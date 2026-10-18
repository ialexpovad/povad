#include "povad_core.h"
#include "byte_queue.hpp"

#include <array>
#include <cstring>
#include <iostream>
#include <stdexcept>

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
  require(sizeof(pv_config) == 372 && sizeof(pv_error) == 200, "Fixed ABI layout");
  require(pv_abi_version() == 1 && pv_config_size() == 372 && pv_error_size() == 200,
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

} // namespace

int main() {
  try {
    test_abi_and_validation();
    test_byte_queue();
    std::cout << "PASS Povad core ABI, config, and byte queue contracts\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "FAIL " << error.what() << '\n';
    return 1;
  }
}
