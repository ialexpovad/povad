#include "transport.hpp"

#include <algorithm>
#include <cerrno>
#include <cstring>

#include <arpa/inet.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <termios.h>
#include <unistd.h>

namespace povad {
namespace {

bool would_block() { return errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR; }

speed_t baud_speed(uint32_t baud) {
  switch (baud) {
    case 300: return B300;
    case 600: return B600;
    case 1200: return B1200;
    case 2400: return B2400;
    case 4800: return B4800;
    case 9600: return B9600;
    case 19200: return B19200;
    case 38400: return B38400;
    case 57600: return B57600;
    case 115200: return B115200;
    case 230400: return B230400;
    default: throw TransportError(PV_INVALID_CONFIG, "Unsupported serial baud rate");
  }
}

} // namespace

struct SerialPort::Impl {
  int fd = -1;
  bool close_uncertain = false;
};

SerialPort::SerialPort() : impl_(new Impl) {}
SerialPort::~SerialPort() { close(); }

void SerialPort::open(const pv_config& config) {
  if (!close()) throw TransportError(PV_NATIVE_FAILURE, "Previous serial shutdown is uncertain");
  impl_->fd = ::open(config.serial_port, O_RDWR | O_NOCTTY | O_NONBLOCK | O_CLOEXEC);
  if (impl_->fd < 0) throw TransportError(PV_NATIVE_FAILURE, "Cannot open serial port exclusively");
  try {
    if (ioctl(impl_->fd, TIOCEXCL) < 0) throw TransportError(PV_NATIVE_FAILURE, "Cannot reserve serial port");
    termios settings{};
    if (tcgetattr(impl_->fd, &settings) < 0) throw TransportError(PV_NATIVE_FAILURE, "Cannot read serial settings");
    cfmakeraw(&settings);
    // With VMIN=0, an idle nonblocking tty may return zero just like EOF.
    // Require one byte so zero unambiguously means the serial peer is gone.
    settings.c_cc[VMIN] = 1;
    settings.c_cc[VTIME] = 0;
    settings.c_cflag |= CLOCAL | CREAD;
    settings.c_cflag &= ~CSIZE;
    settings.c_cflag |= config.data_bits == 5 ? CS5 : config.data_bits == 6 ? CS6 :
                        config.data_bits == 7 ? CS7 : CS8;
    settings.c_cflag &= ~(PARENB | PARODD | CSTOPB);
    if (config.parity != 'N') {
      settings.c_cflag |= PARENB;
      if (config.parity == 'O') settings.c_cflag |= PARODD;
    }
    if (config.stop_bits_x10 == 20) settings.c_cflag |= CSTOPB;
#ifdef CRTSCTS
    if (config.hardware_flow) settings.c_cflag |= CRTSCTS;
    else settings.c_cflag &= ~CRTSCTS;
#else
    if (config.hardware_flow) throw TransportError(PV_INVALID_CONFIG, "Hardware flow control unavailable");
#endif
    const speed_t speed = baud_speed(config.baud);
    if (cfsetispeed(&settings, speed) < 0 || cfsetospeed(&settings, speed) < 0 ||
        tcsetattr(impl_->fd, TCSANOW, &settings) < 0) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot apply serial settings");
    }
    int modem = 0;
    if (ioctl(impl_->fd, TIOCMGET, &modem) == 0) {
      if (config.dtr) modem |= TIOCM_DTR;
      else modem &= ~TIOCM_DTR;
      if (!config.hardware_flow) {
        if (config.rts) modem |= TIOCM_RTS;
        else modem &= ~TIOCM_RTS;
      }
      if (ioctl(impl_->fd, TIOCMSET, &modem) < 0) {
        throw TransportError(PV_NATIVE_FAILURE, "Cannot apply serial control lines");
      }
    } else if (errno != ENOTTY) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot read serial control lines");
    }
  } catch (...) {
    close();
    throw;
  }
}

size_t SerialPort::read(uint8_t* data, size_t capacity) {
  const ssize_t count = ::read(impl_->fd, data, capacity);
  if (count < 0) {
    if (would_block()) return 0;
    throw TransportError(PV_NATIVE_FAILURE, "Serial read failed");
  }
  if (count == 0 && capacity != 0) {
    throw TransportError(PV_NATIVE_FAILURE, "Serial device disconnected");
  }
  return static_cast<size_t>(count);
}

size_t SerialPort::write(const uint8_t* data, size_t length) {
  const ssize_t count = ::write(impl_->fd, data, length);
  if (count < 0) {
    if (would_block()) return 0;
    throw TransportError(PV_DELIVERY_UNCERTAIN, "Serial write failed; delivery is uncertain");
  }
  return static_cast<size_t>(count);
}

bool SerialPort::write_pending() const { return false; }

bool SerialPort::close() {
  if (impl_->close_uncertain) return false;
  if (impl_->fd >= 0) {
    ioctl(impl_->fd, TIOCNXCL);
    const bool closed = ::close(impl_->fd) == 0;
    impl_->fd = -1;
    impl_->close_uncertain = !closed;
    return closed;
  }
  return true;
}

} // namespace povad
