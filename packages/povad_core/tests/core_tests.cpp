#include "povad_core.h"
#include "byte_queue.hpp"
#include "transport.hpp"

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
#include <termios.h>
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
  require(sizeof(pv_config) == 888 && sizeof(pv_error) == 200 &&
          sizeof(pv_snapshot) == 256, "Fixed ABI layout");
  require(pv_abi_version() == 2 && pv_config_size() == 888 &&
          pv_error_size() == 200 && pv_snapshot_size() == 256,
          "ABI version and sizes");
  auto value = config();
  pv_error error{};
  error.size = sizeof(error);
  require(pv_config_validate(&value, &error) == PV_OK && error.code == PV_OK,
          "Valid loopback config");
  value.abi = 1;
  require(pv_config_validate(&value, &error) == PV_ABI_MISMATCH, "ABI mismatch");
  value = config();
  value.wait_next_client = 1;
  require(pv_config_validate(&value, &error) == PV_OK, "Wait-next consent");
  value.wait_next_client = 2;
  require(pv_config_validate(&value, &error) == PV_INVALID_CONFIG, "Invalid wait-next flag");
  value = config();
  std::strcpy(value.allowed_clients, "192.168.1.20");
  require(pv_config_validate(&value, &error) == PV_INVALID_CONFIG, "Allowlist requires LAN");
  value.allow_lan = 1;
  require(pv_config_validate(&value, &error) == PV_OK, "Exact LAN IP allowed");
  require(povad::peer_allowed(value.allowed_clients, "192.168.1.20") &&
          !povad::peer_allowed(value.allowed_clients, "192.168.1.21"),
          "Exact peer match");
  std::strcpy(value.allowed_clients, "192.168.1.20,10.0.0.7");
  require(pv_config_validate(&value, &error) == PV_OK &&
          povad::peer_allowed(value.allowed_clients, "10.0.0.7"),
          "Two allowed clients");
  std::strcpy(value.allowed_clients, "192.168.1.20,");
  require(pv_config_validate(&value, &error) == PV_INVALID_CONFIG, "Trailing comma rejected");
  value = config();
  std::strcpy(value.bind_address, "192.168.1.3");
  require(pv_config_validate(&value, &error) == PV_LAN_CONSENT_REQUIRED, "LAN consent");
  value.allow_lan = 1;
  require(pv_config_validate(&value, &error) == PV_OK, "Explicit LAN consent");
  std::strcpy(value.bind_address, "0.0.0.0");
  value.allow_lan = 0;
  require(pv_config_validate(&value, &error) == PV_LAN_CONSENT_REQUIRED,
          "Wildcard bind requires consent");
  value.allow_lan = 1;
  require(pv_config_validate(&value, &error) == PV_OK, "Wildcard bind with consent");
  for (const char* address : {"0.0.0.1", "224.0.0.1", "169.254.1.2",
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

void reject_second_client(const Rig& rig) {
  const int second = socket(AF_INET, SOCK_STREAM, 0);
  require(second >= 0, "Create second TCP client");
  try {
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons(static_cast<uint16_t>(rig.settings.tcp_port));
    require(connect(second, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0,
            "Connect second TCP client");
    require(fcntl(second, F_SETFL, fcntl(second, F_GETFL) | O_NONBLOCK) == 0,
            "Make second TCP client nonblocking");
    until([&] {
      uint8_t byte = 0;
      const ssize_t count = recv(second, &byte, 1, 0);
      if (count == 0) return true;
      if (count > 0) throw std::runtime_error("Second client received bridge data");
      if (errno == ECONNRESET) return true;
      require(errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR,
              "Second client read failed unexpectedly");
      return false;
    }, "Second TCP client was not rejected");
    require(snapshot(rig.handle).state == PV_STATE_CONNECTED,
            "First TCP client remains active after rejection");
  } catch (...) {
    ::close(second);
    throw;
  }
  ::close(second);
}

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
  reject_second_client(rig);
  require(snapshot(rig.handle).rejected_busy == 1,
          "Busy rejection appears in snapshot");
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

// Exercise two actual native handles, OS serial descriptors, sockets and
// queues concurrently. Different binary vectors expose cross-session routing.
void test_independent_concurrent_bridges() {
  Rig first;
  first.settings.wait_next_client = 1;
  first.start();
  Rig second; // Reserve the second TCP port after the first is listening.
  second.start();
  first.connect_client();
  second.connect_client();
  std::array<uint8_t, 4096> a{}, b{}, c{}, d{};
  for (size_t i = 0; i < a.size(); ++i) {
    a[i] = static_cast<uint8_t>(i * 17);
    b[i] = static_cast<uint8_t>(i * 31 + 1);
    c[i] = static_cast<uint8_t>(255 - i * 13);
    d[i] = static_cast<uint8_t>(i * 7 + 2);
  }
  for (int round = 0; round < 8; ++round) {
    send_all(first.client, a.data(), a.size(), true);
    send_all(second.client, b.data(), b.size(), true);
    send_all(first.master, c.data(), c.size(), false);
    send_all(second.master, d.data(), d.size(), false);
    receive_exact(second.master, b.data(), b.size());
    receive_exact(first.master, a.data(), a.size());
    receive_exact(second.client, d.data(), d.size());
    receive_exact(first.client, c.data(), c.size());
  }
  // Reconnect only the first client while the second keeps its session.
  ::close(first.client);
  first.client = -1;
  until([&] { return snapshot(first.handle).state == PV_STATE_LISTENING; },
        "First bridge did not return to listening");
  first.connect_client();
  require(snapshot(second.handle).state == PV_STATE_CONNECTED,
          "Reconnect changed the other worker");
  // A physical-side fault on the first must not tear down the second.
  ::close(first.master);
  first.master = -1;
  until([&] { return snapshot(first.handle).state == PV_STATE_FAULT; },
        "First bridge did not report serial detach");
  send_all(second.client, b.data(), b.size(), true);
  receive_exact(second.master, b.data(), b.size());
  send_all(second.master, d.data(), d.size(), false);
  receive_exact(second.client, d.data(), d.size());
  until([&] {
    const auto value = snapshot(second.handle);
    return value.tcp_received == b.size() * 9 &&
           value.serial_received == d.size() * 9 &&
           value.serial_accepted == b.size() * 9 &&
           value.tcp_accepted == d.size() * 9;
  }, "Second bridge lost independent counters or bytes after first fault");
  require(snapshot(second.handle).state == PV_STATE_CONNECTED,
          "Fault in one bridge stopped another");
}

void test_three_clients_without_restart() {
  Rig rig;
  rig.settings.wait_next_client = 1;
  rig.start();
  for (int round = 0; round < 3; ++round) {
    rig.connect_client();
    const std::array<uint8_t, 3> request{0x01, static_cast<uint8_t>(round), 0xff};
    const std::array<uint8_t, 3> response{0x02, static_cast<uint8_t>(round), 0x00};
    send_all(rig.client, request.data(), request.size(), true);
    receive_exact(rig.master, request.data(), request.size());
    send_all(rig.master, response.data(), response.size(), false);
    receive_exact(rig.client, response.data(), response.size());
    until([&] {
      const auto current = snapshot(rig.handle);
      return current.serial_accepted == static_cast<uint64_t>((round + 1) * 3) &&
             current.tcp_accepted == static_cast<uint64_t>((round + 1) * 3);
    }, "Round output did not settle");
    ::close(rig.client);
    rig.client = -1;
    until([&] { return snapshot(rig.handle).state == PV_STATE_LISTENING; },
          "Worker did not wait for the next client");
    require(snapshot(rig.handle).serial_open == 1,
            "Serial handle closed between clients");
  }
}

void test_ip_allowlist_rejects_nonmember() {
  Rig rig;
  rig.settings.allow_lan = 1;
  std::strcpy(rig.settings.allowed_clients, "127.0.0.2");
  rig.start();
  const int client = socket(AF_INET, SOCK_STREAM, 0);
  require(client >= 0, "Create denied client");
  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  address.sin_port = htons(static_cast<uint16_t>(rig.settings.tcp_port));
  require(connect(client, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0,
          "Connect denied client");
  until([&] { return snapshot(rig.handle).rejected_ip == 1; },
        "Denied IP was not counted");
  uint8_t byte = 0;
  require(recv(client, &byte, 1, 0) == 0,
          "Denied client was not closed immediately");
  ::close(client);
  require(snapshot(rig.handle).state == PV_STATE_LISTENING,
          "Denied client changed listener state");
}

void test_stop_releases_handles() {
  Rig rig;
  rig.start();
  require(pv_request_stop(rig.handle) == PV_OK, "Request stop");
  until([&] { return snapshot(rig.handle).state == PV_STATE_STOPPED; },
        "Native worker did not stop");
  require(snapshot(rig.handle).serial_open == 0, "Serial handle was not released");
}

void test_repeated_start_stop_on_same_endpoints() {
  Rig rig;
  const std::array<uint8_t, 5> request{0x00, 0xff, 0x19, 0x80, 0x0d};
  const std::array<uint8_t, 4> response{0xff, 0x00, 0x81, 0x0a};
  for (int round = 0; round < 20; ++round) {
    rig.start();
    if (round == 0) {
      const int rival = socket(AF_INET, SOCK_STREAM, 0);
      require(rival >= 0, "Create rival TCP listener");
      const int yes = 1;
      require(setsockopt(rival, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes)) == 0,
              "Configure rival TCP listener");
      sockaddr_in address{};
      address.sin_family = AF_INET;
      address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
      address.sin_port = htons(static_cast<uint16_t>(rig.settings.tcp_port));
      const int bind_result = bind(rival, reinterpret_cast<sockaddr*>(&address),
                                   sizeof(address));
      const int bind_error = errno;
      ::close(rival);
      require(bind_result < 0 && bind_error == EADDRINUSE,
              "A second live listener must not share the bridge port");
    }
    rig.connect_client();
    send_all(rig.client, request.data(), request.size(), true);
    receive_exact(rig.master, request.data(), request.size());
    send_all(rig.master, response.data(), response.size(), false);
    receive_exact(rig.client, response.data(), response.size());
    const auto transferred = snapshot(rig.handle);
    require(transferred.tcp_received == request.size() &&
            transferred.serial_accepted == request.size() &&
            transferred.serial_received == response.size() &&
            transferred.tcp_accepted == response.size(),
            "Each restarted session must reset and settle native counters");
    require(pv_request_stop(rig.handle) == PV_OK, "Request repeated stop");
    until([&] { return snapshot(rig.handle).state == PV_STATE_STOPPED; },
          "Repeated worker stop did not finish");
    require(snapshot(rig.handle).serial_open == 0,
            "Repeated stop retained serial handle");
    ::close(rig.client);
    rig.client = -1;
  }
}

void test_serial_disconnect_is_reported() {
  Rig rig;
  // An inherited VMIN=0 setting must not make an idle device look detached.
  const int slave = ::open(rig.settings.serial_port, O_RDWR | O_NOCTTY);
  require(slave >= 0, "Open serial peer for inherited termios setting");
  termios settings{};
  require(tcgetattr(slave, &settings) == 0, "Read inherited serial settings");
  settings.c_cc[VMIN] = 0;
  settings.c_cc[VTIME] = 0;
  require(tcsetattr(slave, TCSANOW, &settings) == 0,
          "Apply inherited zero-minimum serial setting");
  ::close(slave);
  rig.start();
  rig.connect_client();
  std::this_thread::sleep_for(std::chrono::milliseconds(50));
  require(snapshot(rig.handle).state == PV_STATE_CONNECTED,
          "Idle serial port must not look disconnected");
  ::close(rig.master);
  rig.master = -1;
  until([&] { return snapshot(rig.handle).state == PV_STATE_FAULT; },
        "Disconnected serial port did not stop the worker");
  const auto failed = snapshot(rig.handle);
  require(failed.error_code == PV_NATIVE_FAILURE && failed.serial_open == 0 &&
          failed.client_connected == 0,
          "Serial disconnect fault and confirmed cleanup");
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
    test_independent_concurrent_bridges();
    test_three_clients_without_restart();
    test_ip_allowlist_rejects_nonmember();
    test_stop_releases_handles();
    test_repeated_start_stop_on_same_endpoints();
    test_serial_disconnect_is_reported();
    test_open_failure_is_reported();
#endif
    std::cout << "PASS Povad core ABI, config, queue, and transport contracts\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "FAIL " << error.what() << '\n';
    return 1;
  }
}
