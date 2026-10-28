// BLE GATT peripheral on Windows 10 1803+ through WinRT's
// GattServiceProvider (C++/WinRT, linked with windowsapp). Event handlers run
// on WinRT thread-pool threads and only touch state under the mutex; close()
// stops advertising and revokes every handler before the provider is released.
//
// Windows advertises a GATT service under the computer's own Bluetooth name:
// the configured name cannot be set here, so clients find this bridge by its
// service UUID (or the computer is named as clients expect).
#include "transport.hpp"

#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.Streams.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <deque>
#include <mutex>
#include <string>
#include <vector>

namespace gatt = winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;
namespace streams = winrt::Windows::Storage::Streams;

namespace {

std::atomic<bool> adapter_reserved{false};

uint64_t now_ms() {
  return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
      std::chrono::steady_clock::now().time_since_epoch()).count());
}

winrt::guid parse_uuid(const char* value) {
  std::string uuid(value);
  if (uuid.size() == 4) uuid = "0000" + uuid + "-0000-1000-8000-00805f9b34fb";
  return winrt::guid(uuid);
}

} // namespace

namespace povad {

struct BleServer::Impl {
  gatt::GattServiceProvider provider{nullptr};
  gatt::GattLocalCharacteristic write_characteristic{nullptr};
  gatt::GattLocalCharacteristic notify_characteristic{nullptr};
  winrt::event_token write_token{};
  winrt::event_token subscribers_token{};
  winrt::event_token advertising_token{};
  bool write_handler_registered = false;
  bool subscribers_handler_registered = false;
  bool advertising_handler_registered = false;
  bool reserved = false;

  std::mutex mutex;
  std::condition_variable advertising_changed;
  gatt::GattServiceProviderAdvertisementStatus advertising_status =
      gatt::GattServiceProviderAdvertisementStatus::Created;
  bool advertising_event_seen = false;
  bool advertising_started = false;
  bool shutting_down = false;
  gatt::GattSubscribedClient owner{nullptr};
  std::wstring owner_id;   // The client's device ID (writes or subscription).
  bool disconnected = false;
  int event = 0;
  std::string fault;
  std::deque<std::vector<uint8_t>> incoming;
  std::deque<uint64_t> received_at;
  size_t incoming_offset = 0, incoming_size = 0;
  size_t limit = 65536;
  uint32_t max_age_ms = 2000;

  void on_advertisement(gatt::GattServiceProvider const& sender,
      gatt::GattServiceProviderAdvertisementStatusChangedEventArgs const& args) {
    try {
      std::lock_guard<std::mutex> lock(mutex);
      if (sender != provider) return;
      advertising_status = args.Status();
      advertising_event_seen = true;
      if (advertising_started && !shutting_down &&
          advertising_status != gatt::GattServiceProviderAdvertisementStatus::Started) {
        fault = "BLE advertising stopped or lost service data";
      }
      advertising_changed.notify_all();
    } catch (...) {
      std::lock_guard<std::mutex> lock(mutex);
      fault = "BLE advertising status failed";
      advertising_changed.notify_all();
    }
  }

  void claim(const std::wstring& device) {
    // Called with the mutex held: the first client owns the bridge.
    if (owner_id.empty()) {
      owner_id = device;
      disconnected = false;
      event = 1;
    }
  }

