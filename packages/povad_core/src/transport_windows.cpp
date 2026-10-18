#include "transport.hpp"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>

#include <algorithm>
#include <cstring>
#include <string>
#include <vector>

namespace povad {
namespace {

std::wstring wide(const char* utf8) {
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      utf8, -1, nullptr, 0);
  if (length <= 0) throw TransportError(PV_INVALID_CONFIG, "Invalid serial port name");
  std::wstring result(static_cast<size_t>(length), L'\0');
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      utf8, -1, result.data(), length)) {
    throw TransportError(PV_INVALID_CONFIG, "Invalid serial port name");
  }
  result.pop_back();
  return result;
}

bool socket_blocked() {
  const int code = WSAGetLastError();
  return code == WSAEWOULDBLOCK || code == WSAEINTR;
}

void nonblocking(SOCKET socket) {
  u_long enabled = 1;
  if (ioctlsocket(socket, FIONBIO, &enabled) != 0) {
    throw TransportError(PV_NATIVE_FAILURE, "Cannot set nonblocking socket");
  }
}

} // namespace

struct SerialPort::Impl {
  HANDLE port = INVALID_HANDLE_VALUE;
  OVERLAPPED read_overlapped{};
  OVERLAPPED write_overlapped{};
  uint8_t read_buffer[4096]{};
  std::vector<uint8_t> write_buffer;
  bool reading = false;
  bool writing = false;
  bool close_uncertain = false;
};

SerialPort::SerialPort() : impl_(new Impl) {}
SerialPort::~SerialPort() { close(); }

void SerialPort::open(const pv_config& config) {
  if (!close()) throw TransportError(PV_NATIVE_FAILURE, "Previous serial shutdown is uncertain");
  const std::wstring path = L"\\\\.\\" + wide(config.serial_port);
  impl_->port = CreateFileW(path.c_str(), GENERIC_READ | GENERIC_WRITE, 0,
      nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, nullptr);
  if (impl_->port == INVALID_HANDLE_VALUE) {
    throw TransportError(PV_NATIVE_FAILURE, "Cannot open serial port exclusively");
  }
  try {
    DCB settings{};
    settings.DCBlength = sizeof(settings);
    if (!GetCommState(impl_->port, &settings)) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot read serial settings");
    }
    settings.BaudRate = config.baud;
    settings.ByteSize = static_cast<BYTE>(config.data_bits);
    settings.Parity = config.parity == 'N' ? NOPARITY :
        config.parity == 'E' ? EVENPARITY : ODDPARITY;
    settings.StopBits = config.stop_bits_x10 == 10 ? ONESTOPBIT : TWOSTOPBITS;
    settings.fBinary = TRUE;
    settings.fParity = config.parity != 'N';
    settings.fOutX = FALSE;
    settings.fInX = FALSE;
    settings.fNull = FALSE;
    settings.fErrorChar = FALSE;
    settings.fAbortOnError = FALSE;
    settings.fOutxDsrFlow = FALSE;
    settings.fDsrSensitivity = FALSE;
    settings.fOutxCtsFlow = config.hardware_flow != 0;
    settings.fDtrControl = config.dtr ? DTR_CONTROL_ENABLE : DTR_CONTROL_DISABLE;
    settings.fRtsControl = config.hardware_flow ? RTS_CONTROL_HANDSHAKE :
        config.rts ? RTS_CONTROL_ENABLE : RTS_CONTROL_DISABLE;
    if (!SetCommState(impl_->port, &settings)) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot apply serial settings");
    }
    COMMTIMEOUTS timeouts{};
    timeouts.ReadIntervalTimeout = MAXDWORD;
    timeouts.WriteTotalTimeoutConstant = config.queue_age_ms;
    if (!SetCommTimeouts(impl_->port, &timeouts) ||
        !SetupComm(impl_->port, 65536, 65536)) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot configure serial buffers");
    }
    impl_->read_overlapped.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    impl_->write_overlapped.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (impl_->read_overlapped.hEvent == nullptr ||
        impl_->write_overlapped.hEvent == nullptr) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot create serial events");
    }
  } catch (...) {
    close();
    throw;
  }
}

