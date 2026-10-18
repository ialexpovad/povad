#include "bridge.hpp"
#include "transport.hpp"

#include <atomic>
#include <chrono>
#include <cstring>
#include <stdexcept>
#include <thread>

namespace {

std::atomic<bool> fail_serial_close{false};
std::atomic<unsigned> serial_close_attempts{0};

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

void test_shutdown(bool fail) {
  fail_serial_close = fail;
  serial_close_attempts = 0;
  pv_config config{};
  config.queue_limit = 4096;
  config.queue_age_ms = 1000;
  povad::Bridge bridge;
  struct CloseRecovery final {
    ~CloseRecovery() { fail_serial_close = false; }
  } recovery;
  require(bridge.start(config) == PV_OK, "Worker start");
  wait_for(bridge, PV_STATE_LISTENING);
  bridge.request_stop();
  if (fail) {
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(3);
    pv_snapshot pending{};
    do {
      bridge.snapshot(&pending);
      if (pending.error_code == PV_NATIVE_FAILURE) break;
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
    } while (std::chrono::steady_clock::now() < deadline);
    require(pending.state == PV_STATE_STOPPING && pending.error_code == PV_NATIVE_FAILURE,
        "Failed shutdown stays pending with an error");
    require(pending.serial_open == 1 && !bridge.finished(),
        "Unconfirmed serial close keeps worker ownership");
    require(std::strstr(pending.error_message, "shutdown could not be confirmed") != nullptr,
        "Shutdown failure message");
    fail_serial_close = false;
  }
  const auto snapshot = wait_for(bridge, PV_STATE_STOPPED);
  require(bridge.finished(), "Worker finished after confirmed serial close");
  require(snapshot.error_code == PV_OK && snapshot.serial_open == 0,
      "Confirmed shutdown is clean");
  require(serial_close_attempts >= (fail ? 2u : 1u), "Serial close attempted");
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
void TcpServer::close() {}

} // namespace povad

int main() {
  test_shutdown(false);
  test_shutdown(true);
  return 0;
}
