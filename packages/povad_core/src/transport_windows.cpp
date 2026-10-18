#include "transport.hpp"

namespace povad {

// The Windows worker is introduced after the POSIX PTY contract tests pass.
// This adapter explicitly reports its status; it never pretends to open COM.
struct SerialPort::Impl {};
SerialPort::SerialPort() : impl_(new Impl) {}
SerialPort::~SerialPort() = default;
void SerialPort::open(const pv_config&) {
  throw TransportError(PV_UNSUPPORTED_PLATFORM, "Windows serial adapter is not implemented");
}
size_t SerialPort::read(uint8_t*, size_t) { return 0; }
size_t SerialPort::write(const uint8_t*, size_t) { return 0; }
bool SerialPort::write_pending() const { return false; }
void SerialPort::close() {}

struct TcpServer::Impl {};
TcpServer::TcpServer() : impl_(new Impl) {}
TcpServer::~TcpServer() = default;
void TcpServer::listen(const char*, uint16_t) {
  throw TransportError(PV_UNSUPPORTED_PLATFORM, "Windows TCP adapter is not implemented");
}
int TcpServer::accept() { return 0; }
bool TcpServer::connected() const { return false; }
int64_t TcpServer::receive(uint8_t*, size_t) { return -1; }
size_t TcpServer::send(const uint8_t*, size_t) { return 0; }
void TcpServer::close() {}

} // namespace povad
