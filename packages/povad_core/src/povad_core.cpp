#include "povad_core.h"
#include "bridge.hpp"

#include <cstdio>
#include <cstring>
#include <new>

struct pv_handle { povad::Bridge core; };

namespace {

bool terminated(const char* text, size_t capacity) {
  return std::memchr(text, '\0', capacity) != nullptr;
}

bool ipv4(const char* text, uint8_t octets[4]) {
  for (int index = 0; index < 4; ++index) {
    if (*text < '0' || *text > '9') return false;
    unsigned value = 0;
    unsigned digits = 0;
    const char first = *text;
    while (*text >= '0' && *text <= '9') {
      if (++digits > 3 || (digits > 1 && first == '0')) return false;
      value = value * 10 + static_cast<unsigned>(*text++ - '0');
      if (value > 255) return false;
    }
    octets[index] = static_cast<uint8_t>(value);
    if (index < 3 && *text++ != '.') return false;
  }
  return *text == '\0';
}

int32_t fail(pv_error* error, int32_t code, const char* message) {
  if (error != nullptr && error->size == sizeof(pv_error)) {
    error->code = static_cast<uint32_t>(code);
    std::snprintf(error->message, sizeof(error->message), "%s", message);
  }
  return code;
}

} // namespace

extern "C" {

uint32_t pv_abi_version(void) { return PV_ABI_VERSION; }
uint32_t pv_config_size(void) { return sizeof(pv_config); }
uint32_t pv_error_size(void) { return sizeof(pv_error); }
uint32_t pv_snapshot_size(void) { return sizeof(pv_snapshot); }

int32_t pv_config_validate(const pv_config* config, pv_error* error) {
  if (error != nullptr && error->size != sizeof(pv_error)) return PV_ABI_MISMATCH;
  if (config == nullptr || config->size != sizeof(pv_config) || config->abi != PV_ABI_VERSION) {
    return fail(error, PV_ABI_MISMATCH, "Configuration ABI mismatch");
  }
  if (!terminated(config->serial_port, sizeof(config->serial_port)) ||
      !terminated(config->bind_address, sizeof(config->bind_address))) {
    return fail(error, PV_INVALID_CONFIG, "Unterminated configuration field");
  }
  if (config->serial_port[0] == '\0' ||
      std::strstr(config->serial_port, "://") != nullptr) {
    return fail(error, PV_INVALID_CONFIG, "Select a local serial port");
  }
  if (config->baud < 300 || config->baud > 4000000 ||
      config->data_bits < 5 || config->data_bits > 8 ||
      (config->parity != 'N' && config->parity != 'E' && config->parity != 'O') ||
      (config->stop_bits_x10 != 10 && config->stop_bits_x10 != 20) ||
      config->hardware_flow > 1 || config->dtr > 1 || config->rts > 1) {
    return fail(error, PV_INVALID_CONFIG, "Invalid serial format");
  }
  if (config->tcp_port == 0 || config->tcp_port > 65535 ||
      config->allow_lan > 1 || config->queue_limit < 4096 ||
      config->queue_limit > 1048576 || config->queue_age_ms < 100 ||
      config->queue_age_ms > 30000) {
    return fail(error, PV_INVALID_CONFIG, "Invalid listener or queue setting");
  }
  uint8_t octets[4]{};
  if (!ipv4(config->bind_address, octets) || octets[0] == 0 ||
      octets[0] >= 224 || (octets[0] == 169 && octets[1] == 254)) {
    return fail(error, PV_INVALID_CONFIG, "Select a concrete IPv4 unicast address");
  }
  if (octets[0] != 127 && config->allow_lan == 0) {
    return fail(error, PV_LAN_CONSENT_REQUIRED, "LAN listening requires explicit consent");
  }
  if (error != nullptr) {
    error->code = PV_OK;
    error->message[0] = '\0';
  }
  return PV_OK;
}

pv_handle* pv_create(void) {
  try {
    return new pv_handle();
  } catch (...) {
    return nullptr;
  }
}

int32_t pv_start(pv_handle* handle, const pv_config* config, pv_error* error) {
  if (handle == nullptr) return fail(error, PV_INVALID_HANDLE, "Null bridge handle");
  const int32_t validated = pv_config_validate(config, error);
  if (validated != PV_OK) return validated;
  try {
    const int32_t result = handle->core.start(*config);
    if (result != PV_OK) return fail(error, result, "Bridge is already running or could not start");
    return PV_OK;
  } catch (...) {
    return fail(error, PV_NATIVE_FAILURE, "Cannot start bridge worker");
  }
}

int32_t pv_request_stop(pv_handle* handle) {
  if (handle == nullptr) return PV_INVALID_HANDLE;
  try {
    handle->core.request_stop();
    return PV_OK;
  } catch (...) {
    return PV_NATIVE_FAILURE;
  }
}

int32_t pv_read_snapshot(pv_handle* handle, pv_snapshot* snapshot) {
  if (handle == nullptr) return PV_INVALID_HANDLE;
  if (snapshot == nullptr || snapshot->size != sizeof(pv_snapshot)) return PV_ABI_MISMATCH;
  try {
    handle->core.snapshot(snapshot);
    return PV_OK;
  } catch (...) {
    return PV_NATIVE_FAILURE;
  }
}

int32_t pv_destroy(pv_handle* handle) {
  if (handle == nullptr) return PV_OK;
  try {
    if (!handle->core.finished()) return PV_BUSY;
    delete handle;
    return PV_OK;
  } catch (...) {
    return PV_NATIVE_FAILURE;
  }
}

} // extern "C"
