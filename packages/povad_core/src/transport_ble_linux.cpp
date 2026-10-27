// BLE GATT peripheral on Linux through BlueZ's D-Bus API (GattManager1 and
// LEAdvertisingManager1), with GLib's GDBus, which a Flutter Linux app already
// links. One GLib main loop runs on a thread this server owns; close() stops
// and joins it before any object is released.
#include "transport.hpp"

#include <gio/gio.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <deque>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace {

std::atomic<bool> adapter_reserved{false};
std::atomic<unsigned> next_application{0};

uint64_t now_ms() {
  return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
      std::chrono::steady_clock::now().time_since_epoch()).count());
}

// 16-bit UUIDs (FFE0) become the Bluetooth base UUID; 128-bit ones pass.
std::string full_uuid(const char* value) {
  std::string uuid(value);
  std::transform(uuid.begin(), uuid.end(), uuid.begin(),
      [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  if (uuid.size() == 4) return "0000" + uuid + "-0000-1000-8000-00805f9b34fb";
  return uuid;
}

const char* kIntrospection = R"XML(
<node>
  <interface name="org.freedesktop.DBus.ObjectManager">
    <method name="GetManagedObjects">
      <arg name="objects" type="a{oa{sa{sv}}}" direction="out"/>
    </method>
  </interface>
  <interface name="org.bluez.GattService1">
    <property name="UUID" type="s" access="read"/>
    <property name="Primary" type="b" access="read"/>
  </interface>
  <interface name="org.bluez.GattCharacteristic1">
    <method name="ReadValue">
      <arg name="options" type="a{sv}" direction="in"/>
      <arg name="value" type="ay" direction="out"/>
    </method>
    <method name="WriteValue">
      <arg name="value" type="ay" direction="in"/>
      <arg name="options" type="a{sv}" direction="in"/>
    </method>
    <method name="StartNotify"/>
    <method name="StopNotify"/>
    <property name="UUID" type="s" access="read"/>
    <property name="Service" type="o" access="read"/>
    <property name="Flags" type="as" access="read"/>
    <property name="Notifying" type="b" access="read"/>
    <property name="Value" type="ay" access="read"/>
  </interface>
  <interface name="org.bluez.LEAdvertisement1">
    <method name="Release"/>
    <property name="Type" type="s" access="read"/>
    <property name="ServiceUUIDs" type="as" access="read"/>
    <property name="LocalName" type="s" access="read"/>
  </interface>
</node>)XML";

} // namespace

namespace povad {

struct BleServer::Impl {
  // Owned by the loop thread once started.
  GMainContext* context = nullptr;
  GMainLoop* loop = nullptr;
  std::thread thread;
  GDBusConnection* bus = nullptr;
  GDBusNodeInfo* node = nullptr;
  std::vector<guint> registrations;
  guint device_watch = 0;

  std::string adapter, app, service, write_path, notify_path, advert;
  std::string service_uuid, write_uuid, notify_uuid, name;
  bool paired = true;
  bool reserved = false;
  bool registered_app = false, registered_advert = false;

  mutable std::mutex mutex;
  std::condition_variable ready;
  bool loop_ready = false;
  std::string owner;           // D-Bus path of the client device, once known.
  bool notifying = false;
  bool disconnected = false;
  int event = 0;
  std::string fault;
  std::deque<std::vector<uint8_t>> incoming;
  std::deque<uint64_t> received_at;
  size_t incoming_offset = 0, incoming_size = 0;
  size_t limit = 65536;
  uint32_t max_age_ms = 2000;
  uint16_t mtu = 23;

  GVariant* flags(bool write) const {
    GVariantBuilder builder;
    g_variant_builder_init(&builder, G_VARIANT_TYPE("as"));
    if (write) {
      g_variant_builder_add(&builder, "s", paired ? "encrypt-write" : "write");
      if (!paired) g_variant_builder_add(&builder, "s", "write-without-response");
    } else {
      g_variant_builder_add(&builder, "s", "notify");
      if (paired) g_variant_builder_add(&builder, "s", "encrypt-notify");
    }
    return g_variant_builder_end(&builder);
  }

  GVariant* characteristic_properties(bool write) {
    GVariantBuilder props;
    g_variant_builder_init(&props, G_VARIANT_TYPE("a{sv}"));
    g_variant_builder_add(&props, "{sv}", "UUID",
        g_variant_new_string((write ? write_uuid : notify_uuid).c_str()));
    g_variant_builder_add(&props, "{sv}", "Service", g_variant_new_object_path(service.c_str()));
    g_variant_builder_add(&props, "{sv}", "Flags", flags(write));
    if (!write) {
      std::lock_guard<std::mutex> lock(mutex);
      g_variant_builder_add(&props, "{sv}", "Notifying", g_variant_new_boolean(notifying));
    }
    return g_variant_builder_end(&props);
  }

