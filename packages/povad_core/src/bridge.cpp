#include "bridge.hpp"
#include "byte_queue.hpp"
#include "transport.hpp"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <memory>
#include <string>

namespace povad {
namespace {

uint64_t monotonic_ms() {
  return static_cast<uint64_t>(
      std::chrono::duration_cast<std::chrono::milliseconds>(
          std::chrono::steady_clock::now().time_since_epoch()).count());
}

} // namespace

Bridge::Bridge() {
  status_.size = sizeof(status_);
  status_.state = PV_STATE_STOPPED;
}

Bridge::~Bridge() {
  // The public destroy entry point refuses a live worker. This join only
  // reclaims a thread whose worker has already released every native handle.
  if (worker_.joinable()) worker_.join();
}

int32_t Bridge::start(const pv_config& config) {
  if (!finished_) return PV_BUSY;
  if (worker_.joinable()) worker_.join();
  {
    std::lock_guard<std::mutex> lock(mutex_);
    status_ = {};
    status_.size = sizeof(status_);
    status_.state = PV_STATE_STARTING;
  }
  stop_ = false;
  finished_ = false;
  try {
    worker_ = std::thread([this, config] { run(config); });
  } catch (...) {
    finish(PV_STATE_FAULT, PV_NATIVE_FAILURE, "Cannot start transport worker");
    return PV_NATIVE_FAILURE;
  }
  return PV_OK;
}

void Bridge::request_stop() {
  if (finished_) return;
  stop_ = true;
  std::lock_guard<std::mutex> lock(mutex_);
  if (!finished_) status_.state = PV_STATE_STOPPING;
}

void Bridge::snapshot(pv_snapshot* output) const {
  std::lock_guard<std::mutex> lock(mutex_);
  *output = status_;
}

void Bridge::set_state(uint32_t state, bool serial_open, bool connected) {
  std::lock_guard<std::mutex> lock(mutex_);
  status_.state = stop_ ? static_cast<uint32_t>(PV_STATE_STOPPING) : state;
  status_.serial_open = serial_open ? 1u : 0u;
  status_.client_connected = connected ? 1u : 0u;
}

void Bridge::add_tcp_received(size_t bytes) {
  std::lock_guard<std::mutex> lock(mutex_);
  status_.tcp_received += bytes;
}
void Bridge::add_serial_received(size_t bytes) {
  std::lock_guard<std::mutex> lock(mutex_);
  status_.serial_received += bytes;
}
void Bridge::add_serial_accepted(size_t bytes) {
  std::lock_guard<std::mutex> lock(mutex_);
  status_.serial_accepted += bytes;
}
void Bridge::add_tcp_accepted(size_t bytes) {
  std::lock_guard<std::mutex> lock(mutex_);
  status_.tcp_accepted += bytes;
}

void Bridge::finish(uint32_t state, uint32_t error_code, const char* message) {
  std::lock_guard<std::mutex> lock(mutex_);
  status_.state = state;
  status_.serial_open = 0;
  status_.client_connected = 0;
  status_.error_code = error_code;
  std::snprintf(status_.error_message, sizeof(status_.error_message), "%s", message);
  finished_ = true;
}

void Bridge::run(pv_config config) noexcept {
  uint32_t final_state = PV_STATE_STOPPED;
  uint32_t error_code = PV_OK;
  std::string message;
  std::unique_ptr<SerialPort> serial;
  std::unique_ptr<TcpServer> tcp;
  try {
    serial.reset(new SerialPort());
    tcp.reset(new TcpServer());
    if (!stop_) {
      serial->open(config);
      set_state(PV_STATE_STARTING, true, false);
    }
    if (!stop_) {
      tcp->listen(config.bind_address, static_cast<uint16_t>(config.tcp_port));
      set_state(PV_STATE_LISTENING, true, false);
    }
    ByteQueue to_serial(config.queue_limit);
    ByteQueue to_tcp(config.queue_limit);
    uint8_t buffer[4096];
    while (!stop_) {
      bool progressed = false;
      const int arrival = tcp->accept();
      if (arrival == 1) {
        set_state(PV_STATE_CONNECTED, true, true);
        progressed = true;
      }
      if (tcp->connected()) {
        // Complete pending writes before admitting more input. Read sizes are
        // bounded by the remaining queue capacity to provide backpressure.
        if (!to_serial.empty()) {
          const size_t sent = serial->write(to_serial.front_data(),
              std::min(to_serial.front_size(), sizeof(buffer)));
          if (sent != 0) {
            to_serial.consume(sent);
            add_serial_accepted(sent);
            progressed = true;
          }
        }
        if (!to_tcp.empty()) {
          const size_t sent = tcp->send(to_tcp.front_data(),
              std::min(to_tcp.front_size(), sizeof(buffer)));
          if (sent != 0) {
            to_tcp.consume(sent);
            add_tcp_accepted(sent);
            progressed = true;
          }
        }
        const size_t serial_room = config.queue_limit - to_tcp.size();
        if (serial_room != 0) {
          const size_t count = serial->read(buffer, std::min(serial_room, sizeof(buffer)));
          if (count != 0) {
            to_tcp.push(buffer, count, monotonic_ms());
            add_serial_received(count);
            progressed = true;
          }
        }
        const size_t tcp_room = config.queue_limit - to_serial.size();
        if (tcp_room != 0) {
          const int64_t count = tcp->receive(buffer, std::min(tcp_room, sizeof(buffer)));
          if (count == 0) {
            final_state = PV_STATE_INTERRUPTED;
            if (!to_serial.empty() || !to_tcp.empty() || serial->write_pending()) {
              error_code = PV_DELIVERY_UNCERTAIN;
              message = "Client closed with output pending; delivery is uncertain";
            } else {
              message = "Client disconnected; restart for another session";
            }
            break;
          }
          if (count > 0) {
            to_serial.push(buffer, static_cast<size_t>(count), monotonic_ms());
            add_tcp_received(static_cast<size_t>(count));
            progressed = true;
          }
        }
        to_serial.check_age(monotonic_ms(), config.queue_age_ms);
        to_tcp.check_age(monotonic_ms(), config.queue_age_ms);
      } else {
        // Bytes with no client have no owner. Discard them without capture.
        if (serial->read(buffer, sizeof(buffer)) != 0) progressed = true;
      }
      if (!progressed) std::this_thread::sleep_for(std::chrono::milliseconds(2));
    }
    if (stop_ && (!to_serial.empty() || !to_tcp.empty() || serial->write_pending())) {
      final_state = PV_STATE_INTERRUPTED;
      error_code = PV_DELIVERY_UNCERTAIN;
      message = "Stopped with output pending; delivery is uncertain";
    }
  } catch (const TransportError& error) {
    final_state = PV_STATE_FAULT;
    error_code = static_cast<uint32_t>(error.code);
    message = error.what();
  } catch (const QueueError& error) {
    final_state = PV_STATE_FAULT;
    error_code = error.reason == QueueFailure::age ? PV_DELIVERY_UNCERTAIN : PV_NATIVE_FAILURE;
    message = error.reason == QueueFailure::age ?
        "Output queue exceeded its age limit; delivery is uncertain" :
        "Output queue failed";
  } catch (...) {
    final_state = PV_STATE_FAULT;
    error_code = PV_NATIVE_FAILURE;
    message = "Transport worker failed";
  }
  // Only the worker releases live handles. Windows OVERLAPPED cancellation
  // must complete inside SerialPort::close before finished_ becomes true.
  set_state(PV_STATE_STOPPING, serial != nullptr, tcp != nullptr && tcp->connected());
  bool tcp_closed = tcp == nullptr || tcp->close();
  bool serial_closed = serial == nullptr || serial->close();
  while (!tcp_closed || !serial_closed) {
    // The worker keeps ownership until every handle is confirmed closed.
    // A timeout in the Dart owner must not turn this into a clean stop.
    {
      std::lock_guard<std::mutex> lock(mutex_);
      status_.state = PV_STATE_STOPPING;
      status_.serial_open = serial_closed ? 0u : 1u;
      status_.client_connected = 0;
      status_.error_code = PV_NATIVE_FAILURE;
      std::snprintf(status_.error_message, sizeof(status_.error_message), "%s",
          !tcp_closed && !serial_closed ? "Transport shutdown could not be confirmed" :
          !tcp_closed ? "TCP shutdown could not be confirmed" :
          "Serial shutdown could not be confirmed");
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
    if (!tcp_closed) tcp_closed = tcp->close();
    if (!serial_closed) serial_closed = serial->close();
  }
  finish(final_state, error_code, message.c_str());
}

} // namespace povad
