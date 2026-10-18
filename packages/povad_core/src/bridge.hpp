#pragma once

#include "povad_core.h"

#include <atomic>
#include <cstddef>
#include <mutex>
#include <thread>

namespace povad {

class Bridge final {
 public:
  Bridge();
  ~Bridge();
  Bridge(const Bridge&) = delete;
  Bridge& operator=(const Bridge&) = delete;

  int32_t start(const pv_config& config);
  void request_stop();
  bool finished() const { return finished_.load(); }
  void snapshot(pv_snapshot* output) const;

 private:
  void run(pv_config config) noexcept;
  void set_state(uint32_t state, bool serial_open, bool connected);
  void add_tcp_received(size_t bytes);
  void add_serial_received(size_t bytes);
  void add_serial_accepted(size_t bytes);
  void add_tcp_accepted(size_t bytes);
  void finish(uint32_t state, uint32_t error_code, const char* message);

  mutable std::mutex mutex_;
  std::thread worker_;
  std::atomic<bool> stop_{false};
  std::atomic<bool> finished_{true};
  pv_snapshot status_{};
};

} // namespace povad
