#ifndef POVAD_CORE_H
#define POVAD_CORE_H

#include <stdint.h>

#if defined(_WIN32)
#if defined(POVAD_CORE_BUILD)
#define PV_API __declspec(dllexport)
#else
#define PV_API __declspec(dllimport)
#endif
#else
#define PV_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define PV_ABI_VERSION 1u

enum pv_result {
  PV_OK = 0,
  PV_ABI_MISMATCH = 1,
  PV_INVALID_CONFIG = 2,
  PV_LAN_CONSENT_REQUIRED = 3
};

// All fields are fixed width. Strings are UTF-8 and must be NUL terminated.
// This v1 contract currently defines desktop serial ports and IPv4 listeners.
typedef struct pv_config {
  uint32_t size;
  uint32_t abi;
  uint32_t baud;
  uint32_t data_bits;
  uint32_t parity;        // ASCII N, E, or O.
  uint32_t stop_bits_x10; // 10 or 20.
  uint32_t hardware_flow;
  uint32_t dtr;
  uint32_t rts;
  uint32_t tcp_port;
  uint32_t allow_lan;
  uint32_t queue_limit;
  uint32_t queue_age_ms;
  char serial_port[256];
  char bind_address[64];
} pv_config;

typedef struct pv_error {
  uint32_t size;
  uint32_t code;
  char message[192];
} pv_error;

PV_API uint32_t pv_abi_version(void);
PV_API uint32_t pv_config_size(void);
PV_API uint32_t pv_error_size(void);

// Does not open a device or listener. `error` is optional; when supplied its
// size must equal pv_error_size(). No caller-owned memory is retained.
PV_API int32_t pv_config_validate(const pv_config* config, pv_error* error);

#ifdef __cplusplus
}
#endif

#endif
