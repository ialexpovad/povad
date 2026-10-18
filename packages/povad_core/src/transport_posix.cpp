#include "transport.hpp"

#include <algorithm>
#include <cerrno>
#include <cstring>

#include <arpa/inet.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <termios.h>
#include <unistd.h>

namespace povad {
namespace {

bool would_block() { return errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR; }

speed_t baud_speed(uint32_t baud) {
  switch (baud) {
    case 300: return B300;
    case 600: return B600;
    case 1200: return B1200;
    case 2400: return B2400;
    case 4800: return B4800;
    case 9600: return B9600;
    case 19200: return B19200;
    case 38400: return B38400;
    case 57600: return B57600;
    case 115200: return B115200;
    case 230400: return B230400;
    default: throw TransportError(PV_INVALID_CONFIG, "Unsupported serial baud rate");
  }
}

void make_nonblocking(int fd) {
  const int flags = fcntl(fd, F_GETFL, 0);
  if (flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) {
    throw TransportError(PV_NATIVE_FAILURE, "Cannot set nonblocking socket");
  }
}

} // namespace

struct SerialPort::Impl { int fd = -1; };

SerialPort::SerialPort() : impl_(new Impl) {}
SerialPort::~SerialPort() { close(); }

void SerialPort::open(const pv_config& config) {
  close();
  impl_->fd = ::open(config.serial_port, O_RDWR | O_NOCTTY | O_NONBLOCK | O_CLOEXEC);
  if (impl_->fd < 0) throw TransportError(PV_NATIVE_FAILURE, "Cannot open serial port exclusively");
  try {
    if (ioctl(impl_->fd, TIOCEXCL) < 0) throw TransportError(PV_NATIVE_FAILURE, "Cannot reserve serial port");
    termios settings{};
    if (tcgetattr(impl_->fd, &settings) < 0) throw TransportError(PV_NATIVE_FAILURE, "Cannot read serial settings");
    cfmakeraw(&settings);
    settings.c_cflag |= CLOCAL | CREAD;
    settings.c_cflag &= ~CSIZE;
    settings.c_cflag |= config.data_bits == 5 ? CS5 : config.data_bits == 6 ? CS6 :
                        config.data_bits == 7 ? CS7 : CS8;
    settings.c_cflag &= ~(PARENB | PARODD | CSTOPB);
    if (config.parity != 'N') {
      settings.c_cflag |= PARENB;
      if (config.parity == 'O') settings.c_cflag |= PARODD;
    }
    if (config.stop_bits_x10 == 20) settings.c_cflag |= CSTOPB;
#ifdef CRTSCTS
    if (config.hardware_flow) settings.c_cflag |= CRTSCTS;
    else settings.c_cflag &= ~CRTSCTS;
#else
    if (config.hardware_flow) throw TransportError(PV_INVALID_CONFIG, "Hardware flow control unavailable");
#endif
    const speed_t speed = baud_speed(config.baud);
    if (cfsetispeed(&settings, speed) < 0 || cfsetospeed(&settings, speed) < 0 ||
        tcsetattr(impl_->fd, TCSANOW, &settings) < 0) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot apply serial settings");
    }
    int modem = 0;
    if (ioctl(impl_->fd, TIOCMGET, &modem) == 0) {
      if (config.dtr) modem |= TIOCM_DTR;
      else modem &= ~TIOCM_DTR;
      if (!config.hardware_flow) {
        if (config.rts) modem |= TIOCM_RTS;
        else modem &= ~TIOCM_RTS;
      }
      if (ioctl(impl_->fd, TIOCMSET, &modem) < 0) {
        throw TransportError(PV_NATIVE_FAILURE, "Cannot apply serial control lines");
      }
    } else if (errno != ENOTTY) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot read serial control lines");
    }
  } catch (...) {
    close();
    throw;
  }
}

