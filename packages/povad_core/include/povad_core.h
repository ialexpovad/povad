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
  PV_LAN_CONSENT_REQUIRED = 3,
  PV_BUSY = 4,
  PV_INVALID_HANDLE = 5,
  PV_NATIVE_FAILURE = 6,
  PV_DELIVERY_UNCERTAIN = 7,
  PV_UNSUPPORTED_PLATFORM = 8
};

enum pv_state {
  PV_STATE_STOPPED = 0,
  PV_STATE_STARTING = 1,
  PV_STATE_LISTENING = 2,
  PV_STATE_CONNECTED = 3,
  PV_STATE_STOPPING = 4,
  PV_STATE_INTERRUPTED = 5,
  PV_STATE_FAULT = 6
};

// All fields are fixed width. Strings are UTF-8 and must be NUL terminated.
// This v1 contract defines local serial selections and IPv4 listeners.
// Android selections use the usb:<device-name>:<port-index> form.
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

typedef struct pv_snapshot {
  uint32_t size;
  uint32_t state;
  uint32_t serial_open;
  uint32_t client_connected;
  uint64_t tcp_received;
  uint64_t serial_received;
  uint64_t serial_accepted;
  uint64_t tcp_accepted;
  uint32_t error_code;
  char error_message[192];
} pv_snapshot;

typedef struct pv_handle pv_handle;

PV_API uint32_t pv_abi_version(void);
PV_API uint32_t pv_config_size(void);
PV_API uint32_t pv_error_size(void);
PV_API uint32_t pv_snapshot_size(void);

// Does not open a device or listener. `error` is optional; when supplied its
// size must equal pv_error_size(). No caller-owned memory is retained.
PV_API int32_t pv_config_validate(const pv_config* config, pv_error* error);

// start returns after launching the worker, not after opening the port. Poll
// the snapshot for listening, connected, or fault. The worker owns all live
// handles and queues. A stop request is asynchronous; destroy returns PV_BUSY
// until the worker has completed cleanup. Control and destruction calls must
// be serialized by the caller; snapshots may be read while the worker runs.
// A disconnected client ends the generation, so late device bytes cannot be
// assigned to a successor.
PV_API pv_handle* pv_create(void);
PV_API int32_t pv_start(pv_handle* handle, const pv_config* config, pv_error* error);
PV_API int32_t pv_request_stop(pv_handle* handle);
PV_API int32_t pv_read_snapshot(pv_handle* handle, pv_snapshot* snapshot);
PV_API int32_t pv_destroy(pv_handle* handle);

#ifdef __cplusplus
}
#endif

#endif