  GVariant* managed_objects() {
    GVariantBuilder objects;
    g_variant_builder_init(&objects, G_VARIANT_TYPE("a{oa{sa{sv}}}"));
    auto add = [&](const std::string& path, const char* iface, GVariant* props) {
      GVariantBuilder ifaces;
      g_variant_builder_init(&ifaces, G_VARIANT_TYPE("a{sa{sv}}"));
      g_variant_builder_add(&ifaces, "{s@a{sv}}", iface, props);
      g_variant_builder_add(&objects, "{o@a{sa{sv}}}", path.c_str(), g_variant_builder_end(&ifaces));
    };
    GVariantBuilder service_props;
    g_variant_builder_init(&service_props, G_VARIANT_TYPE("a{sv}"));
    g_variant_builder_add(&service_props, "{sv}", "UUID", g_variant_new_string(service_uuid.c_str()));
    g_variant_builder_add(&service_props, "{sv}", "Primary", g_variant_new_boolean(TRUE));
    add(service, "org.bluez.GattService1", g_variant_builder_end(&service_props));
    add(write_path, "org.bluez.GattCharacteristic1", characteristic_properties(true));
    add(notify_path, "org.bluez.GattCharacteristic1", characteristic_properties(false));
    return g_variant_new("(@a{oa{sa{sv}}})", g_variant_builder_end(&objects));
  }

  void claim(const std::string& device) {
    // Called with the mutex held. The first client to write or subscribe
    // owns the bridge until it leaves.
    if (owner.empty()) {
      owner = device;
      disconnected = false;
      event = 1;
    }
  }

  void on_write(GVariant* parameters, GDBusMethodInvocation* invocation) {
    GVariant* value = nullptr;
    GVariant* options = nullptr;
    g_variant_get(parameters, "(@ay@a{sv})", &value, &options);
    const char* device = nullptr;
    guint16 option_mtu = 0;
    guint16 offset = 0;
    g_variant_lookup(options, "device", "&o", &device);
    g_variant_lookup(options, "mtu", "q", &option_mtu);
    g_variant_lookup(options, "offset", "q", &offset);
    gsize length = 0;
    const auto* bytes = static_cast<const uint8_t*>(
        g_variant_get_fixed_array(value, &length, sizeof(uint8_t)));
    const char* error = nullptr;
    {
      std::lock_guard<std::mutex> lock(mutex);
      if (offset != 0) {
        error = "org.bluez.Error.InvalidOffset";
      } else {
        const std::string client = device != nullptr ? device : "";
        claim(client);
        if (option_mtu != 0) mtu = option_mtu;
        if (!client.empty() && owner != client) {
          event = 2;
          error = "org.bluez.Error.NotPermitted";
        } else if (disconnected) {
          error = "org.bluez.Error.NotPermitted";
        } else if (length > limit - incoming_size) {
          fault = "BLE input queue overflow; delivery is uncertain";
          error = "org.bluez.Error.Failed";
        } else {
          incoming.emplace_back(bytes, bytes + length);
          received_at.push_back(now_ms());
          incoming_size += length;
        }
      }
    }
    g_variant_unref(value);
    g_variant_unref(options);
    if (error != nullptr) {
      g_dbus_method_invocation_return_dbus_error(invocation, error, "Write refused");
    } else {
      g_dbus_method_invocation_return_value(invocation, nullptr);
    }
  }

  static void method(GDBusConnection*, const gchar*, const gchar* path, const gchar* iface,
      const gchar* name, GVariant* parameters, GDBusMethodInvocation* invocation, gpointer data) {
    auto* self = static_cast<Impl*>(data);
    const std::string object(path);
    if (std::strcmp(iface, "org.freedesktop.DBus.ObjectManager") == 0) {
      g_dbus_method_invocation_return_value(invocation, self->managed_objects());
    } else if (std::strcmp(name, "WriteValue") == 0 && object == self->write_path) {
      self->on_write(parameters, invocation);
    } else if (std::strcmp(name, "ReadValue") == 0) {
      g_dbus_method_invocation_return_dbus_error(invocation,
          "org.bluez.Error.NotPermitted", "Not readable");
    } else if (std::strcmp(name, "StartNotify") == 0 && object == self->notify_path) {
      {
        std::lock_guard<std::mutex> lock(self->mutex);
        self->notifying = true;
        self->disconnected = false;
        if (self->owner.empty()) self->event = 1;
      }
      g_dbus_method_invocation_return_value(invocation, nullptr);
    } else if (std::strcmp(name, "StopNotify") == 0 && object == self->notify_path) {
      {
        std::lock_guard<std::mutex> lock(self->mutex);
        self->notifying = false;
        self->disconnected = true;
      }
      g_dbus_method_invocation_return_value(invocation, nullptr);
    } else if (std::strcmp(name, "Release") == 0) {
      g_dbus_method_invocation_return_value(invocation, nullptr);
    } else {
      g_dbus_method_invocation_return_dbus_error(invocation,
          "org.bluez.Error.NotSupported", "Not supported");
    }
  }

