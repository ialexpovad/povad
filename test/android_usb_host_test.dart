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
              'portCount': 2,
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
    'identical adapter models remain distinguishable after list reordering',
    () {
      const first = AndroidUsbPort(
        deviceName: '/dev/bus/usb/001/002',
        vendorId: 0x0483,
        productId: 0x5740,
        portIndex: 0,
      );
      const second = AndroidUsbPort(
        deviceName: '/dev/bus/usb/001/003',
        vendorId: 0x0483,
        productId: 0x5740,
        portIndex: 0,
      );
      expect(first.labelIn([first]), first.label);
      expect(first.labelIn([first, second]), endsWith('001/002'));
      expect(second.labelIn([first, second]), endsWith('001/003'));
      expect(first.labelIn([second, first]), first.labelIn([first, second]));
      expect(first.nativeSelection, isNot(second.nativeSelection));
    },
  );

  test('an adapter is named by its USB product name when it has one', () {
    const named = AndroidUsbPort(
      deviceName: '/dev/bus/usb/001/004',
      vendorId: 0x0403,
      productId: 0x6001,
      portIndex: 0,
      productName: ' Example Serial Adapter ',
    );
    const unnamed = AndroidUsbPort(
      deviceName: '/dev/bus/usb/001/005',
      vendorId: 0x0403,
      productId: 0x6001,
      portIndex: 0,
    );
    expect(named.label, 'Example Serial Adapter');
    expect(unnamed.label, 'USB 0403:6001');
  });

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
