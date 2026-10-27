#include "transport.hpp"

#include <jni.h>
#include <algorithm>

namespace povad {
namespace {
JavaVM* vm = nullptr;
jclass host = nullptr;
jmethodID open_method = nullptr;

class Env final {
 public:
  Env() {
    if (!vm) throw TransportError(PV_UNSUPPORTED_PLATFORM, "Android BLE is unavailable");
    const jint status = vm->GetEnv(reinterpret_cast<void**>(&env_), JNI_VERSION_1_6);
    if (status == JNI_EDETACHED) {
      if (vm->AttachCurrentThread(&env_, nullptr) != JNI_OK)
        throw TransportError(PV_NATIVE_FAILURE, "Cannot attach BLE worker");
      attached_ = true;
    } else if (status != JNI_OK) throw TransportError(PV_NATIVE_FAILURE, "Cannot access Java VM");
  }
  ~Env() { if (attached_) vm->DetachCurrentThread(); }
  JNIEnv* get() const { return env_; }
 private:
  JNIEnv* env_ = nullptr;
  bool attached_ = false;
};

bool failed(JNIEnv* env) {
  if (!env->ExceptionCheck()) return false;
  env->ExceptionClear();
  return true;
}
} // namespace

void set_android_ble_host(void* java_vm, void* type, void* method) {
  vm = static_cast<JavaVM*>(java_vm);
  host = static_cast<jclass>(type);
  open_method = static_cast<jmethodID>(method);
}

struct BleServer::Impl {
  jobject session = nullptr;
  jmethodID poll = nullptr;
  jmethodID connected = nullptr;
  jmethodID pending = nullptr;
  jmethodID close_client = nullptr;
  jmethodID read = nullptr;
  jmethodID write = nullptr;
  jmethodID close = nullptr;
};

BleServer::BleServer() : impl_(new Impl) {}
BleServer::~BleServer() { close(); }

void BleServer::listen(const pv_config& config) {
  if (!close()) throw TransportError(PV_NATIVE_FAILURE, "Previous BLE shutdown is uncertain");
  if (!host || !open_method) throw TransportError(PV_UNSUPPORTED_PLATFORM, "Android BLE is unavailable");
  Env worker;
  JNIEnv* env = worker.get();
  jstring name = env->NewStringUTF(config.ble_name);
  jstring service = env->NewStringUTF(config.ble_service_uuid);
  jstring write = env->NewStringUTF(config.ble_write_uuid);
  jstring notify = env->NewStringUTF(config.ble_notify_uuid);
  if (!name || !service || !write || !notify || failed(env))
    throw TransportError(PV_INVALID_CONFIG, "Cannot allocate BLE configuration");
  jobject session = env->CallStaticObjectMethod(host, open_method, name, service, write, notify,
      static_cast<jint>(config.queue_limit), static_cast<jint>(config.queue_age_ms),
      config.ble_require_pairing != 0 ? JNI_TRUE : JNI_FALSE);
  env->DeleteLocalRef(name);
  env->DeleteLocalRef(service);
  env->DeleteLocalRef(write);
  env->DeleteLocalRef(notify);
  if (failed(env) || !session) throw TransportError(PV_NATIVE_FAILURE,
      "Cannot start Android BLE; check Bluetooth, permission, and advertising support");
  jclass type = env->GetObjectClass(session);
  impl_->poll = env->GetMethodID(type, "poll", "()I");
  impl_->connected = env->GetMethodID(type, "connected", "()Z");
  impl_->pending = env->GetMethodID(type, "pending", "()Z");
  impl_->close_client = env->GetMethodID(type, "closeClient", "()Z");
  impl_->read = env->GetMethodID(type, "read", "([B)I");
  impl_->write = env->GetMethodID(type, "write", "([BI)I");
  impl_->close = env->GetMethodID(type, "close", "()Z");
  const bool invalid = failed(env) || !impl_->poll || !impl_->connected || !impl_->pending ||
      !impl_->close_client || !impl_->read || !impl_->write || !impl_->close;
  env->DeleteLocalRef(type);
  if (invalid) {
    env->DeleteLocalRef(session);
    throw TransportError(PV_NATIVE_FAILURE, "Android BLE session ABI mismatch");
  }
  impl_->session = env->NewGlobalRef(session);
  env->DeleteLocalRef(session);
  if (!impl_->session || failed(env))
    throw TransportError(PV_NATIVE_FAILURE, "Cannot retain Android BLE session");
}

int BleServer::accept() {
  Env worker;
  JNIEnv* env = worker.get();
  const int result = env->CallIntMethod(impl_->session, impl_->poll);
  if (failed(env)) throw TransportError(PV_NATIVE_FAILURE, "Android BLE session failed");
  return result;
}

bool BleServer::connected() const {
  if (!impl_->session) return false;
  Env worker;
  JNIEnv* env = worker.get();
  const bool result = env->CallBooleanMethod(impl_->session, impl_->connected) == JNI_TRUE;
  if (failed(env)) throw TransportError(PV_NATIVE_FAILURE, "Cannot read BLE state");
  return result;
}

bool BleServer::write_pending() const {
  if (!impl_->session) return false;
  Env worker;
  JNIEnv* env = worker.get();
  const bool result = env->CallBooleanMethod(impl_->session, impl_->pending) == JNI_TRUE;
  if (failed(env)) throw TransportError(PV_NATIVE_FAILURE, "Cannot read BLE queue state");
  return result;
}

bool BleServer::close_client() {
  Env worker;
  JNIEnv* env = worker.get();
  const bool result = env->CallBooleanMethod(impl_->session, impl_->close_client) == JNI_TRUE;
  return !failed(env) && result;
}

int64_t BleServer::receive(uint8_t* data, size_t capacity) {
  Env worker;
  JNIEnv* env = worker.get();
  const jsize size = static_cast<jsize>(std::min(capacity, size_t(4096)));
  jbyteArray bytes = env->NewByteArray(size);
  if (!bytes || failed(env)) throw TransportError(PV_NATIVE_FAILURE, "Cannot allocate BLE input buffer");
  const jint result = env->CallIntMethod(impl_->session, impl_->read, bytes);
  if (failed(env) || result < -1 || result > size) {
    env->DeleteLocalRef(bytes);
    throw TransportError(PV_NATIVE_FAILURE, "Android BLE receive failed");
  }
  if (result > 0) env->GetByteArrayRegion(bytes, 0, result, reinterpret_cast<jbyte*>(data));
  const bool copy_failed = failed(env);
  env->DeleteLocalRef(bytes);
  if (copy_failed) throw TransportError(PV_NATIVE_FAILURE, "Cannot copy BLE input");
  return result;
}

size_t BleServer::send(const uint8_t* data, size_t length) {
  Env worker;
  JNIEnv* env = worker.get();
  const jsize size = static_cast<jsize>(std::min(length, size_t(4096)));
  jbyteArray bytes = env->NewByteArray(size);
  if (!bytes || failed(env)) throw TransportError(PV_DELIVERY_UNCERTAIN, "Cannot allocate BLE output buffer");
  env->SetByteArrayRegion(bytes, 0, size, reinterpret_cast<const jbyte*>(data));
  if (failed(env)) {
    env->DeleteLocalRef(bytes);
    throw TransportError(PV_DELIVERY_UNCERTAIN, "Cannot copy BLE output");
  }
  const jint result = env->CallIntMethod(impl_->session, impl_->write, bytes, size);
  const bool send_failed = failed(env);
  env->DeleteLocalRef(bytes);
  if (send_failed || result < 0 || result > size)
    throw TransportError(PV_DELIVERY_UNCERTAIN, "BLE notification failed; delivery is uncertain");
  return static_cast<size_t>(result);
}

bool BleServer::close() {
  if (!impl_->session) return true;
  try {
    Env worker;
    JNIEnv* env = worker.get();
    const bool closed = env->CallBooleanMethod(impl_->session, impl_->close) == JNI_TRUE;
    if (failed(env) || !closed) return false;
    env->DeleteGlobalRef(impl_->session);
    impl_->session = nullptr;
    return true;
  } catch (...) { return false; }
}
} // namespace povad
