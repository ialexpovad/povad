import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:povad/app/login_startup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native login item can be read, enabled and removed', (
    tester,
  ) async {
    if (!Platform.isMacOS && !Platform.isWindows) return;
    const backend = NativeLoginStartup();
    final initial = await backend.read();
    // CI and the local qualification Mac run macOS 13 or later.
    expect(initial, isNot(LoginStartupStatus.unavailable));
    try {
      await backend.setEnabled(true);
      expect(
        await backend.read(),
        anyOf(LoginStartupStatus.enabled, LoginStartupStatus.approvalRequired),
      );
      await backend.setEnabled(false);
      expect(await backend.read(), LoginStartupStatus.disabled);
      await backend.setEnabled(true);
      expect(
        await backend.read(),
        anyOf(LoginStartupStatus.enabled, LoginStartupStatus.approvalRequired),
      );
    } finally {
      await backend.setEnabled(initial != LoginStartupStatus.disabled);
    }
  });
}
