#include "login_startup.h"

#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
constexpr auto kRun = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr auto kApproved =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run";
constexpr auto kName = L"Povad";

std::wstring Command() {
  std::vector<wchar_t> buffer(32768);
  const DWORD length = GetModuleFileNameW(nullptr, buffer.data(),
                                         static_cast<DWORD>(buffer.size()));
  if (length == 0 || length >= buffer.size()) {
    throw std::runtime_error("Cannot locate Povad");
  }
  const auto command = L"\"" + std::wstring(buffer.data(), length) + L"\"";
  // Run entries have a documented 260-character limit.
  if (command.size() > 260) {
    throw std::runtime_error("Move Povad to a shorter installation path");
  }
  return command;
}

std::wstring RegisteredCommand() {
  wchar_t buffer[32768] = {};
  DWORD bytes = sizeof(buffer);
  const auto status = RegGetValueW(HKEY_CURRENT_USER, kRun, kName,
                                  RRF_RT_REG_SZ, nullptr, buffer, &bytes);
  if (status == ERROR_FILE_NOT_FOUND || status == ERROR_PATH_NOT_FOUND) return L"";
  if (status != ERROR_SUCCESS) throw std::runtime_error("Cannot read login startup");
  return buffer;
}

bool BlockedByWindows() {
  BYTE buffer[12] = {};
  DWORD bytes = sizeof(buffer);
  const auto status = RegGetValueW(HKEY_CURRENT_USER, kApproved, kName,
                                  RRF_RT_REG_BINARY, nullptr, buffer, &bytes);
  if (status == ERROR_FILE_NOT_FOUND || status == ERROR_PATH_NOT_FOUND) return false;
  if (status != ERROR_SUCCESS) throw std::runtime_error("Cannot read startup approval");
  // Explorer owns this value. Read its disabled flag, never overwrite it.
  return bytes > 0 && (buffer[0] & 1) != 0;
}

std::string Status() {
  if (RegisteredCommand().empty()) return "disabled";
  return BlockedByWindows() ? "approvalRequired" : "enabled";
}

void SetEnabled(bool enabled) {
  if (!enabled) {
    const auto result = RegDeleteKeyValueW(HKEY_CURRENT_USER, kRun, kName);
    if (result != ERROR_SUCCESS && result != ERROR_FILE_NOT_FOUND &&
        result != ERROR_PATH_NOT_FOUND) {
      throw std::runtime_error("Cannot disable login startup");
    }
    return;
  }
  const auto command = Command();
  if (RegisteredCommand() == command) return;
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kRun, 0, nullptr, 0, KEY_SET_VALUE,
                      nullptr, &key, nullptr) != ERROR_SUCCESS) {
    throw std::runtime_error("Cannot open login startup settings");
  }
  const auto result = RegSetValueExW(
      key, kName, 0, REG_SZ, reinterpret_cast<const BYTE*>(command.c_str()),
      static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(key);
  if (result != ERROR_SUCCESS) throw std::runtime_error("Cannot enable login startup");
}
}  // namespace

void RegisterLoginStartup(flutter::BinaryMessenger* messenger) {
  flutter::MethodChannel<flutter::EncodableValue> channel(
      messenger, "povad/login-startup", &flutter::StandardMethodCodec::GetInstance());
  channel.SetMethodCallHandler([](const auto& call, auto result) {
    try {
      if (call.method_name() == "status") {
        result->Success(flutter::EncodableValue(Status()));
      } else if (call.method_name() == "setEnabled") {
        const auto* value = call.arguments()
                                ? std::get_if<bool>(call.arguments())
                                : nullptr;
        if (!value) {
          result->Error("ARGUMENT", "Expected enabled boolean");
          return;
        }
        SetEnabled(*value);
        result->Success();
      } else {
        result->NotImplemented();
      }
    } catch (const std::exception& error) {
      result->Error("STARTUP", error.what());
    }
  });
}