  static GVariant* property(GDBusConnection*, const gchar*, const gchar* path, const gchar* iface,
      const gchar* name, GError**, gpointer data) {
    auto* self = static_cast<Impl*>(data);
    const std::string object(path);
    if (std::strcmp(iface, "org.bluez.GattService1") == 0) {
      if (std::strcmp(name, "UUID") == 0) return g_variant_new_string(self->service_uuid.c_str());
      if (std::strcmp(name, "Primary") == 0) return g_variant_new_boolean(TRUE);
    } else if (std::strcmp(iface, "org.bluez.GattCharacteristic1") == 0) {
      const bool write = object == self->write_path;
      if (std::strcmp(name, "UUID") == 0)
        return g_variant_new_string((write ? self->write_uuid : self->notify_uuid).c_str());
      if (std::strcmp(name, "Service") == 0) return g_variant_new_object_path(self->service.c_str());
      if (std::strcmp(name, "Flags") == 0) return self->flags(write);
      if (std::strcmp(name, "Notifying") == 0) {
        std::lock_guard<std::mutex> lock(self->mutex);
        return g_variant_new_boolean(self->notifying);
      }
      if (std::strcmp(name, "Value") == 0)
        return g_variant_new_fixed_array(G_VARIANT_TYPE_BYTE, nullptr, 0, 1);
    } else if (std::strcmp(iface, "org.bluez.LEAdvertisement1") == 0) {
      if (std::strcmp(name, "Type") == 0) return g_variant_new_string("peripheral");
      if (std::strcmp(name, "LocalName") == 0) return g_variant_new_string(self->name.c_str());
      if (std::strcmp(name, "ServiceUUIDs") == 0) {
        const gchar* uuids[] = {self->service_uuid.c_str(), nullptr};
        return g_variant_new_strv(uuids, -1);
      }
    }
    return nullptr;
  }

  static void device_changed(GDBusConnection*, const gchar*, const gchar* path, const gchar*,
      const gchar*, GVariant* parameters, gpointer data) {
    auto* self = static_cast<Impl*>(data);
    const gchar* iface = nullptr;
    GVariant* changed = nullptr;
    g_variant_get(parameters, "(&s@a{sv}@as)", &iface, &changed, nullptr);
    gboolean connected = TRUE;
    if (std::strcmp(iface, "org.bluez.Device1") == 0 &&
        g_variant_lookup(changed, "Connected", "b", &connected) && !connected) {
      std::lock_guard<std::mutex> lock(self->mutex);
      if (self->owner == path) {
        self->disconnected = true;
        self->notifying = false;
      }
    }
    g_variant_unref(changed);
  }

  // Runs on the loop thread: registers objects, the application and the
  // advertisement, then serves until quit.
  void run() {
    g_main_context_push_thread_default(context);
    std::string problem;
    GError* error = nullptr;
    bus = g_bus_get_sync(G_BUS_TYPE_SYSTEM, nullptr, &error);
    if (bus == nullptr) problem = "Cannot reach the system D-Bus for BlueZ";
    if (problem.empty()) problem = find_adapter();
    if (problem.empty()) problem = register_objects();
    if (problem.empty()) problem = register_with_bluez();
    if (error != nullptr) g_error_free(error);
    {
      std::lock_guard<std::mutex> lock(mutex);
      if (!problem.empty()) fault = problem;
      loop_ready = true;
    }
    ready.notify_all();
    if (problem.empty()) g_main_loop_run(loop);
    teardown();
    g_main_context_pop_thread_default(context);
  }

