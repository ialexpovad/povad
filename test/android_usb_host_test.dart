import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/domain/android_usb_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('povad/usb_host');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'available':
          return true;
        case 'list':
          return [
            {
              'deviceName': '/dev/bus/usb/001/002',
              'vendorId': 0x10c4,
              'productId': 0xea60,
              'portIndex': 1,
            },
          ];
        case 'permission':
          return (call.arguments as Map)['deviceName'] ==
              '/dev/bus/usb/001/002';
      }
      throw PlatformException(code: 'UNEXPECTED');
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'USB discovery and permission agree on the native device selection',
    () async {
      const host = AndroidUsbHost();
      expect(await host.available(), isTrue);
      final ports = await host.listPorts();
      expect(ports, hasLength(1));
      expect(ports.single.label, 'USB 10C4:EA60 · 2');
      expect(ports.single.nativeSelection, 'usb:/dev/bus/usb/001/002:1');
      expect(await host.requestPermission(ports.single), isTrue);
    },
  );
}
