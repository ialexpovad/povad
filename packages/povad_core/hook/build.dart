import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    // Flutter can invoke hooks for builds that request no code assets.
    if (!input.config.buildCodeAssets) return;
    final target = input.config.code.targetOS;
    final transport = switch (target) {
      OS.windows => [
        'src/transport_windows.cpp',
        'src/transport_ble_windows.cpp',
      ],
      OS.macOS => [
        'src/transport_posix.cpp',
        'src/transport_tcp_posix.cpp',
        'src/transport_ble_macos.mm',
      ],
      OS.linux => [
        'src/transport_posix.cpp',
        'src/transport_tcp_posix.cpp',
        'src/transport_ble_linux.cpp',
      ],
      OS.android => [
        'src/transport_android.cpp',
        'src/transport_ble_android.cpp',
        'src/transport_tcp_posix.cpp',
      ],
      _ => ['src/transport_unavailable.cpp'],
    };
    // Linux BLE talks to BlueZ through GLib's GDBus, which the Flutter Linux
    // embedder already links; pkg-config gives its headers.
    final gio = target == OS.linux ? _pkgConfig('gio-2.0') : null;
    final builder = CBuilder.library(
      name: input.packageName,
      assetName: 'povad_core_bindings_generated.dart',
      sources: ['src/povad_core.cpp', 'src/bridge.cpp', ...transport],
      includes: ['include', 'src'],
      libraries: switch (target) {
        OS.windows => ['ws2_32', 'windowsapp'],
        OS.macOS => ['c++'],
        OS.linux => gio!.libraries,
        _ => const [],
      },
      frameworks: target == OS.macOS
          ? ['Foundation', 'CoreBluetooth']
          : const [],
      flags: switch (target) {
        OS.macOS => ['-fobjc-arc'],
        OS.windows => ['/bigobj', '/permissive-'],
        OS.linux => gio!.cflags,
        _ => const [],
      },
      defines: const {'POVAD_CORE_BUILD': null},
      language: target == OS.macOS ? Language.objectiveC : Language.cpp,
      std: 'c++17',
      cppLinkStdLib: target == OS.android ? 'c++_static' : null,
    );
    await builder.run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = Level.WARNING
        ..onRecord.listen((record) => stdout.writeln(record.message)),
    );
  });
}

/// Compiler flags and library names from pkg-config.
({List<String> cflags, List<String> libraries}) _pkgConfig(String module) {
  List<String> query(String option) {
    final result = Process.runSync('pkg-config', [option, module]);
    if (result.exitCode != 0) {
      throw StateError('pkg-config cannot find $module: ${result.stderr}');
    }
    return (result.stdout as String)
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
  }

  return (
    cflags: query('--cflags'),
    libraries: [
      for (final flag in query('--libs-only-l'))
        if (flag.startsWith('-l')) flag.substring(2),
    ],
  );
}
