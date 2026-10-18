#pragma once

#include <cstddef>
#include <cstdint>
#include <deque>
#include <stdexcept>
#include <vector>

namespace povad {

enum class QueueFailure { limit, age, consume, empty };

class QueueError final : public std::runtime_error {
 public:
  explicit QueueError(QueueFailure reason)
      : std::runtime_error("Byte queue contract violation"), reason(reason) {}
  QueueFailure reason;
};

// One worker owns this queue. It preserves byte order and supports partial
// writes without inserting, rewriting, or replaying any bytes.
class ByteQueue final {
 public:
  explicit ByteQueue(size_t limit) : limit_(limit) {}

  void push(const uint8_t* data, size_t length, uint64_t now_ms) {
    if (length == 0) return;
    if (data == nullptr || length > limit_ - size_) throw QueueError(QueueFailure::limit);
    chunks_.push_back({std::vector<uint8_t>(data, data + length), 0, now_ms});
    size_ += length;
  }

  const uint8_t* front_data() const {
    if (chunks_.empty()) throw QueueError(QueueFailure::empty);
    return chunks_.front().data.data() + chunks_.front().offset;
  }
  size_t front_size() const {
    if (chunks_.empty()) throw QueueError(QueueFailure::empty);
    return chunks_.front().data.size() - chunks_.front().offset;
  }
  size_t size() const { return size_; }
  bool empty() const { return chunks_.empty(); }

  void consume(size_t length) {
    if (length > size_) throw QueueError(QueueFailure::consume);
    while (length > 0) {
      auto& chunk = chunks_.front();
      const size_t amount = chunk.data.size() - chunk.offset;
      const size_t taken = length < amount ? length : amount;
      chunk.offset += taken;
      size_ -= taken;
      length -= taken;
      if (chunk.offset == chunk.data.size()) chunks_.pop_front();
    }
  }

  void check_age(uint64_t now_ms, uint64_t max_age_ms) const {
    if (!chunks_.empty() && now_ms >= chunks_.front().created_ms &&
        now_ms - chunks_.front().created_ms > max_age_ms) {
      throw QueueError(QueueFailure::age);
    }
  }

  void clear() {
    chunks_.clear();
    size_ = 0;
  }

 private:
  struct Chunk {
    std::vector<uint8_t> data;
    size_t offset;
    uint64_t created_ms;
  };
  const size_t limit_;
  size_t size_ = 0;
  std::deque<Chunk> chunks_;
};

} // namespace povad
