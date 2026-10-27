#include "transport.hpp"

#include <jni.h>

#include <algorithm>
#include <cstring>

namespace {

JavaVM* java_vm = nullptr;
jclass usb_host = nullptr;
jmethodID open_usb = nullptr;

class WorkerEnv final {
 public:
  WorkerEnv() {
    if (java_vm == nullptr || usb_host == nullptr || open_usb == nullptr) {
      throw povad::TransportError(PV_UNSUPPORTED_PLATFORM, "Android USB Host is unavailable");
    }
    const jint status = java_vm->GetEnv(reinterpret_cast<void**>(&env_), JNI_VERSION_1_6);
    if (status == JNI_EDETACHED) {
      if (java_vm->AttachCurrentThread(&env_, nullptr) != JNI_OK) {
        throw povad::TransportError(PV_NATIVE_FAILURE, "Cannot attach USB transport worker");
      }
      attached_ = true;
    } else if (status != JNI_OK) {
      throw povad::TransportError(PV_NATIVE_FAILURE, "Cannot access Android Java VM");
    }
  }

  ~WorkerEnv() {
    if (attached_) java_vm->DetachCurrentThread();
  }

  JNIEnv* get() const { return env_; }

 private:
  JNIEnv* env_ = nullptr;
  bool attached_ = false;
};

bool java_failed(JNIEnv* env) {
  if (!env->ExceptionCheck()) return false;
  env->ExceptionClear();
  return true;
}

} // namespace

// System.loadLibrary from MainActivity initializes the class loader and Java VM
// before Dart starts the C++ transport worker.
extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  JNIEnv* env = nullptr;
  if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
    return JNI_ERR;
  }
  jclass local = env->FindClass("io/github/ialexpovad/povad/PovadUsbHost");
  if (local == nullptr || java_failed(env)) return JNI_ERR;
  jclass global = static_cast<jclass>(env->NewGlobalRef(local));
  env->DeleteLocalRef(local);
  if (global == nullptr || java_failed(env)) return JNI_ERR;
  jmethodID method = env->GetStaticMethodID(global, "open",
      "(Ljava/lang/String;IIIIZZZ)Lio/github/ialexpovad/povad/UsbSession;");
  if (method == nullptr || java_failed(env)) {
    env->DeleteGlobalRef(global);
    return JNI_ERR;
  }
  java_vm = vm;
  usb_host = global;
  open_usb = method;
  jclass ble_local = env->FindClass("io/github/ialexpovad/povad/PovadBleHost");
  if (ble_local == nullptr || java_failed(env)) return JNI_ERR;
  jclass ble_global = static_cast<jclass>(env->NewGlobalRef(ble_local));
  env->DeleteLocalRef(ble_local);
  if (ble_global == nullptr || java_failed(env)) return JNI_ERR;
  jmethodID ble_method = env->GetStaticMethodID(ble_global, "open",
      "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;IIZ)Lio/github/ialexpovad/povad/BleSession;");
  if (ble_method == nullptr || java_failed(env)) return JNI_ERR;
  povad::set_android_ble_host(vm, ble_global, ble_method);
  return JNI_VERSION_1_6;
}

