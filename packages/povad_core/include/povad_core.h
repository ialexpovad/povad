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

#define PV_ABI_VERSION 3u

enum pv_peer_kind { PV_PEER_TCP = 0, PV_PEER_BLE = 1 };

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
// This v3 contract defines local serial selections and TCP or BLE peers.
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
  uint32_t wait_next_client; // 0 ends on disconnect; 1 keeps listening.
  char allowed_clients[512]; // Comma-separated exact IPv4 addresses, or empty.
  uint32_t peer_kind;
  char ble_name[64];
  char ble_service_uuid[37];
  char ble_write_uuid[37];
  char ble_notify_uuid[37];
  // 1: writes and the notification subscription need an encrypted, bonded
  // link. 0: open, as common BLE UART modules (BT24, HM-10) are, so their
  // clients connect without pairing; any nearby client may then connect.
  uint32_t ble_require_pairing;
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
  uint32_t rejected_busy;
  uint32_t rejected_ip;
  uint64_t ble_received;
  uint64_t ble_accepted;
  uint32_t rejected_unpaired;
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
// In wait-next mode pending queues are discarded on disconnect. Late serial
// responses after a successor connects remain protocol-ambiguous; callers
// must use this mode only when that risk is acceptable.
PV_API pv_handle* pv_create(void);
PV_API int32_t pv_start(pv_handle* handle, const pv_config* config, pv_error* error);
PV_API int32_t pv_request_stop(pv_handle* handle);
PV_API int32_t pv_read_snapshot(pv_handle* handle, pv_snapshot* snapshot);
PV_API int32_t pv_destroy(pv_handle* handle);

#ifdef __cplusplus
}
#endif

#endif
