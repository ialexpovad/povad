#include "transport.hpp"

namespace povad {
struct BleServer::Impl {};
BleServer::BleServer() : impl_(new Impl) {}
BleServer::~BleServer() = default;
void BleServer::listen(const pv_config&) {
  throw TransportError(PV_UNSUPPORTED_PLATFORM, "BLE test peer unavailable");
}
int BleServer::accept() { return 0; }
bool BleServer::connected() const { return false; }
bool BleServer::write_pending() const { return false; }
bool BleServer::close_client() { return true; }
int64_t BleServer::receive(uint8_t*, size_t) { return -1; }
size_t BleServer::send(const uint8_t*, size_t) { return 0; }
bool BleServer::close() { return true; }
} // namespace povad
