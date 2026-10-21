import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:povad/app/login_startup.dart';

class _Backend implements LoginStartupBackend {
  LoginStartupStatus status = LoginStartupStatus.disabled;
  final writes = <bool>[];
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<LoginStartupStatus> read() async => status;
  @override
  Future<void> setEnabled(bool enabled) async {
    writes.add(enabled);
    if (fail) throw StateError('Denied');
    await pending?.future;
    status = enabled ? LoginStartupStatus.enabled : LoginStartupStatus.disabled;
  }
}

void main() {
  late _Backend backend;
  late LoginStartup startup;
  var initialized = false;
  setUp(() {
    initialized = false;
    backend = _Backend();
    startup = LoginStartup(
      backend: backend,
      readInitialized: () async => initialized,
      markInitialized: () async => initialized = true,
    );
  });
  tearDown(() => startup.dispose());

  test(
    'first release launch enables startup, choice survives restart',
    () async {
      await startup.initialize();
      expect(initialized, isTrue);
      expect(startup.status, LoginStartupStatus.enabled);
      await startup.change(false);
      await startup.initialize();
      expect(backend.writes, [true, false]);
      expect(startup.status, LoginStartupStatus.disabled);
    },
  );

  test('system disablement is not undone by another launch', () async {
    initialized = true;
    await startup.initialize();
    expect(backend.writes, isEmpty);
    expect(startup.status, LoginStartupStatus.disabled);
  });

  test('enabled registration refreshes portable executable path', () async {
    initialized = true;
    backend.status = LoginStartupStatus.enabled;
    await startup.initialize();
    expect(backend.writes, [true]);
  });

  test('OS approval is preserved and never silently overridden', () async {
    backend.status = LoginStartupStatus.approvalRequired;
    await startup.initialize();
    expect(backend.writes, isEmpty);
    expect(startup.status, LoginStartupStatus.approvalRequired);
  });

  test(
    'failed registration is visible, retry works, no false success',
    () async {
      backend.fail = true;
      await startup.initialize();
      expect(startup.failed, isTrue);
      expect(startup.status, LoginStartupStatus.disabled);
      expect(initialized, isTrue);
      backend.fail = false;
      await startup.change(true);
      expect(startup.failed, isFalse);
      expect(startup.status, LoginStartupStatus.enabled);
    },
  );

  test('unavailable OS does not persist or attempt registration', () async {
    backend.status = LoginStartupStatus.unavailable;
    await startup.initialize();
    expect(initialized, isFalse);
    expect(backend.writes, isEmpty);
  });

  test('rapid changes cannot race native writes', () async {
    backend.pending = Completer<void>();
    final request = startup.change(true);
    await Future<void>.delayed(Duration.zero);
    await startup.change(false);
    expect(backend.writes, [true]);
    backend.pending!.complete();
    await request;
    expect(startup.busy, isFalse);
  });

  test('refresh observes system setting changes', () async {
    await startup.initialize();
    backend.status = LoginStartupStatus.approvalRequired;
    await startup.refresh();
    expect(startup.status, LoginStartupStatus.approvalRequired);
    expect(backend.writes, [true]);
  });

  group('Linux XDG registration', () {
    late Directory directory;
    late LinuxLoginStartup linux;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('povad-login-test-');
      linux = LinuxLoginStartup(
        environment: {'XDG_CONFIG_HOME': directory.path, 'HOME': '/unused'},
        executable: '/opt/Povad app/povad',
      );
    });
    tearDown(() => directory.delete(recursive: true));

    test('creates and removes an actual user startup entry', () async {
      expect(await linux.read(), LoginStartupStatus.disabled);
      await linux.setEnabled(true);
      expect(linux.entry.parent.path, '${directory.path}/autostart');
      expect(
        await linux.entry.readAsString(),
        contains('Exec="/opt/Povad app/povad"'),
      );
      expect(await linux.read(), LoginStartupStatus.enabled);
      await linux.setEnabled(false);
      expect(await linux.entry.exists(), isFalse);
      expect(await linux.read(), LoginStartupStatus.disabled);
    });

    test('respects desktop environment disablement', () async {
      await linux.setEnabled(true);
      await linux.entry.writeAsString('Hidden=true\n', mode: FileMode.append);
      expect(await linux.read(), LoginStartupStatus.disabled);
      await linux.setEnabled(true);
      await linux.entry.writeAsString(
        'X-GNOME-Autostart-enabled=false\n',
        mode: FileMode.append,
      );
      expect(await linux.read(), LoginStartupStatus.disabled);
    });

    test(
      'desktop launcher executes a path with spaces and reserved characters',
      () async {
        final executable = File(
          '${directory.path}/Povad \"quoted\" \$cash%/povad',
        );
        await executable.parent.create();
        await executable.writeAsString(
          '#!/bin/sh\nprintf launched > "\$0.marker"\n',
        );
        expect(
          (await Process.run('chmod', ['+x', executable.path])).exitCode,
          0,
        );
        final registration = LinuxLoginStartup(
          environment: {'XDG_CONFIG_HOME': directory.path},
          executable: executable.path,
        );
        await registration.setEnabled(true);
        final result = await Process.run('gio', [
          'launch',
          registration.entry.path,
        ]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
        final marker = File('${executable.path}.marker');
        for (
          var attempt = 0;
          attempt < 20 && !await marker.exists();
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(await marker.readAsString(), 'launched');
      },
      skip: !Platform.isLinux,
    );

    test('relative XDG path falls back to user home', () {
      final fallback = LinuxLoginStartup(
        environment: {'XDG_CONFIG_HOME': 'relative', 'HOME': directory.path},
        executable: '/opt/povad',
      );
      expect(
        fallback.entry.path,
        '${directory.path}/.config/autostart/io.github.ialexpovad.povad.desktop',
      );
    });

    test('quotes reserved characters and prevents entry injection', () {
      final entry = LinuxLoginStartup.desktopEntry(
        '/opt/a "b"/\$cash`100%\\/povad',
      );
      expect(
        entry,
        contains(r'Exec="/opt/a \\"b\\"/\\$cash\\`100%%\\\\/povad"'),
      );
      expect(
        () => LinuxLoginStartup.desktopEntry('/opt/a\nHidden=false'),
        throwsArgumentError,
      );
      expect(
        () => LinuxLoginStartup.desktopEntry('/opt/a=b'),
        throwsArgumentError,
      );
    });
  });
}