size_t SerialPort::read(uint8_t* data, size_t capacity) {
  DWORD count = 0;
  if (impl_->reading) {
    if (!GetOverlappedResult(impl_->port, &impl_->read_overlapped, &count, FALSE)) {
      if (GetLastError() == ERROR_IO_INCOMPLETE) return 0;
      throw TransportError(PV_NATIVE_FAILURE, "Serial read completion failed");
    }
    impl_->reading = false;
    std::memcpy(data, impl_->read_buffer, count);
    return count;
  }
  ResetEvent(impl_->read_overlapped.hEvent);
  const DWORD requested = static_cast<DWORD>(std::min(capacity, sizeof(impl_->read_buffer)));
  if (!ReadFile(impl_->port, impl_->read_buffer, requested, &count,
      &impl_->read_overlapped)) {
    if (GetLastError() == ERROR_IO_PENDING) {
      impl_->reading = true;
      return 0;
    }
    throw TransportError(PV_NATIVE_FAILURE, "Serial read failed");
  }
  std::memcpy(data, impl_->read_buffer, count);
  return count;
}

size_t SerialPort::write(const uint8_t* data, size_t length) {
  DWORD count = 0;
  if (impl_->writing) {
    if (!GetOverlappedResult(impl_->port, &impl_->write_overlapped, &count, FALSE)) {
      if (GetLastError() == ERROR_IO_INCOMPLETE) return 0;
      throw TransportError(PV_DELIVERY_UNCERTAIN,
          "Serial write completion failed; delivery is uncertain");
    }
    impl_->writing = false;
    const size_t expected = impl_->write_buffer.size();
    impl_->write_buffer.clear();
    if (count != expected) throw TransportError(PV_DELIVERY_UNCERTAIN,
        "Partial serial write; delivery is uncertain");
    return count;
  }
  const size_t requested = std::min(length, size_t(4096));
  impl_->write_buffer.assign(data, data + requested);
  ResetEvent(impl_->write_overlapped.hEvent);
  if (!WriteFile(impl_->port, impl_->write_buffer.data(),
      static_cast<DWORD>(requested), &count, &impl_->write_overlapped)) {
    if (GetLastError() == ERROR_IO_PENDING) {
      impl_->writing = true;
      return 0;
    }
    throw TransportError(PV_DELIVERY_UNCERTAIN, "Serial write failed; delivery is uncertain");
  }
  impl_->write_buffer.clear();
  if (count != requested) throw TransportError(PV_DELIVERY_UNCERTAIN,
      "Partial serial write; delivery is uncertain");
  return count;
}

bool SerialPort::write_pending() const { return impl_->writing; }

bool SerialPort::close() {
  if (impl_->close_uncertain) return false;
  bool closed = true;
  if (impl_->port != INVALID_HANDLE_VALUE) {
    // The worker waits for cancellation before OVERLAPPED buffers and events
    // are released. A broken driver keeps the worker active.
    if (impl_->reading) {
      CancelIoEx(impl_->port, &impl_->read_overlapped);
      DWORD count = 0;
      GetOverlappedResult(impl_->port, &impl_->read_overlapped, &count, TRUE);
    }
    if (impl_->writing) {
      CancelIoEx(impl_->port, &impl_->write_overlapped);
      DWORD count = 0;
      GetOverlappedResult(impl_->port, &impl_->write_overlapped, &count, TRUE);
    }
    closed = CloseHandle(impl_->port) != 0 && closed;
    impl_->port = INVALID_HANDLE_VALUE;
  }
  if (impl_->read_overlapped.hEvent)
    closed = CloseHandle(impl_->read_overlapped.hEvent) != 0 && closed;
  if (impl_->write_overlapped.hEvent)
    closed = CloseHandle(impl_->write_overlapped.hEvent) != 0 && closed;
  impl_->read_overlapped = {};
  impl_->write_overlapped = {};
  impl_->reading = false;
  impl_->writing = false;
  impl_->write_buffer.clear();
  impl_->close_uncertain = !closed;
  return closed;
}