namespace povad {

struct SerialPort::Impl {
  jobject session = nullptr;
  jmethodID read = nullptr;
  jmethodID write = nullptr;
  jmethodID close = nullptr;
};

SerialPort::SerialPort() : impl_(new Impl) {}
SerialPort::~SerialPort() { close(); }

void SerialPort::open(const pv_config& config) {
  if (!close()) throw TransportError(PV_NATIVE_FAILURE, "Previous serial shutdown is uncertain");
  WorkerEnv worker;
  JNIEnv* env = worker.get();
  jstring name = env->NewStringUTF(config.serial_port);
  if (name == nullptr || java_failed(env)) {
    throw TransportError(PV_INVALID_CONFIG, "Invalid Android USB device selection");
  }
  jobject session = env->CallStaticObjectMethod(usb_host, open_usb, name,
      static_cast<jint>(config.baud), static_cast<jint>(config.data_bits),
      static_cast<jint>(config.parity), static_cast<jint>(config.stop_bits_x10),
      static_cast<jboolean>(config.hardware_flow), static_cast<jboolean>(config.dtr),
      static_cast<jboolean>(config.rts));
  env->DeleteLocalRef(name);
  if (java_failed(env) || session == nullptr) {
    throw TransportError(PV_NATIVE_FAILURE,
        "Cannot open USB serial device; check permission, adapter, and settings");
  }
  jclass type = env->GetObjectClass(session);
  if (type == nullptr || java_failed(env)) {
    env->DeleteLocalRef(session);
    throw TransportError(PV_NATIVE_FAILURE, "Cannot access Android USB serial session");
  }
  impl_->close = env->GetMethodID(type, "close", "()V");
  impl_->read = env->GetMethodID(type, "read", "([B)I");
  impl_->write = env->GetMethodID(type, "write", "([BI)I");
  const bool invalid = java_failed(env) || impl_->read == nullptr ||
      impl_->write == nullptr || impl_->close == nullptr;
  env->DeleteLocalRef(type);
  if (invalid) {
    if (impl_->close != nullptr) {
      env->CallVoidMethod(session, impl_->close);
      java_failed(env);
    }
    env->DeleteLocalRef(session);
    throw TransportError(PV_NATIVE_FAILURE, "Android USB serial session ABI mismatch");
  }
  impl_->session = env->NewGlobalRef(session);
  if (impl_->session == nullptr || java_failed(env)) {
    env->CallVoidMethod(session, impl_->close);
    java_failed(env);
    env->DeleteLocalRef(session);
    throw TransportError(PV_NATIVE_FAILURE, "Cannot retain Android USB serial session");
  }
  env->DeleteLocalRef(session);
}

size_t SerialPort::read(uint8_t* data, size_t capacity) {
  WorkerEnv worker;
  JNIEnv* env = worker.get();
  const jsize requested = static_cast<jsize>(std::min(capacity, size_t(4096)));
  jbyteArray buffer = env->NewByteArray(requested);
  if (buffer == nullptr || java_failed(env)) {
    throw TransportError(PV_NATIVE_FAILURE, "Cannot allocate Android USB read buffer");
  }
  const jint count = env->CallIntMethod(impl_->session, impl_->read, buffer);
  if (java_failed(env) || count < 0 || count > requested) {
    env->DeleteLocalRef(buffer);
    throw TransportError(PV_NATIVE_FAILURE, "Android USB serial read failed or device detached");
  }
  if (count != 0) env->GetByteArrayRegion(buffer, 0, count, reinterpret_cast<jbyte*>(data));
  const bool copy_failed = java_failed(env);
  env->DeleteLocalRef(buffer);
  if (copy_failed) throw TransportError(PV_NATIVE_FAILURE, "Android USB read copy failed");
  return static_cast<size_t>(count);
}

size_t SerialPort::write(const uint8_t* data, size_t length) {
  WorkerEnv worker;
  JNIEnv* env = worker.get();
  const jsize requested = static_cast<jsize>(std::min(length, size_t(4096)));
  jbyteArray buffer = env->NewByteArray(requested);
  if (buffer == nullptr || java_failed(env)) {
    throw TransportError(PV_DELIVERY_UNCERTAIN, "Cannot allocate Android USB write buffer");
  }
  env->SetByteArrayRegion(buffer, 0, requested, reinterpret_cast<const jbyte*>(data));
  if (java_failed(env)) {
    env->DeleteLocalRef(buffer);
    throw TransportError(PV_DELIVERY_UNCERTAIN, "Android USB write copy failed");
  }
  const jint count = env->CallIntMethod(impl_->session, impl_->write, buffer, requested);
  const bool failed = java_failed(env);
  env->DeleteLocalRef(buffer);
  if (failed || count != requested) {
    throw TransportError(PV_DELIVERY_UNCERTAIN,
        "Android USB serial write failed; delivery is uncertain");
  }
  return static_cast<size_t>(count);
}

bool SerialPort::write_pending() const { return false; }

bool SerialPort::close() {
  if (impl_->session == nullptr) return true;
  try {
    WorkerEnv worker;
    JNIEnv* env = worker.get();
    env->CallVoidMethod(impl_->session, impl_->close);
    const bool closed = !java_failed(env);
    if (closed) {
      env->DeleteGlobalRef(impl_->session);
      impl_->session = nullptr;
    }
    return closed;
  } catch (...) {
    // Retain the reference so the worker can retry. An unconfirmed shutdown
    // never becomes a clean stop.
    return false;
  }
}

} // namespace povad
