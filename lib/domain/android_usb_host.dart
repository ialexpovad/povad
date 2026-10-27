import 'package:flutter/services.dart';

/// UI-side discovery and permission brokerage. Byte transfer never crosses
/// the Flutter channel; the C++ worker controls the Android USB session.
final class AndroidUsbHost {
  const AndroidUsbHost();

  static const MethodChannel _channel = MethodChannel('povad/usb_host');

  Future<bool> available() async =>
      await _channel.invokeMethod<bool>('available') ?? false;

  Future<List<AndroidUsbPort>> listPorts() async {
    final raw = await _channel.invokeListMethod<dynamic>('list') ?? [];
    return raw
        .map((item) {
          final value = Map<Object?, Object?>.from(item as Map);
          return AndroidUsbPort(
            deviceName: value['deviceName'] as String,
            vendorId: value['vendorId'] as int,
            productId: value['productId'] as int,
            portIndex: value['portIndex'] as int,
            portCount: value['portCount'] as int? ?? 1,
            productName: value['productName'] as String? ?? '',
          );
        })
        .toList(growable: false);
  }

  Future<bool> requestPermission(AndroidUsbPort port) async =>
      await _channel.invokeMethod<bool>('permission', {
        'deviceName': port.deviceName,
      }) ??
      false;
}

final class AndroidUsbPort {
  const AndroidUsbPort({
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    required this.portIndex,
    this.portCount = 1,
    this.productName = '',
  });

  final String deviceName;
  final int vendorId, productId, portIndex, portCount;

  /// The adapter's name from its USB descriptor; empty when it has none.
  final String productName;

  String get nativeSelection => 'usb:$deviceName:$portIndex';

  /// Identical adapter models need a local bus address in the picker.
  /// This is a label only, not a durable identity or a permission grant.
  String labelIn(List<AndroidUsbPort> ports) {
    if (ports.where((port) => port.label == label).length < 2) return label;
    const prefix = '/dev/bus/usb/';
    final address = deviceName.startsWith(prefix)
        ? deviceName.substring(prefix.length)
        : deviceName;
    return '$label · $address';
  }

  /// The adapter's own name when its descriptor gives one, else its USB
  /// vendor and product IDs; the port number only for multi-port adapters.
  String get label {
    final name = productName.trim().isNotEmpty
        ? productName.trim()
        : 'USB ${vendorId.toRadixString(16).padLeft(4, '0').toUpperCase()}'
              ':${productId.toRadixString(16).padLeft(4, '0').toUpperCase()}';
    return portCount > 1 ? '$name · ${portIndex + 1}' : name;
  }
}
