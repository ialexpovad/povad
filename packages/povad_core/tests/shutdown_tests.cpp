#include "bridge.hpp"
#include "transport.hpp"

#include <atomic>
#include <chrono>
#include <cstring>
#include <stdexcept>
#include <thread>

namespace {

std::atomic<bool> fail_serial_close{false};
std::atomic<bool> fail_tcp_close{false};
std::atomic<unsigned> serial_close_attempts{0};
std::atomic<unsigned> tcp_close_attempts{0};

void require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}

pv_snapshot wait_for(povad::Bridge& bridge, uint32_t state) {
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(3);
  pv_snapshot snapshot{};
  while (std::chrono::steady_clock::now() < deadline) {
    bridge.snapshot(&snapshot);
    if (snapshot.state == state) return snapshot;
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }
  throw std::runtime_error("Worker did not reach the expected state");
}

void test_shutdown(bool serial_failure, bool tcp_failure) {
  fail_serial_close = serial_failure;
  fail_tcp_close = tcp_failure;
  serial_close_attempts = 0;
  tcp_close_attempts = 0;
  pv_config config{};
  config.queue_limit = 4096;
  config.queue_age_ms = 1000;
  povad::Bridge bridge;
  struct CloseRecovery final {
    ~CloseRecovery() {
      fail_serial_close = false;
      fail_tcp_close = false;
    }
  } recovery;
  require(bridge.start(config) == PV_OK, "Worker start");
  wait_for(bridge, PV_STATE_LISTENING);
  bridge.request_stop();
  if (serial_failure || tcp_failure) {
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(3);
    pv_snapshot pending{};
    do {
      bridge.snapshot(&pending);
      if (pending.error_code == PV_NATIVE_FAILURE) break;
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
    } while (std::chrono::steady_clock::now() < deadline);
    require(pending.state == PV_STATE_STOPPING && pending.error_code == PV_NATIVE_FAILURE,
        "Failed shutdown stays pending with an error");
    require(pending.serial_open == (serial_failure ? 1u : 0u) && !bridge.finished(),
        "Unconfirmed close keeps worker ownership");
    require(std::strstr(pending.error_message, "shutdown could not be confirmed") != nullptr,
        "Shutdown failure message");
    fail_serial_close = false;
    fail_tcp_close = false;
  }
  const auto snapshot = wait_for(bridge, PV_STATE_STOPPED);
  require(bridge.finished(), "Worker finished after confirmed serial close");
  require(snapshot.error_code == PV_OK && snapshot.serial_open == 0,
      "Confirmed shutdown is clean");
  require(serial_close_attempts >= (serial_failure ? 2u : 1u), "Serial close attempted");
  require(tcp_close_attempts >= (tcp_failure ? 2u : 1u), "TCP close attempted");
}

} // namespace

namespace povad {

struct SerialPort::Impl {};
SerialPort::SerialPort() : impl_(new Impl) {}
SerialPort::~SerialPort() { close(); }
void SerialPort::open(const pv_config&) {}
size_t SerialPort::read(uint8_t*, size_t) { return 0; }
size_t SerialPort::write(const uint8_t*, size_t length) { return length; }
bool SerialPort::write_pending() const { return false; }
bool SerialPort::close() {
  ++serial_close_attempts;
  return !fail_serial_close;
}

struct TcpServer::Impl {};
TcpServer::TcpServer() : impl_(new Impl) {}
TcpServer::~TcpServer() = default;
void TcpServer::listen(const char*, uint16_t) {}
int TcpServer::accept() { return 0; }
bool TcpServer::connected() const { return false; }
int64_t TcpServer::receive(uint8_t*, size_t) { return -1; }
size_t TcpServer::send(const uint8_t*, size_t length) { return length; }
bool TcpServer::close() {
  ++tcp_close_attempts;
  return !fail_tcp_close;
}

} // namespace povad

int main() {
  test_shutdown(false, false);
  test_shutdown(true, false);
  test_shutdown(false, true);
  test_shutdown(true, true);
  return 0;
}