  std::string find_adapter() {
    GError* error = nullptr;
    GVariant* reply = g_dbus_connection_call_sync(bus, "org.bluez", "/",
        "org.freedesktop.DBus.ObjectManager", "GetManagedObjects", nullptr,
        G_VARIANT_TYPE("(a{oa{sa{sv}}})"), G_DBUS_CALL_FLAGS_NONE, 5000, nullptr, &error);
    if (reply == nullptr) {
      if (error != nullptr) g_error_free(error);
      return "BlueZ is unavailable; install and start bluetoothd";
    }
    GVariant* objects = g_variant_get_child_value(reply, 0);
    GVariantIter iter;
    g_variant_iter_init(&iter, objects);
    const gchar* path = nullptr;
    GVariant* ifaces = nullptr;
    bool powered_off = false;
    while (g_variant_iter_next(&iter, "{&o@a{sa{sv}}}", &path, &ifaces)) {
      GVariant* gatt = g_variant_lookup_value(ifaces, "org.bluez.GattManager1", nullptr);
      GVariant* adv = g_variant_lookup_value(ifaces, "org.bluez.LEAdvertisingManager1", nullptr);
      GVariant* props = g_variant_lookup_value(ifaces, "org.bluez.Adapter1", nullptr);
      gboolean powered = FALSE;
      if (props != nullptr) g_variant_lookup(props, "Powered", "b", &powered);
      if (gatt != nullptr && adv != nullptr && adapter.empty()) {
        if (powered) adapter = path;
        else powered_off = true;
      }
      if (gatt != nullptr) g_variant_unref(gatt);
      if (adv != nullptr) g_variant_unref(adv);
      if (props != nullptr) g_variant_unref(props);
      g_variant_unref(ifaces);
    }
    g_variant_unref(objects);
    g_variant_unref(reply);
    if (!adapter.empty()) return {};
    return powered_off ? "Bluetooth adapter is powered off"
                       : "No Bluetooth adapter supports BLE peripheral mode";
  }

  std::string register_objects() {
    GError* error = nullptr;
    node = g_dbus_node_info_new_for_xml(kIntrospection, &error);
    if (node == nullptr) {
      if (error != nullptr) g_error_free(error);
      return "Cannot describe the BLE GATT objects";
    }
    static const GDBusInterfaceVTable vtable = {&Impl::method, &Impl::property, nullptr, {}};
    auto add = [&](const std::string& path, const char* iface) {
      GDBusInterfaceInfo* info = g_dbus_node_info_lookup_interface(node, iface);
      const guint id = g_dbus_connection_register_object(bus, path.c_str(), info,
          &vtable, this, nullptr, nullptr);
      if (id != 0) registrations.push_back(id);
      return id != 0;
    };
    if (!add(app, "org.freedesktop.DBus.ObjectManager") ||
        !add(service, "org.bluez.GattService1") ||
        !add(write_path, "org.bluez.GattCharacteristic1") ||
        !add(notify_path, "org.bluez.GattCharacteristic1") ||
        !add(advert, "org.bluez.LEAdvertisement1")) {
      return "Cannot publish the BLE GATT objects";
    }
    device_watch = g_dbus_connection_signal_subscribe(bus, "org.bluez",
        "org.freedesktop.DBus.Properties", "PropertiesChanged", nullptr, nullptr,
        G_DBUS_SIGNAL_FLAGS_NONE, &Impl::device_changed, this, nullptr);
    return {};
  }

  std::string register_with_bluez() {
    GError* error = nullptr;
    GVariant* reply = g_dbus_connection_call_sync(bus, "org.bluez", adapter.c_str(),
        "org.bluez.GattManager1", "RegisterApplication",
        g_variant_new("(o@a{sv})", app.c_str(), g_variant_new_array(G_VARIANT_TYPE("{sv}"), nullptr, 0)),
        nullptr, G_DBUS_CALL_FLAGS_NONE, 10000, nullptr, &error);
    if (reply == nullptr) {
      if (error != nullptr) g_error_free(error);
      return "BlueZ refused the BLE GATT service";
    }
    g_variant_unref(reply);
    registered_app = true;
    reply = g_dbus_connection_call_sync(bus, "org.bluez", adapter.c_str(),
        "org.bluez.LEAdvertisingManager1", "RegisterAdvertisement",
        g_variant_new("(o@a{sv})", advert.c_str(), g_variant_new_array(G_VARIANT_TYPE("{sv}"), nullptr, 0)),
        nullptr, G_DBUS_CALL_FLAGS_NONE, 10000, nullptr, &error);
    if (reply == nullptr) {
      if (error != nullptr) g_error_free(error);
      return "BLE advertising is unavailable";
    }
    g_variant_unref(reply);
    registered_advert = true;
    return {};
  }

