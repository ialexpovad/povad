/// Exact IPv4 peers admitted to a LAN bridge. Empty input means any peer.
/// Returns null for malformed or oversized input.
List<String>? parseClientAllowlist(String input) {
  if (input.trim().isEmpty) return const [];
  final entries = input
      .split(RegExp(r'[,\n]'))
      .map((part) => part.trim())
      .toList();
  if (entries.length > 32 || entries.any((entry) => entry.isEmpty)) return null;
  for (final entry in entries) {
    final octets = entry.split('.');
    if (octets.length != 4 ||
        octets.any((octet) {
          final value = int.tryParse(octet);
          return value == null ||
              value < 0 ||
              value > 255 ||
              (octet.length > 1 && octet.startsWith('0')) ||
              !RegExp(r'^\d{1,3}$').hasMatch(octet);
        })) {
      return null;
    }
  }
  if (entries.join(',').length >= 512) return null;
  return entries.toSet().toList();
}
