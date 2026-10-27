#pragma once

#include "povad_core.h"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <stdexcept>
#include <string_view>

namespace povad {

#if defined(__ANDROID__)
void set_android_ble_host(void* vm, void* type, void* open_method);
#endif

inline bool peer_allowed(std::string_view list, std::string_view peer) {
  if (list.empty()) return true;
  while (!list.empty()) {
    const size_t separator = list.find(',');
    const auto candidate = list.substr(0, separator);
    if (candidate == peer) return true;
    if (separator == std::string_view::npos) break;
    list.remove_prefix(separator + 1);
  }
  return false;
}

class TransportError final : public std::runtime_error {
 public:
  TransportError(int32_t code, const char* message) : std::runtime_error(message), code(code) {}
  int32_t code;
};

class SerialPort final {
 public:
  SerialPort();
  ~SerialPort();
  SerialPort(const SerialPort&) = delete;
  SerialPort& operator=(const SerialPort&) = delete;
  void open(const pv_config& config);
  size_t read(uint8_t* data, size_t capacity);
  size_t write(const uint8_t* data, size_t length);
  bool write_pending() const;
  // False means the serial handle's shutdown could not be confirmed.
  bool close();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

class TcpServer final {
 public:
  TcpServer();
  ~TcpServer();
  TcpServer(const TcpServer&) = delete;
  TcpServer& operator=(const TcpServer&) = delete;
  void listen(const char* address, uint16_t port);
  // 0: none, 1: admitted, 2: busy rejected, 3: IP rejected.
  int accept(const char* allowed_clients);
  bool connected() const;
  // Keeps the listener open for a later client. False means close uncertain.
  bool close_client();
  // -1: would block, 0: peer closed, positive: byte count.
  int64_t receive(uint8_t* data, size_t capacity);
  size_t send(const uint8_t* data, size_t length);
  // False means socket shutdown could not be confirmed.
  bool close();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

// A platform GATT peripheral. Its methods are called by the bridge worker;
// platform callbacks only deliver bounded events to this worker-owned object.
class BleServer final {
 public:
  BleServer();
  ~BleServer();
  BleServer(const BleServer&) = delete;
  BleServer& operator=(const BleServer&) = delete;
  void listen(const pv_config& config);
  // 0: no event, 1: paired client subscribed, 2: additional client rejected,
  // 3: unpaired client rejected.
  int accept();
  bool connected() const;
  bool write_pending() const;
  bool close_client();
  // -1: no data, 0: client disconnected, positive: byte count.
  int64_t receive(uint8_t* data, size_t capacity);
  // Returns bytes accepted by the platform notification queue, or zero.
  size_t send(const uint8_t* data, size_t length);
  bool close();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

} // namespace povad
