import 'package:povad_core/povad_core.dart';
import 'package:test/test.dart';

void main() {
  test('bundled native ABI matches the Dart package', () {
    expect(nativeAbiVersion(), 1);
  });

  test('typed Dart binding rejects invalid config and closes safely', () async {
    final bridge = NativeBridge();
    expect(bridge.snapshot().state, BridgeState.stopped);
    expect(
      () => bridge.start(const BridgeConfig(serialPort: '')),
      throwsA(isA<NativeBridgeError>()),
    );
    await bridge.close();
    expect(() => bridge.snapshot(), throwsA(isA<NativeBridgeError>()));
  });

  test('UTF-8 serial names cross the FFI boundary', () async {
    final bridge = NativeBridge();
    bridge.start(const BridgeConfig(serialPort: '/dev/прылада-не-існуе'));
    final stopped = await bridge.waitForStop();
    expect(stopped.state, BridgeState.fault);
    expect(stopped.serialOpen, isFalse);
    await bridge.close();
  });
}
