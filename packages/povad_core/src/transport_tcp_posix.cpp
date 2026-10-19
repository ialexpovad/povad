#include "transport.hpp"

#include <cerrno>

#include <arpa/inet.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <unistd.h>

namespace povad {
namespace {

bool would_block() { return errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR; }

void make_nonblocking(int fd) {
  const int flags = fcntl(fd, F_GETFL, 0);
  if (flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) {
    throw TransportError(PV_NATIVE_FAILURE, "Cannot set nonblocking socket");
  }
}

} // namespace

struct TcpServer::Impl {
  int listener = -1;
  int client = -1;
  bool close_uncertain = false;
};

TcpServer::TcpServer() : impl_(new Impl) {}
TcpServer::~TcpServer() { close(); }

void TcpServer::listen(const char* address, uint16_t port) {
  if (!close()) throw TransportError(PV_NATIVE_FAILURE, "Previous TCP shutdown is uncertain");
  impl_->listener = socket(AF_INET, SOCK_STREAM, 0);
  if (impl_->listener < 0) throw TransportError(PV_NATIVE_FAILURE, "Cannot create TCP listener");
  try {
    // A stopped session with an active client can leave TCP in TIME_WAIT.
    // Permit rebinding that closed endpoint without allowing a second live
    // listener (SO_REUSEPORT is intentionally not enabled).
    const int yes = 1;
    if (setsockopt(impl_->listener, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes)) < 0) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot configure TCP listener");
    }
    sockaddr_in target{};
    target.sin_family = AF_INET;
    target.sin_port = htons(port);
    if (inet_pton(AF_INET, address, &target.sin_addr) != 1 ||
        ::bind(impl_->listener, reinterpret_cast<sockaddr*>(&target), sizeof(target)) < 0) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot bind TCP listener");
    }
    make_nonblocking(impl_->listener);
    if (::listen(impl_->listener, 4) < 0) throw TransportError(PV_NATIVE_FAILURE, "Cannot listen on TCP port");
  } catch (...) {
    close();
    throw;
  }
}

int TcpServer::accept(const char* allowed_clients) {
  sockaddr_in peer{};
  socklen_t peer_length = sizeof(peer);
  const int incoming = ::accept(impl_->listener,
      reinterpret_cast<sockaddr*>(&peer), &peer_length);
  if (incoming < 0) {
    if (would_block()) return 0;
    throw TransportError(PV_NATIVE_FAILURE, "TCP accept failed");
  }
  if (impl_->client >= 0) {
    ::close(incoming);
    return 2;
  }
  char peer_address[INET_ADDRSTRLEN]{};
  if (peer.sin_family != AF_INET ||
      inet_ntop(AF_INET, &peer.sin_addr, peer_address, sizeof(peer_address)) == nullptr ||
      !peer_allowed(allowed_clients, peer_address)) {
    ::close(incoming);
    return 3;
  }
  try {
    make_nonblocking(incoming);
    const int yes = 1;
    if (setsockopt(incoming, IPPROTO_TCP, TCP_NODELAY, &yes, sizeof(yes)) < 0) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot configure TCP client");
    }
#ifdef SO_NOSIGPIPE
    if (setsockopt(incoming, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes)) < 0) {
      throw TransportError(PV_NATIVE_FAILURE, "Cannot protect TCP writes");
    }
#endif
    impl_->client = incoming;
    return 1;
  } catch (...) {
    ::close(incoming);
    throw;
  }
}

bool TcpServer::connected() const { return impl_->client >= 0; }

bool TcpServer::close_client() {
  if (impl_->client < 0) return true;
  if (::close(impl_->client) != 0) return false;
  impl_->client = -1;
  return true;
}

int64_t TcpServer::receive(uint8_t* data, size_t capacity) {
  const ssize_t count = recv(impl_->client, data, capacity, 0);
  if (count < 0) {
    if (would_block()) return -1;
    throw TransportError(PV_NATIVE_FAILURE, "TCP read failed");
  }
  return count;
}

size_t TcpServer::send(const uint8_t* data, size_t length) {
#ifdef MSG_NOSIGNAL
  constexpr int flags = MSG_NOSIGNAL;
#else
  constexpr int flags = 0;
#endif
  const ssize_t count = ::send(impl_->client, data, length, flags);
  if (count < 0) {
    if (would_block()) return 0;
    throw TransportError(PV_DELIVERY_UNCERTAIN, "TCP write failed; delivery is uncertain");
  }
  return static_cast<size_t>(count);
}

bool TcpServer::close() {
  if (impl_->close_uncertain) return false;
  bool closed = true;
  if (impl_->client >= 0) closed = close_client() && closed;
  if (impl_->listener >= 0) {
    closed = ::close(impl_->listener) == 0 && closed;
    impl_->listener = -1;
  }
  impl_->close_uncertain = !closed;
  return closed;
}

} // namespace povad
