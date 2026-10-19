import 'dart:io';

typedef DeviceDirectoryLister = Future<List<String>> Function();

/// Suggests local serial device paths for the setup form. Discovery is
/// read-only, stays on this machine, and never opens a port. Windows COM
/// names are entered manually.
final class SerialPortDiscovery {
  SerialPortDiscovery({String? operatingSystem, DeviceDirectoryLister? list})
    : _os = operatingSystem ?? Platform.operatingSystem,
      _list = list ?? _listDev;

  final String _os;
  final DeviceDirectoryLister _list;

  bool get supported => _os == 'macos' || _os == 'linux';

  Future<List<String>> discover() async {
    if (!supported) return const [];
    final List<String> names;
    try {
      names = await _list();
    } catch (_) {
      // A sandbox or permission policy may hide /dev; manual entry remains.
      return const [];
    }
    final ports = [
      for (final name in names)
        if (_accepts(name)) '/dev/$name',
    ]..sort(_byRelevance);
    return ports;
  }

  bool _accepts(String name) {
    if (_os == 'macos') {
      return name.startsWith('cu.') &&
          !name.contains('Bluetooth-Incoming-Port') &&
          !name.contains('debug-console');
    }
    return RegExp(r'^(ttyUSB|ttyACM|ttyAMA|ttyXRUSB|ttyCH\d+USB|rfcomm)\d+$')
        .hasMatch(name);
  }

  static int _byRelevance(String a, String b) {
    int rank(String path) =>
        RegExp(r'usb|USB|ACM|SLAB|wch', caseSensitive: true).hasMatch(path)
        ? 0
        : 1;
    final difference = rank(a).compareTo(rank(b));
    return difference != 0 ? difference : a.compareTo(b);
  }
}

Future<List<String>> _listDev() async => [
  await for (final entity in Directory('/dev').list(followLinks: false))
    entity.path.substring(entity.path.lastIndexOf('/') + 1),
];