  void on_write(gatt::GattLocalCharacteristic const&,
      gatt::GattWriteRequestedEventArgs const& args) {
    auto deferral = args.GetDeferral();
    try {
      const auto request = args.GetRequestAsync().get();
      if (request == nullptr) {
        deferral.Complete();
        return;
      }
      const std::wstring device(args.Session().DeviceId().Id());
      const auto buffer = request.Value();
      std::vector<uint8_t> bytes(buffer.Length());
      streams::DataReader::FromBuffer(buffer).ReadBytes(bytes);
      bool refused = false;
      {
        std::lock_guard<std::mutex> lock(mutex);
        if (request.Offset() != 0) {
          refused = true;
        } else {
          claim(device);
        }
        if (!refused && (owner_id != device || disconnected)) {
          if (owner_id != device) event = 2;
          refused = true;
        } else if (!refused && bytes.size() > limit - incoming_size) {
          fault = "BLE input queue overflow; delivery is uncertain";
          refused = true;
        } else if (!refused && !bytes.empty()) {
          incoming_size += bytes.size();
          incoming.push_back(std::move(bytes));
          received_at.push_back(now_ms());
        }
      }
      if (request.Option() == gatt::GattWriteOption::WriteWithResponse) {
        if (refused) request.RespondWithProtocolError(gatt::GattProtocolError::WriteNotPermitted());
        else request.Respond();
      }
    } catch (...) {
      std::lock_guard<std::mutex> lock(mutex);
      fault = "BLE write handling failed; delivery is uncertain";
    }
    deferral.Complete();
  }

  void on_subscribers(gatt::GattLocalCharacteristic const& characteristic,
      winrt::Windows::Foundation::IInspectable const&) {
    try {
      const auto clients = characteristic.SubscribedClients();
      std::lock_guard<std::mutex> lock(mutex);
      if (owner != nullptr) {
        bool still = false;
        for (const auto& client : clients) {
          if (client == owner) still = true;
        }
        if (!still) {
          owner = nullptr;
          disconnected = true;
        }
        return;
      }
      for (const auto& client : clients) {
        const std::wstring device(client.Session().DeviceId().Id());
        claim(device);
        if (device == owner_id) {
          owner = client;
          return;
        }
        event = 2;
      }
    } catch (...) {
      std::lock_guard<std::mutex> lock(mutex);
      fault = "BLE subscription handling failed";
    }
  }

