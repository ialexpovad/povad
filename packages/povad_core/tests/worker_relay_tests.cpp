#include "bridge.hpp"
#include "transport.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <deque>
#include <functional>
#include <iostream>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <vector>

namespace {

struct FakeTransport {
  std::mutex mutex;
  std::deque<uint8_t> serial_input;
  std::deque<uint8_t> tcp_input;
  std::vector<uint8_t> serial_output;
  std::vector<uint8_t> tcp_output;
  bool serial_open = false;
  bool listening = false;
  bool admit_client = false;
  bool client_connected = false;
  bool disconnect_client = false;
  bool reject_busy = false;
  bool reject_ip = false;
} fake;

void require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}

void wait_for(const std::function<bool()>& ready, const char* message) {
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
  while (std::chrono::steady_clock::now() < deadline) {
    if (ready()) return;
    std::this_thread::sleep_for(std::chrono::milliseconds(2));
  }
  throw std::runtime_error(message);
}

pv_snapshot snapshot(povad::Bridge& bridge) {
  pv_snapshot value{};
  bridge.snapshot(&value);
  return value;
}

std::vector<uint8_t> vector_for(int round, size_t length, int factor) {
  std::vector<uint8_t> bytes(length);
  for (size_t index = 0; index < length; ++index) {
    bytes[index] = static_cast<uint8_t>(index * factor + round * 29);
  }
  bytes[0] = 0x00;
  bytes[1] = 0xff;
  return bytes;
}

void test_repeated_full_duplex_relay() {
  pv_config config{};
  config.queue_limit = 64;
  config.queue_age_ms = 5000;
  povad::Bridge bridge;
  struct StopOnExit final {
    povad::Bridge& bridge;
    ~StopOnExit() { bridge.request_stop(); }
  } stop_on_exit{bridge};
  require(bridge.start(config) == PV_OK, "Start worker");
  wait_for([&] { return snapshot(bridge).state == PV_STATE_LISTENING; },
           "Worker did not start listening");
  {
    std::lock_guard<std::mutex> lock(fake.mutex);
    fake.admit_client = true;
  }
  wait_for([&] { return snapshot(bridge).state == PV_STATE_CONNECTED; },
           "Worker did not admit client");

  std::vector<uint8_t> expected_serial;
  std::vector<uint8_t> expected_tcp;
  constexpr int rounds = 12;
  constexpr size_t tcp_length = 257;
  constexpr size_t serial_length = 263;
  for (int round = 0; round < rounds; ++round) {
    const auto from_tcp = vector_for(round, tcp_length, 37);
    const auto from_serial = vector_for(round, serial_length, 53);
    expected_serial.insert(expected_serial.end(), from_tcp.begin(), from_tcp.end());
    expected_tcp.insert(expected_tcp.end(), from_serial.begin(), from_serial.end());
    {
      std::lock_guard<std::mutex> lock(fake.mutex);
      fake.tcp_input.insert(fake.tcp_input.end(), from_tcp.begin(), from_tcp.end());
      fake.serial_input.insert(fake.serial_input.end(), from_serial.begin(), from_serial.end());
    }
    wait_for([&] {
      std::lock_guard<std::mutex> lock(fake.mutex);
      return fake.serial_output.size() >= expected_serial.size() &&
             fake.tcp_output.size() >= expected_tcp.size();
    }, "Repeated bidirectional output did not arrive");
    {
      std::lock_guard<std::mutex> lock(fake.mutex);
      require(fake.serial_output == expected_serial, "TCP-to-serial bytes changed");
      require(fake.tcp_output == expected_tcp, "Serial-to-TCP bytes changed");
    }
  }

  wait_for([&] {
    const auto value = snapshot(bridge);
    return value.tcp_received == rounds * tcp_length &&
           value.serial_accepted == rounds * tcp_length &&
           value.serial_received == rounds * serial_length &&
           value.tcp_accepted == rounds * serial_length;
  }, "Native counters did not settle after repeated exchanges");
  const auto transferred = snapshot(bridge);
  std::this_thread::sleep_for(std::chrono::milliseconds(150));
  const auto idle = snapshot(bridge);
  require(idle.state == PV_STATE_CONNECTED &&
          idle.tcp_received == transferred.tcp_received &&
          idle.serial_received == transferred.serial_received,
          "Idle worker invented traffic or lost its client");

  bridge.request_stop();
  wait_for([&] { return snapshot(bridge).state == PV_STATE_STOPPED; },
           "Worker did not stop cleanly");
  {
    std::lock_guard<std::mutex> lock(fake.mutex);
    require(!fake.serial_open && !fake.listening && !fake.client_connected,
            "Worker retained a transport after stop");
  }
}

