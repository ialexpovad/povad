/// Groups native worker messages into causes an operator can act on.
/// The worker's own text stays visible in Details; this only adds advice.
enum TroubleHint {
  serialAccess,
  tcpPort,
  disconnected,
  settings,
  delivery,
  clientLeft,
}

TroubleHint? troubleHintFor(String? message) {
  if (message == null || message.isEmpty) return null;
  final text = message.toLowerCase();
  // Uncertain delivery outranks the event that caused it.
  if (text.contains('delivery is uncertain')) return TroubleHint.delivery;
  if (text.contains('client disconnected')) return TroubleHint.clientLeft;
  if (text.contains('disconnected') || text.contains('detached')) {
    return TroubleHint.disconnected;
  }
  if (text.contains('serial read failed')) return TroubleHint.disconnected;
  if (text.contains('baud rate') ||
      text.contains('serial settings') ||
      text.contains('serial format') ||
      text.contains('flow control')) {
    return TroubleHint.settings;
  }
  if (text.contains('tcp listener') ||
      text.contains('tcp port') ||
      text.contains('tcp address')) {
    return TroubleHint.tcpPort;
  }
  if (text.contains('open serial port') ||
      text.contains('reserve serial port') ||
      text.contains('serial port name') ||
      text.contains('open usb serial device') ||
      text.contains('select a local serial port')) {
    return TroubleHint.serialAccess;
  }
  return null;
}