  bool stop() {
    {
      std::lock_guard<std::mutex> lock(mutex);
      shutting_down = true;
    }
    try {
      if (provider != nullptr) {
        const auto status = provider.AdvertisementStatus();
        if (status == gatt::GattServiceProviderAdvertisementStatus::Started ||
            status == gatt::GattServiceProviderAdvertisementStatus::StartedWithoutAllAdvertisementData)
          provider.StopAdvertising();
        if (write_handler_registered) {
          write_characteristic.WriteRequested(write_token);
          write_handler_registered = false;
        }
        if (subscribers_handler_registered) {
          notify_characteristic.SubscribedClientsChanged(subscribers_token);
          subscribers_handler_registered = false;
        }
        if (advertising_handler_registered) {
          provider.AdvertisementStatusChanged(advertising_token);
          advertising_handler_registered = false;
        }
      }
    } catch (...) {
      return false;
    }
    std::lock_guard<std::mutex> lock(mutex);
    owner = nullptr;
    owner_id.clear();
    incoming.clear();
    received_at.clear();
    incoming_size = 0;
    incoming_offset = 0;
    write_handler_registered = false;
    subscribers_handler_registered = false;
    advertising_handler_registered = false;
    advertising_started = false;
    advertising_event_seen = false;
    advertising_status = gatt::GattServiceProviderAdvertisementStatus::Created;
    shutting_down = false;
    write_characteristic = nullptr;
    notify_characteristic = nullptr;
    provider = nullptr;
    return true;
  }
};

BleServer::BleServer() : impl_(new Impl) {}
BleServer::~BleServer() { close(); }

void BleServer::listen(const pv_config& config) {
  if (!close()) throw TransportError(PV_NATIVE_FAILURE, "Previous BLE shutdown is uncertain");
  bool available = false;
  if (!adapter_reserved.compare_exchange_strong(available, true))
    throw TransportError(PV_BUSY, "Bluetooth adapter already has a Povad BLE bridge");
  auto& s = *impl_;
  s.reserved = true;
  s.limit = config.queue_limit;
  s.max_age_ms = config.queue_age_ms;
  s.fault.clear();
  const bool paired = config.ble_require_pairing != 0;
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
  } catch (...) {
    // The worker thread may already be in the multithreaded apartment.
  }
  try {
    const auto adapter = winrt::Windows::Devices::Bluetooth::BluetoothAdapter::GetDefaultAsync().get();
    if (adapter == nullptr || !adapter.IsPeripheralRoleSupported()) {
      close();
      throw TransportError(PV_UNSUPPORTED_PLATFORM,
          "This Bluetooth adapter does not support the BLE peripheral role");
    }
    const auto created = gatt::GattServiceProvider::CreateAsync(parse_uuid(config.ble_service_uuid)).get();
    if (created.Error() != winrt::Windows::Devices::Bluetooth::BluetoothError::Success) {
      close();
      throw TransportError(PV_UNSUPPORTED_PLATFORM, "Cannot publish BLE GATT service");
    }
    s.provider = created.ServiceProvider();

    gatt::GattLocalCharacteristicParameters write;
    write.CharacteristicProperties(paired ? gatt::GattCharacteristicProperties::Write :
        gatt::GattCharacteristicProperties::Write |
        gatt::GattCharacteristicProperties::WriteWithoutResponse);
    write.WriteProtectionLevel(paired ? gatt::GattProtectionLevel::EncryptionRequired :
        gatt::GattProtectionLevel::Plain);
    const auto write_result = s.provider.Service().CreateCharacteristicAsync(
        parse_uuid(config.ble_write_uuid), write).get();
    gatt::GattLocalCharacteristicParameters notify;
    notify.CharacteristicProperties(gatt::GattCharacteristicProperties::Notify);
    notify.ReadProtectionLevel(paired ? gatt::GattProtectionLevel::EncryptionRequired :
        gatt::GattProtectionLevel::Plain);
    const auto notify_result = s.provider.Service().CreateCharacteristicAsync(
        parse_uuid(config.ble_notify_uuid), notify).get();
    if (write_result.Error() != winrt::Windows::Devices::Bluetooth::BluetoothError::Success ||
        notify_result.Error() != winrt::Windows::Devices::Bluetooth::BluetoothError::Success) {
      close();
      throw TransportError(PV_UNSUPPORTED_PLATFORM, "Cannot publish BLE characteristics");
    }
    s.write_characteristic = write_result.Characteristic();
    s.notify_characteristic = notify_result.Characteristic();
    Impl* self = &s;
    s.write_token = s.write_characteristic.WriteRequested(
        [self](auto const& sender, auto const& args) { self->on_write(sender, args); });
    s.write_handler_registered = true;
    s.subscribers_token = s.notify_characteristic.SubscribedClientsChanged(
        [self](auto const& sender, auto const& args) { self->on_subscribers(sender, args); });
    s.subscribers_handler_registered = true;
    s.advertising_token = s.provider.AdvertisementStatusChanged(
        [self](auto const& sender, auto const& args) { self->on_advertisement(sender, args); });
    s.advertising_handler_registered = true;

    gatt::GattServiceProviderAdvertisingParameters advertising;
    advertising.IsConnectable(true);
    advertising.IsDiscoverable(true);
    s.provider.StartAdvertising(advertising);
    const auto status = s.provider.AdvertisementStatus();
    {
      std::unique_lock<std::mutex> lock(s.mutex);
      // StartAdvertising returns before the radio confirms its advertisement.
      // The status event can also arrive before this wait begins.
      if (!s.advertising_event_seen) s.advertising_status = status;
      s.advertising_changed.wait_for(lock, std::chrono::seconds(5), [&s] {
        return !s.fault.empty() ||
            s.advertising_status == gatt::GattServiceProviderAdvertisementStatus::Started ||
            s.advertising_status == gatt::GattServiceProviderAdvertisementStatus::StartedWithoutAllAdvertisementData ||
            s.advertising_status == gatt::GattServiceProviderAdvertisementStatus::Aborted;
      });
      if (s.fault.empty() &&
          s.advertising_status == gatt::GattServiceProviderAdvertisementStatus::Started)
        s.advertising_started = true;
    }
    if (!s.advertising_started) {
      close();
      throw TransportError(PV_UNSUPPORTED_PLATFORM,
          "BLE advertising did not start with complete service data");
    }
  } catch (const TransportError&) {
    throw;
  } catch (...) {
    close();
    throw TransportError(PV_UNSUPPORTED_PLATFORM, "Bluetooth LE peripheral is unavailable");
  }
}