struct TcpServer::Impl {
  SOCKET listener = INVALID_SOCKET;
  SOCKET client = INVALID_SOCKET;
  bool wsa = false;
};

TcpServer::TcpServer() : impl_(new Impl) {
  WSADATA data{};
  if (WSAStartup(MAKEWORD(2, 2), &data) != 0) {
    throw TransportError(PV_NATIVE_FAILURE, "Cannot initialize Windows sockets");
  }
  impl_->wsa = true;
}

TcpServer::~TcpServer() {
  close();
  if (impl_->wsa) WSACleanup();
}

void TcpServer::listen(const char* address, uint16_t port) {
  close();
  impl_->listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (impl_->listener == INVALID_SOCKET) {
    throw TransportError(PV_NATIVE_FAILURE, "Cannot create TCP listener");
  }
  try {
    const int yes = 1;
    if (setsockopt(impl_->listener, SOL_SOCKET, SO_EXCLUSIVEADDRUSE,
        reinterpret_cast<const char*>(&yes), sizeof(yes)) != 0) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot reserve TCP address");
    }
    sockaddr_in target{};
    target.sin_family = AF_INET;
    target.sin_port = htons(port);
    if (InetPtonA(AF_INET, address, &target.sin_addr) != 1 ||
        ::bind(impl_->listener, reinterpret_cast<sockaddr*>(&target),
            sizeof(target)) != 0) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot bind TCP listener");
    }
    nonblocking(impl_->listener);
    if (::listen(impl_->listener, 4) != 0) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot listen on TCP port");
    }
  } catch (...) {
    close();
    throw;
  }
}

int TcpServer::accept() {
  const SOCKET incoming = ::accept(impl_->listener, nullptr, nullptr);
  if (incoming == INVALID_SOCKET) {
    if (socket_blocked()) return 0;
    throw TransportError(PV_NATIVE_FAILURE, "TCP accept failed");
  }
  if (impl_->client != INVALID_SOCKET) {
    closesocket(incoming);
    return 2;
  }
  try {
    nonblocking(incoming);
    const int yes = 1;
    if (setsockopt(incoming, IPPROTO_TCP, TCP_NODELAY,
        reinterpret_cast<const char*>(&yes), sizeof(yes)) != 0) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot configure TCP client");
    }
    impl_->client = incoming;
    return 1;
  } catch (...) {
    closesocket(incoming);
    throw;
  }
}

bool TcpServer::connected() const { return impl_->client != INVALID_SOCKET; }

int64_t TcpServer::receive(uint8_t* data, size_t capacity) {
  const int count = recv(impl_->client, reinterpret_cast<char*>(data),
      static_cast<int>(std::min(capacity, size_t(4096))), 0);
  if (count == SOCKET_ERROR) {
    if (socket_blocked()) return -1;
    throw TransportError(PV_NATIVE_FAILURE, "TCP read failed");
  }
  return count;
}

size_t TcpServer::send(const uint8_t* data, size_t length) {
  const int count = ::send(impl_->client, reinterpret_cast<const char*>(data),
      static_cast<int>(std::min(length, size_t(4096))), 0);
  if (count == SOCKET_ERROR) {
    if (socket_blocked()) return 0;
    throw TransportError(PV_DELIVERY_UNCERTAIN, "TCP write failed; delivery is uncertain");
  }
  return static_cast<size_t>(count);
}

void TcpServer::close() {
  if (impl_->client != INVALID_SOCKET) {
    closesocket(impl_->client);
    impl_->client = INVALID_SOCKET;
  }
  if (impl_->listener != INVALID_SOCKET) {
    closesocket(impl_->listener);
    impl_->listener = INVALID_SOCKET;
  }
}

} // namespace povad