  void teardown() {
    if (bus != nullptr) {
      if (registered_advert) {
        GVariant* reply = g_dbus_connection_call_sync(bus, "org.bluez", adapter.c_str(),
            "org.bluez.LEAdvertisingManager1", "UnregisterAdvertisement",
            g_variant_new("(o)", advert.c_str()), nullptr, G_DBUS_CALL_FLAGS_NONE, 5000,
            nullptr, nullptr);
        if (reply != nullptr) g_variant_unref(reply);
      }
      if (registered_app) {
        GVariant* reply = g_dbus_connection_call_sync(bus, "org.bluez", adapter.c_str(),
            "org.bluez.GattManager1", "UnregisterApplication",
            g_variant_new("(o)", app.c_str()), nullptr, G_DBUS_CALL_FLAGS_NONE, 5000,
            nullptr, nullptr);
        if (reply != nullptr) g_variant_unref(reply);
      }
      if (device_watch != 0) g_dbus_connection_signal_unsubscribe(bus, device_watch);
      for (const guint id : registrations) g_dbus_connection_unregister_object(bus, id);
      registrations.clear();
      g_object_unref(bus);
      bus = nullptr;
    }
    if (node != nullptr) {
      g_dbus_node_info_unref(node);
      node = nullptr;
    }
  }

  static gboolean quit(gpointer data) {
    g_main_loop_quit(static_cast<GMainLoop*>(data));
    return G_SOURCE_REMOVE;
  }

  bool stop() {
    if (!thread.joinable()) return true;
    GSource* source = g_idle_source_new();
    g_source_set_callback(source, &Impl::quit, loop, nullptr);
    g_source_attach(source, context);
    g_source_unref(source);
    thread.join();
    g_main_loop_unref(loop);
    g_main_context_unref(context);
    loop = nullptr;
    context = nullptr;
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
  const std::string root = "/io/github/ialexpovad/povad/ble" + std::to_string(next_application++);
  s.app = root;
  s.service = root + "/service0";
  s.write_path = s.service + "/char0";
  s.notify_path = s.service + "/char1";
  s.advert = root + "/advertisement0";
  s.service_uuid = full_uuid(config.ble_service_uuid);
  s.write_uuid = full_uuid(config.ble_write_uuid);
  s.notify_uuid = full_uuid(config.ble_notify_uuid);
  s.name = config.ble_name;
  s.paired = config.ble_require_pairing != 0;
  s.limit = config.queue_limit;
  s.max_age_ms = config.queue_age_ms;
  s.owner.clear();
  s.fault.clear();
  s.loop_ready = false;
  s.context = g_main_context_new();
  s.loop = g_main_loop_new(s.context, FALSE);
  s.thread = std::thread([&s] { s.run(); });
  std::unique_lock<std::mutex> lock(s.mutex);
  s.ready.wait(lock, [&s] { return s.loop_ready; });
  if (!s.fault.empty()) {
    const std::string message = s.fault;
    lock.unlock();
    close();
    throw TransportError(PV_UNSUPPORTED_PLATFORM, message.c_str());
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
  return !impl_->owner.empty() || impl_->notifying;
}

bool BleServer::write_pending() const {
  std::lock_guard<std::mutex> lock(impl_->mutex);
  return impl_->incoming_size != 0;
}

bool BleServer::close_client() {
  std::lock_guard<std::mutex> lock(impl_->mutex);
  auto& s = *impl_;
  s.owner.clear();
  s.notifying = false;
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
  size_t count = 0;
  GDBusConnection* bus = nullptr;
  std::string path;
  {
    std::lock_guard<std::mutex> lock(impl_->mutex);
    auto& s = *impl_;
    if (!s.fault.empty()) throw TransportError(PV_DELIVERY_UNCERTAIN, s.fault.c_str());
    if (!s.notifying || s.disconnected || s.bus == nullptr) return 0;
    // An attribute value is at most 512 bytes; a notification fits the MTU.
    count = std::min({length, static_cast<size_t>(std::max<int>(20, s.mtu - 3)), size_t(512)});
    bus = s.bus;
    path = s.notify_path;
  }
  GVariantBuilder changed;
  g_variant_builder_init(&changed, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(&changed, "{sv}", "Value",
      g_variant_new_fixed_array(G_VARIANT_TYPE_BYTE, data, count, 1));
  GError* error = nullptr;
  const gboolean sent = g_dbus_connection_emit_signal(bus, nullptr, path.c_str(),
      "org.freedesktop.DBus.Properties", "PropertiesChanged",
      g_variant_new("(sa{sv}as)", "org.bluez.GattCharacteristic1", &changed, nullptr), &error);
  if (!sent) {
    if (error != nullptr) g_error_free(error);
    return 0;
  }
  return count;
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
