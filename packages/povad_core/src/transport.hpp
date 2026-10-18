#pragma once

#include "povad_core.h"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <stdexcept>

namespace povad {

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
  // 0: no arrival, 1: admitted, 2: extra client rejected.
  int accept();
  bool connected() const;
  // -1: would block, 0: peer closed, positive: byte count.
  int64_t receive(uint8_t* data, size_t capacity);
  size_t send(const uint8_t* data, size_t length);
  void close();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

} // namespace povad
