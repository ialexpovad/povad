#include "povad_core.h"
#include "byte_queue.hpp"

#include <array>
#include <chrono>
#include <cstring>
#include <functional>
#include <iostream>
#include <stdexcept>
#include <thread>

#ifndef _WIN32
#include <cerrno>
#include <fcntl.h>
#include <poll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#ifdef __APPLE__
#include <util.h>
#else
#include <pty.h>
#endif
#endif

namespace {

void require(bool condition, const char* name) {
  if (!condition) throw std::runtime_error(name);
}

pv_config config() {
  pv_config value{};
  value.size = sizeof(value);
  value.abi = PV_ABI_VERSION;
  value.baud = 115200;
  value.data_bits = 8;
  value.parity = 'N';
  value.stop_bits_x10 = 10;
  value.tcp_port = 9268;
  value.queue_limit = 65536;
  value.queue_age_ms = 2000;
  std::strcpy(value.serial_port, "COM17");
  std::strcpy(value.bind_address, "127.0.0.1");
  return value;
}

void test_abi_and_validation() {
  require(sizeof(pv_config) == 372 && sizeof(pv_error) == 200 &&
          sizeof(pv_snapshot) == 248, "Fixed ABI layout");
  require(pv_abi_version() == 1 && pv_config_size() == 372 &&
          pv_error_size() == 200 && pv_snapshot_size() == 248,
          "ABI version and sizes");
  auto value = config();
  pv_error error{};
  error.size = sizeof(error);
  require(pv_config_validate(&value, &error) == PV_OK && error.code == PV_OK,
          "Valid loopback config");
  value.abi = 2;
  require(pv_config_validate(&value, &error) == PV_ABI_MISMATCH, "ABI mismatch");
  value = config();
  std::strcpy(value.bind_address, "192.168.1.3");
  require(pv_config_validate(&value, &error) == PV_LAN_CONSENT_REQUIRED, "LAN consent");
  value.allow_lan = 1;
  require(pv_config_validate(&value, &error) == PV_OK, "Explicit LAN consent");
  for (const char* address : {"0.0.0.0", "224.0.0.1", "169.254.1.2",
                              "127.0.0.01", "example.org", "1.2.3.256"}) {
    std::strcpy(value.bind_address, address);
    require(pv_config_validate(&value, &error) == PV_INVALID_CONFIG, "Unsafe bind address");
  }
  value = config();
  std::memset(value.serial_port, 'A', sizeof(value.serial_port));
  require(pv_config_validate(&value, &error) == PV_INVALID_CONFIG, "NUL termination");
  value = config();
  value.parity = 'M';
  require(pv_config_validate(&value, &error) == PV_INVALID_CONFIG, "Unsupported parity");
  error.size = 0;
  require(pv_config_validate(&value, &error) == PV_ABI_MISMATCH, "Error ABI mismatch");
}

void test_byte_queue() {
  povad::ByteQueue queue(8);
  const std::array<uint8_t, 5> binary{0x00, 0xff, 0x0d, 0x0a, 0x80};
  queue.push(binary.data(), binary.size(), 10);
  require(queue.size() == 5 && std::memcmp(queue.front_data(), binary.data(), 5) == 0,
          "Binary bytes preserved");
  queue.consume(2);
  require(queue.front_size() == 3 && queue.front_data()[0] == 0x0d,
          "Partial write accounting");
  const uint8_t tail[5]{1, 2, 3, 4, 5};
  queue.push(tail, sizeof(tail), 12);
  require(queue.size() == 8, "Queue full at exact bound");
  try {
    queue.push(tail, 1, 13);
    throw std::runtime_error("Queue limit was ignored");
  } catch (const povad::QueueError& error) {
    require(error.reason == povad::QueueFailure::limit, "Queue limit reason");
  }
  queue.consume(3);
  require(queue.front_data()[0] == 1, "Next chunk retains order");
  queue.check_age(14, 2);
  try {
    queue.check_age(15, 2);
    throw std::runtime_error("Queue age was ignored");
  } catch (const povad::QueueError& error) {
    require(error.reason == povad::QueueFailure::age, "Queue age reason");
  }
  queue.clear();
  require(queue.empty() && queue.size() == 0, "Queue clear");
  try {
    queue.front_data();
    throw std::runtime_error("Empty queue was readable");
  } catch (const povad::QueueError& error) {
    require(error.reason == povad::QueueFailure::empty, "Empty queue reason");
  }
}

#ifndef _WIN32
pv_snapshot snapshot(pv_handle* handle) {
  pv_snapshot value{};
  value.size = sizeof(value);
  require(pv_read_snapshot(handle, &value) == PV_OK, "Read native snapshot");
  return value;
}

void until(const std::function<bool()>& ready, const char* description) {
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(4);
  while (std::chrono::steady_clock::now() < deadline) {
    if (ready()) return;
    std::this_thread::sleep_for(std::chrono::milliseconds(2));
  }
  throw std::runtime_error(description);
}

uint16_t available_port() {
  const int fd = socket(AF_INET, SOCK_STREAM, 0);
  require(fd >= 0, "Create port reservation");
  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  require(bind(fd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0,
          "Reserve loopback port");
  socklen_t length = sizeof(address);
  require(getsockname(fd, reinterpret_cast<sockaddr*>(&address), &length) == 0,
          "Get reserved port");
  const uint16_t port = ntohs(address.sin_port);
  ::close(fd);
  return port;
}

void send_all(int fd, const uint8_t* bytes, size_t length, bool tcp) {
  size_t offset = 0;
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(4);
  while (offset < length) {
    const ssize_t count = tcp ? send(fd, bytes + offset, length - offset, 0) :
                                ::write(fd, bytes + offset, length - offset);
    if (count > 0) offset += static_cast<size_t>(count);
    else {
      require(count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR),
              "Test write failed");
      require(std::chrono::steady_clock::now() < deadline, "Test write timed out");
      std::this_thread::sleep_for(std::chrono::milliseconds(2));
    }
  }
}

void receive_exact(int fd, const uint8_t* expected, size_t length) {
  std::vector<uint8_t> received(length);
  size_t offset = 0;
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(4);
  while (offset < length) {
    const ssize_t count = ::read(fd, received.data() + offset, length - offset);
    if (count > 0) offset += static_cast<size_t>(count);
    else {
      require(count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR),
              "Test peer closed or read failed");
      require(std::chrono::steady_clock::now() < deadline, "Test read timed out");
      std::this_thread::sleep_for(std::chrono::milliseconds(2));
    }
  }
  require(std::memcmp(received.data(), expected, length) == 0, "Byte stream changed");
}

