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
      OS.windows => ['src/transport_windows.cpp'],
      OS.macOS ||
      OS.linux => ['src/transport_posix.cpp', 'src/transport_tcp_posix.cpp'],
      OS.android => [
        'src/transport_android.cpp',
        'src/transport_tcp_posix.cpp',
      ],
      _ => ['src/transport_unavailable.cpp'],
    };
    final builder = CBuilder.library(
      name: input.packageName,
      assetName: 'povad_core_bindings_generated.dart',
      sources: ['src/povad_core.cpp', 'src/bridge.cpp', ...transport],
      includes: ['include', 'src'],
      libraries: target == OS.windows ? ['ws2_32'] : const [],
      defines: const {'POVAD_CORE_BUILD': null},
      language: Language.cpp,
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