int BleServer::accept() {
  std::lock_guard<std::mutex> lock(impl_->mutex);
  auto& s = *impl_;
  if (!s.incoming.empty() && now_ms() - s.received_at.front() > s.max_age_ms)
    s.fault = "BLE input queue timed out; delivery is uncertain";
  if (!s.fault.empty()) throw TransportError(PV_NATIVE_FAILURE, s.fault.c_str());
  const int event = s.event;
  s.event = 0;
  return event;
}

bool BleServer::connected() const {
  std::lock_guard<std::mutex> lock(impl_->mutex);
  return !impl_->owner_id.empty();
}

bool BleServer::write_pending() const {
  std::lock_guard<std::mutex> lock(impl_->mutex);
  return impl_->incoming_size != 0;
}

bool BleServer::close_client() {
  std::lock_guard<std::mutex> lock(impl_->mutex);
  auto& s = *impl_;
  s.owner = nullptr;
  s.owner_id.clear();
  s.disconnected = false;
  s.incoming.clear();
  s.received_at.clear();
  s.incoming_size = 0;
  s.incoming_offset = 0;
  return true;
}

int64_t BleServer::receive(uint8_t* data, size_t capacity) {
  std::lock_guard<std::mutex> lock(impl_->mutex);
  auto& s = *impl_;
  if (!s.fault.empty()) throw TransportError(PV_DELIVERY_UNCERTAIN, s.fault.c_str());
  if (s.disconnected) return 0;
  if (s.incoming.empty()) return -1;
  const auto& front = s.incoming.front();
  const size_t count = std::min(capacity, front.size() - s.incoming_offset);
  std::memcpy(data, front.data() + s.incoming_offset, count);
  s.incoming_offset += count;
  s.incoming_size -= count;
  if (s.incoming_offset == front.size()) {
    s.incoming.pop_front();
    s.received_at.pop_front();
    s.incoming_offset = 0;
  }
  return static_cast<int64_t>(count);
}

size_t BleServer::send(const uint8_t* data, size_t length) {
  gatt::GattSubscribedClient client{nullptr};
  gatt::GattLocalCharacteristic characteristic{nullptr};
  {
    std::lock_guard<std::mutex> lock(impl_->mutex);
    auto& s = *impl_;
    if (!s.fault.empty()) throw TransportError(PV_DELIVERY_UNCERTAIN, s.fault.c_str());
    if (s.owner == nullptr || s.disconnected) return 0;
    client = s.owner;
    characteristic = s.notify_characteristic;
  }
  try {
    // An attribute value is at most 512 bytes; a notification fits the PDU.
    const size_t count = std::min({length,
        static_cast<size_t>(std::max<uint16_t>(20, client.MaxNotificationSize())), size_t(512)});
    streams::DataWriter writer;
    writer.WriteBytes(winrt::array_view<const uint8_t>(data, data + count));
    const auto result = characteristic.NotifyValueAsync(writer.DetachBuffer(), client).get();
    if (result.Status() != gatt::GattCommunicationStatus::Success) return 0;
    return count;
  } catch (...) {
    std::lock_guard<std::mutex> lock(impl_->mutex);
    impl_->fault = "BLE notification failed; delivery is uncertain";
    throw TransportError(PV_DELIVERY_UNCERTAIN, impl_->fault.c_str());
  }
}

bool BleServer::close() {
  auto& s = *impl_;
  if (!s.stop()) return false;
  if (s.reserved) {
    s.reserved = false;
    adapter_reserved = false;
  }
  return true;
}

} // namespace povad