size_t SerialPort::read(uint8_t* data, size_t capacity) {
  const ssize_t count = ::read(impl_->fd, data, capacity);
  if (count < 0) {
    if (would_block()) return 0;
    throw TransportError(PV_NATIVE_FAILURE, "Serial read failed");
  }
  return static_cast<size_t>(count);
}

size_t SerialPort::write(const uint8_t* data, size_t length) {
  const ssize_t count = ::write(impl_->fd, data, length);
  if (count < 0) {
    if (would_block()) return 0;
    throw TransportError(PV_DELIVERY_UNCERTAIN, "Serial write failed; delivery is uncertain");
  }
  return static_cast<size_t>(count);
}

bool SerialPort::write_pending() const { return false; }

void SerialPort::close() {
  if (impl_->fd >= 0) {
    ioctl(impl_->fd, TIOCNXCL);
    ::close(impl_->fd);
    impl_->fd = -1;
  }
}

struct TcpServer::Impl { int listener = -1; int client = -1; };

TcpServer::TcpServer() : impl_(new Impl) {}
TcpServer::~TcpServer() { close(); }

void TcpServer::listen(const char* address, uint16_t port) {
  close();
  impl_->listener = socket(AF_INET, SOCK_STREAM, 0);
  if (impl_->listener < 0) throw TransportError(PV_NATIVE_FAILURE, "Cannot create TCP listener");
  try {
    sockaddr_in target{};
    target.sin_family = AF_INET;
    target.sin_port = htons(port);
    if (inet_pton(AF_INET, address, &target.sin_addr) != 1 ||
        ::bind(impl_->listener, reinterpret_cast<sockaddr*>(&target), sizeof(target)) < 0) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot bind TCP listener");
    }
    make_nonblocking(impl_->listener);
    if (::listen(impl_->listener, 4) < 0) throw TransportError(PV_NATIVE_FAILURE, "Cannot listen on TCP port");
  } catch (...) {
    close();
    throw;
  }
}

int TcpServer::accept() {
  const int incoming = ::accept(impl_->listener, nullptr, nullptr);
  if (incoming < 0) {
    if (would_block()) return 0;
    throw TransportError(PV_NATIVE_FAILURE, "TCP accept failed");
  }
  if (impl_->client >= 0) {
    ::close(incoming);
    return 2;
  }
  try {
    make_nonblocking(incoming);
    const int yes = 1;
    if (setsockopt(incoming, IPPROTO_TCP, TCP_NODELAY, &yes, sizeof(yes)) < 0) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot configure TCP client");
    }
#ifdef SO_NOSIGPIPE
    if (setsockopt(incoming, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes)) < 0) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot protect TCP writes");
    }
#endif
    impl_->client = incoming;
    return 1;
  } catch (...) {
    ::close(incoming);
    throw;
  }
}

bool TcpServer::connected() const { return impl_->client >= 0; }

int64_t TcpServer::receive(uint8_t* data, size_t capacity) {
  const ssize_t count = recv(impl_->client, data, capacity, 0);
  if (count < 0) {
    if (would_block()) return -1;
    throw TransportError(PV_NATIVE_FAILURE, "TCP read failed");
  }
  return count;
}

size_t TcpServer::send(const uint8_t* data, size_t length) {
#ifdef MSG_NOSIGNAL
  constexpr int flags = MSG_NOSIGNAL;
#else
  constexpr int flags = 0;
#endif
  const ssize_t count = ::send(impl_->client, data, length, flags);
  if (count < 0) {
    if (would_block()) return 0;
    throw TransportError(PV_DELIVERY_UNCERTAIN, "TCP write failed; delivery is uncertain");
  }
  return static_cast<size_t>(count);
}

void TcpServer::close() {
  if (impl_->client >= 0) {
    ::close(impl_->client);
    impl_->client = -1;
  }
  if (impl_->listener >= 0) {
    ::close(impl_->listener);
    impl_->listener = -1;
  }
}

} // namespace povad
