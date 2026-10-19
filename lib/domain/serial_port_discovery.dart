import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef DeviceDirectoryLister = Future<List<String>> Function();

/// Suggests local serial device paths for the setup form. Discovery is
/// read-only, stays on this machine, and never opens a port.
final class SerialPortDiscovery {
  SerialPortDiscovery({String? operatingSystem, DeviceDirectoryLister? list})
    : _os = operatingSystem ?? Platform.operatingSystem,
      _list =
          list ??
          ((operatingSystem ?? Platform.operatingSystem) == 'windows'
              ? _listWindowsDosDevices
              : _listDev);

  final String _os;
  final DeviceDirectoryLister _list;

  bool get supported => _os == 'macos' || _os == 'linux' || _os == 'windows';

  Future<List<String>> discover() async {
    if (!supported) return const [];
    final List<String> names;
    try {
      names = await _list();
    } catch (_) {
      // A device namespace or permission policy may be unavailable.
      return const [];
    }
    final ports = [
      for (final name in names)
        if (_accepts(name))
          _os == 'windows' ? name.toUpperCase() : '/dev/$name',
    ]..sort(_byRelevance);
    return ports;
  }

  bool _accepts(String name) {
    if (_os == 'windows') {
      return RegExp(r'^COM[1-9]\d*$', caseSensitive: false).hasMatch(name);
    }
    if (_os == 'macos') {
      return name.startsWith('cu.') &&
          !name.contains('Bluetooth-Incoming-Port') &&
          !name.contains('debug-console');
    }
    return RegExp(r'^(ttyUSB|ttyACM|ttyAMA|ttyXRUSB|ttyCH\d+USB|rfcomm)\d+$')
        .hasMatch(name);
  }

  static int _byRelevance(String a, String b) {
    final aCom = RegExp(r'^COM(\d+)$').firstMatch(a);
    final bCom = RegExp(r'^COM(\d+)$').firstMatch(b);
    if (aCom != null && bCom != null) {
      return int.parse(aCom.group(1)!).compareTo(int.parse(bCom.group(1)!));
    }
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

typedef _QueryDosDeviceNative = Uint32 Function(
  Pointer<Uint16> deviceName,
  Pointer<Uint16> targetPath,
  Uint32 maxChars,
);
typedef _QueryDosDeviceDart = int Function(
  Pointer<Uint16> deviceName,
  Pointer<Uint16> targetPath,
  int maxChars,
);

/// QueryDosDeviceW returns a double-null-terminated UTF-16 name list. It
/// discovers COM names without opening devices or starting another process.
Future<List<String>> _listWindowsDosDevices() async {
  final query = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<_QueryDosDeviceNative, _QueryDosDeviceDart>(
        'QueryDosDeviceW',
      );
  for (var capacity = 4096; capacity <= 65536; capacity *= 2) {
    final buffer = calloc<Uint16>(capacity);
    try {
      final count = query(nullptr, buffer, capacity);
      if (count == 0) continue;
      final names = <String>[];
      var start = 0;
      for (var i = 0; i < count; i++) {
        if (buffer[i] != 0) continue;
        if (i == start) break;
        names.add(
          String.fromCharCodes([
            for (var index = start; index < i; index++) buffer[index],
          ]),
        );
        start = i + 1;
      }
      return names;
    } finally {
      calloc.free(buffer);
    }
  }
  return const [];
}