void test_wait_next_client_and_rejections() {
  pv_config config{};
  config.queue_limit = 64;
  config.queue_age_ms = 5000;
  config.wait_next_client = 1;
  povad::Bridge bridge;
  struct StopOnExit final {
    povad::Bridge& bridge;
    ~StopOnExit() { bridge.request_stop(); }
  } stop_on_exit{bridge};
  require(bridge.start(config) == PV_OK, "Start waiting worker");
  wait_for([&] { return snapshot(bridge).state == PV_STATE_LISTENING; },
      "Worker did not listen");
  for (int round = 0; round < 3; ++round) {
    {
      std::lock_guard<std::mutex> lock(fake.mutex);
      fake.admit_client = true;
    }
    wait_for([&] { return snapshot(bridge).state == PV_STATE_CONNECTED; },
        "Client did not connect");
    {
      std::lock_guard<std::mutex> lock(fake.mutex);
      fake.reject_busy = true;
    }
    wait_for([&] { return snapshot(bridge).rejected_busy == static_cast<uint32_t>(round + 1); },
        "Busy client was not counted");
    {
      std::lock_guard<std::mutex> lock(fake.mutex);
      fake.disconnect_client = true;
    }
    wait_for([&] { return snapshot(bridge).state == PV_STATE_LISTENING; },
        "Worker did not wait for a successor");
  }
  require(snapshot(bridge).serial_open == 1, "Serial port was closed between clients");
  bridge.request_stop();
  wait_for([&] { return snapshot(bridge).state == PV_STATE_STOPPED; },
      "Waiting worker did not stop");
}

} // namespace

namespace povad {

struct SerialPort::Impl {};
SerialPort::SerialPort() : impl_(new Impl) {}
SerialPort::~SerialPort() { close(); }
void SerialPort::open(const pv_config&) {
  std::lock_guard<std::mutex> lock(fake.mutex);
  fake.serial_open = true;
}
size_t SerialPort::read(uint8_t* data, size_t capacity) {
  std::lock_guard<std::mutex> lock(fake.mutex);
  const size_t count = std::min({capacity, size_t(19), fake.serial_input.size()});
  for (size_t index = 0; index < count; ++index) {
    data[index] = fake.serial_input.front();
    fake.serial_input.pop_front();
  }
  return count;
}
size_t SerialPort::write(const uint8_t* data, size_t length) {
  std::lock_guard<std::mutex> lock(fake.mutex);
  const size_t count = std::min(length, size_t(7));
  fake.serial_output.insert(fake.serial_output.end(), data, data + count);
  return count;
}
bool SerialPort::write_pending() const { return false; }
bool SerialPort::close() {
  std::lock_guard<std::mutex> lock(fake.mutex);
  fake.serial_open = false;
  return true;
}

struct TcpServer::Impl {};
TcpServer::TcpServer() : impl_(new Impl) {}
TcpServer::~TcpServer() { close(); }
void TcpServer::listen(const char*, uint16_t) {
  std::lock_guard<std::mutex> lock(fake.mutex);
  fake.listening = true;
}
int TcpServer::accept(const char*) {
  std::lock_guard<std::mutex> lock(fake.mutex);
  if (fake.reject_busy) {
    fake.reject_busy = false;
    return 2;
  }
  if (fake.reject_ip) {
    fake.reject_ip = false;
    return 3;
  }
  if (!fake.admit_client || fake.client_connected) return 0;
  fake.admit_client = false;
  fake.client_connected = true;
  return 1;
}
bool TcpServer::connected() const {
  std::lock_guard<std::mutex> lock(fake.mutex);
  return fake.client_connected;
}
bool TcpServer::close_client() {
  std::lock_guard<std::mutex> lock(fake.mutex);
  fake.client_connected = false;
  return true;
}
int64_t TcpServer::receive(uint8_t* data, size_t capacity) {
  std::lock_guard<std::mutex> lock(fake.mutex);
  if (fake.disconnect_client) {
    fake.disconnect_client = false;
    return 0;
  }
  if (fake.tcp_input.empty()) return -1;
  const size_t count = std::min({capacity, size_t(17), fake.tcp_input.size()});
  for (size_t index = 0; index < count; ++index) {
    data[index] = fake.tcp_input.front();
    fake.tcp_input.pop_front();
  }
  return static_cast<int64_t>(count);
}
size_t TcpServer::send(const uint8_t* data, size_t length) {
  std::lock_guard<std::mutex> lock(fake.mutex);
  const size_t count = std::min(length, size_t(11));
  fake.tcp_output.insert(fake.tcp_output.end(), data, data + count);
  return count;
}
bool TcpServer::close() {
  std::lock_guard<std::mutex> lock(fake.mutex);
  fake.listening = false;
  fake.client_connected = false;
  return true;
}

} // namespace povad

int main() {
  try {
    test_repeated_full_duplex_relay();
    std::cout << "PASS repeated full-duplex worker relay\n";
    test_wait_next_client_and_rejections();
    std::cout << "PASS three sequential clients and busy rejection\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "FAIL " << error.what() << '\n';
    return 1;
  }
}