struct Rig {
  pv_handle* handle = nullptr;
  int master = -1;
  int client = -1;
  pv_config settings = config();

  Rig() {
    int slave = -1;
    char path[256]{};
    require(openpty(&master, &slave, path, nullptr, nullptr) == 0, "Open PTY pair");
    ::close(slave);
    fcntl(master, F_SETFL, fcntl(master, F_GETFL) | O_NONBLOCK);
    std::strcpy(settings.serial_port, path);
    settings.tcp_port = available_port();
    handle = pv_create();
    require(handle != nullptr, "Create native handle");
  }

  ~Rig() {
    if (client >= 0) ::close(client);
    if (handle != nullptr) {
      pv_request_stop(handle);
      const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(4);
      while (pv_destroy(handle) == PV_BUSY && std::chrono::steady_clock::now() < deadline) {
        std::this_thread::sleep_for(std::chrono::milliseconds(2));
      }
    }
    if (master >= 0) ::close(master);
  }

  void start() {
    pv_error error{};
    error.size = sizeof(error);
    require(pv_start(handle, &settings, &error) == PV_OK, "Start native worker");
    require(pv_destroy(handle) == PV_BUSY, "Cannot destroy running worker");
    until([&] {
      const auto current = snapshot(handle);
      if (current.state == PV_STATE_FAULT) throw std::runtime_error(current.error_message);
      return current.state == PV_STATE_LISTENING;
    }, "Listener did not start");
  }

  void connect_client() {
    client = socket(AF_INET, SOCK_STREAM, 0);
    require(client >= 0, "Create TCP client");
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons(static_cast<uint16_t>(settings.tcp_port));
    require(connect(client, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0,
            "Connect TCP client");
    fcntl(client, F_SETFL, fcntl(client, F_GETFL) | O_NONBLOCK);
    until([&] { return snapshot(handle).state == PV_STATE_CONNECTED; },
          "Native worker did not admit client");
  }
};

void test_transparent_bridge() {
  Rig rig;
  rig.start();
  rig.connect_client();
  const std::array<uint8_t, 8> request{0x00, 0xff, 0x01, 0x02, 0x0d, 0x0a, 0x80, 0x00};
  const std::array<uint8_t, 7> response{0x7f, 0x00, 0xff, 0x10, 0x20, 0x00, 0x7e};
  send_all(rig.client, request.data(), request.size(), true);
  receive_exact(rig.master, request.data(), request.size());
  send_all(rig.master, response.data(), response.size(), false);
  receive_exact(rig.client, response.data(), response.size());
  std::vector<uint8_t> bulk(8192);
  for (size_t index = 0; index < bulk.size(); ++index) bulk[index] = static_cast<uint8_t>(index);
  send_all(rig.client, bulk.data(), bulk.size(), true);
  receive_exact(rig.master, bulk.data(), bulk.size());
  until([&] {
    const auto current = snapshot(rig.handle);
    return current.tcp_received == request.size() + bulk.size() &&
           current.serial_received == response.size() &&
           current.serial_accepted == request.size() + bulk.size() &&
           current.tcp_accepted == response.size();
  }, "Native counters did not settle");
  ::close(rig.client);
  rig.client = -1;
  until([&] { return snapshot(rig.handle).state == PV_STATE_INTERRUPTED; },
        "Client close did not end the generation");
  const auto final = snapshot(rig.handle);
  require(final.serial_open == 0 && final.client_connected == 0,
          "Worker released handles after disconnect");
}

void test_stop_releases_handles() {
  Rig rig;
  rig.start();
  require(pv_request_stop(rig.handle) == PV_OK, "Request stop");
  until([&] { return snapshot(rig.handle).state == PV_STATE_STOPPED; },
        "Native worker did not stop");
  require(snapshot(rig.handle).serial_open == 0, "Serial handle was not released");
}

void test_open_failure_is_reported() {
  Rig rig;
  std::strcpy(rig.settings.serial_port, "/dev/povad-device-that-does-not-exist");
  pv_error error{};
  error.size = sizeof(error);
  require(pv_start(rig.handle, &rig.settings, &error) == PV_OK,
          "Worker launch is distinct from device open");
  until([&] { return snapshot(rig.handle).state == PV_STATE_FAULT; },
        "Missing serial port did not produce a fault");
  const auto failed = snapshot(rig.handle);
  require(failed.error_code == PV_NATIVE_FAILURE && failed.serial_open == 0,
          "Open failure code and cleanup");
}
#endif

} // namespace

int main() {
  try {
    test_abi_and_validation();
    test_byte_queue();
#ifndef _WIN32
    test_transparent_bridge();
    test_stop_releases_handles();
    test_open_failure_is_reported();
#endif
    std::cout << "PASS Povad core ABI, config, queue, and transport contracts\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "FAIL " << error.what() << '\n';
    return 1;
  }
}
