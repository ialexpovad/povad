import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LoginStartupStatus { enabled, disabled, approvalRequired, unavailable }

abstract interface class LoginStartupBackend {
  Future<LoginStartupStatus> read();
  Future<void> setEnabled(bool enabled);
}

/// The OS owns the setting. The local marker applies the default only once,
/// so disabling Povad in system settings is respected on subsequent launches.
class LoginStartup extends ChangeNotifier {
  LoginStartup({
    required this.backend,
    required this.readInitialized,
    required this.markInitialized,
  });

  final LoginStartupBackend backend;
  final Future<bool> Function() readInitialized;
  final Future<void> Function() markInitialized;
  LoginStartupStatus status = LoginStartupStatus.disabled;
  bool busy = false;
  bool failed = false;
  bool _disposed = false;

  static LoginStartup? forDesktop() {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return null;
    }
    final store = SharedPreferencesAsync();
    const key = 'desktop.loginStartupInitialized';
    return LoginStartup(
      backend: Platform.isLinux
          ? LinuxLoginStartup(
              environment: Platform.environment,
              executable: Platform.resolvedExecutable,
            )
          : const NativeLoginStartup(),
      readInitialized: () async => await store.getBool(key) ?? false,
      markInitialized: () => store.setBool(key, true),
    );
  }

  Future<void> initialize() => _run(() async {
    status = await backend.read();
    if (status == LoginStartupStatus.unavailable) return;
    final initialized = await readInitialized();
    if (!initialized) {
      // Persist before changing the OS: never repeatedly re-register after
      // a denied request or a crash between registration and saving.
      await markInitialized();
      if (status == LoginStartupStatus.disabled) {
        await backend.setEnabled(true);
      }
    } else if (status == LoginStartupStatus.enabled) {
      // Refresh an enabled portable installation's executable path after a move.
      await backend.setEnabled(true);
    }
    status = await backend.read();
  });

  Future<void> refresh() => _run(() async => status = await backend.read());

  Future<void> change(bool enabled) => _run(() async {
    await markInitialized();
    await backend.setEnabled(enabled);
    status = await backend.read();
    if (enabled && status == LoginStartupStatus.disabled ||
        !enabled && status != LoginStartupStatus.disabled) {
      throw StateError('Login startup change was not applied');
    }
  });

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    failed = false;
    notifyListeners();
    try {
      await action();
    } catch (_) {
      failed = true;
      try {
        status = await backend.read();
      } catch (_) {
        // Preserve the last confirmed state; never report a failed write as ON.
      }
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class NativeLoginStartup implements LoginStartupBackend {
  const NativeLoginStartup();
  static const channel = MethodChannel('povad/login-startup');

  @override
  Future<LoginStartupStatus> read() async {
    final value = await channel.invokeMethod<String>('status');
    return LoginStartupStatus.values.byName(value!);
  }

  @override
  Future<void> setEnabled(bool enabled) =>
      channel.invokeMethod<void>('setEnabled', enabled);
}

class LinuxLoginStartup implements LoginStartupBackend {
  LinuxLoginStartup({required this.environment, required this.executable});
  final Map<String, String> environment;
  final String executable;

  File get entry {
    final xdg = environment['XDG_CONFIG_HOME'];
    final home = environment['HOME'];
    final String config;
    if (xdg != null && xdg.startsWith('/')) {
      config = xdg;
    } else if (home != null && home.startsWith('/')) {
      config = '$home/.config';
    } else {
      throw StateError('No user configuration directory');
    }
    return File('$config/autostart/io.github.ialexpovad.povad.desktop');
  }

  @override
  Future<LoginStartupStatus> read() async {
    if (!await entry.exists()) return LoginStartupStatus.disabled;
    final text = await entry.readAsString();
    final disabled = RegExp(
      r'^\s*(Hidden\s*=\s*true|X-GNOME-Autostart-enabled\s*=\s*false)\s*$',
      multiLine: true,
    ).hasMatch(text);
    return disabled ? LoginStartupStatus.disabled : LoginStartupStatus.enabled;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final file = entry;
    if (!enabled) {
      if (await file.exists()) await file.delete();
      return;
    }
    final contents = desktopEntry(executable);
    if (await file.exists() && await file.readAsString() == contents) return;
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(file.path);
  }

  @visibleForTesting
  static String desktopEntry(String executable) {
    if (!executable.startsWith('/') ||
        executable.contains(RegExp(r'[\x00\r\n=]'))) {
      throw ArgumentError.value(executable, 'executable');
    }
    // Desktop Entry string escaping precedes Exec argument unquoting.
    final quoted = executable
        .replaceAll(r'\', r'\\\\')
        .replaceAll('"', r'\\"')
        .replaceAll(r'$', r'\\$')
        .replaceAll('`', r'\\`')
        .replaceAll('%', '%%');
    return '[Desktop Entry]\n'
        'Type=Application\n'
        'Name=Povad\n'
        'Exec="$quoted"\n'
        'Terminal=false\n'
        'StartupNotify=false\n';
  }
}
