#include "povad_core.h"
#include "bridge.hpp"

#include <cstdio>
#include <cstring>
#include <new>
#include <cctype>

struct pv_handle { povad::Bridge core; };

namespace {

bool terminated(const char* text, size_t capacity) {
  return std::memchr(text, '\0', capacity) != nullptr;
}

bool ble_uuid_valid(const char* text) {
  const size_t length = std::strlen(text);
  if (length != 4 && length != 36) return false;
  for (size_t i = 0; i < length; ++i) {
    if (length == 36 && (i == 8 || i == 13 || i == 18 || i == 23)) {
      if (text[i] != '-') return false;
    } else if (!std::isxdigit(static_cast<unsigned char>(text[i]))) {
      return false;
    }
  }
  return true;
}

bool same_ble_uuid(const char* first, const char* second) {
  char a[37]{};
  char b[37]{};
  const auto canonical = [](const char* source, char* target) {
    if (std::strlen(source) == 4) {
      std::snprintf(target, 37, "0000%s-0000-1000-8000-00805f9b34fb", source);
    } else {
      std::snprintf(target, 37, "%s", source);
    }
    for (size_t i = 0; target[i] != '\0'; ++i) {
      target[i] = static_cast<char>(std::tolower(static_cast<unsigned char>(target[i])));
    }
  };
  canonical(first, a);
  canonical(second, b);
  return std::strcmp(a, b) == 0;
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

bool allowed_clients_valid(const char* text) {
  if (*text == '\0') return true;
  unsigned entries = 0;
  while (*text != '\0') {
    char address[16]{};
    unsigned length = 0;
    while (*text != '\0' && *text != ',') {
      if (length >= sizeof(address) - 1) return false;
      address[length++] = *text++;
    }
    uint8_t octets[4]{};
    if (length == 0 || !ipv4(address, octets) || ++entries > 32) return false;
    if (*text == ',') {
      ++text;
      if (*text == '\0') return false;
    }
  }
  return true;
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
      !terminated(config->bind_address, sizeof(config->bind_address)) ||
      !terminated(config->allowed_clients, sizeof(config->allowed_clients)) ||
      !terminated(config->ble_name, sizeof(config->ble_name)) ||
      !terminated(config->ble_service_uuid, sizeof(config->ble_service_uuid)) ||
      !terminated(config->ble_write_uuid, sizeof(config->ble_write_uuid)) ||
      !terminated(config->ble_notify_uuid, sizeof(config->ble_notify_uuid))) {
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
  if (config->peer_kind > PV_PEER_BLE || config->wait_next_client > 1 ||
      config->ble_require_pairing > 1 ||
      config->queue_limit < 4096 ||
      config->queue_limit > 1048576 || config->queue_age_ms < 100 ||
      config->queue_age_ms > 30000) {
    return fail(error, PV_INVALID_CONFIG, "Invalid listener or queue setting");
  }
  if (config->peer_kind == PV_PEER_BLE) {
    if (config->ble_name[0] == '\0' || std::strlen(config->ble_name) > 29 ||
        !ble_uuid_valid(config->ble_service_uuid) ||
        !ble_uuid_valid(config->ble_write_uuid) ||
        !ble_uuid_valid(config->ble_notify_uuid) ||
        same_ble_uuid(config->ble_service_uuid, config->ble_write_uuid) ||
        same_ble_uuid(config->ble_service_uuid, config->ble_notify_uuid) ||
        same_ble_uuid(config->ble_write_uuid, config->ble_notify_uuid)) {
      return fail(error, PV_INVALID_CONFIG, "Invalid BLE service or characteristics");
    }
    if (error != nullptr) {
      error->code = PV_OK;
      error->message[0] = '\0';
    }
    return PV_OK;
  }
  if (config->tcp_port == 0 || config->tcp_port > 65535 || config->allow_lan > 1) {
    return fail(error, PV_INVALID_CONFIG, "Invalid TCP listener");
  }
  uint8_t octets[4]{};
  if (!ipv4(config->bind_address, octets) ||
      (octets[0] == 0 && std::strcmp(config->bind_address, "0.0.0.0") != 0) ||
      octets[0] >= 224 || (octets[0] == 169 && octets[1] == 254)) {
    return fail(error, PV_INVALID_CONFIG, "Select a concrete IPv4 unicast address");
  }
  if ((octets[0] != 127 || std::strcmp(config->bind_address, "0.0.0.0") == 0) &&
      config->allow_lan == 0) {
    return fail(error, PV_LAN_CONSENT_REQUIRED, "LAN listening requires explicit consent");
  }
  if (!allowed_clients_valid(config->allowed_clients) ||
      (config->allowed_clients[0] != '\0' && config->allow_lan == 0)) {
    return fail(error, PV_INVALID_CONFIG, "Allowed clients require LAN mode and exact IPv4 addresses");
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
