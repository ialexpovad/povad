import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:povad/app/update_installer.dart';

/// Runs the real install helper on this operating system. CI runs it on
/// Linux and Windows; macOS developers exercise the POSIX script locally.
void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('povad-install'));
  tearDown(() => root.deleteSync(recursive: true));

  Future<int> exitedPid() async {
    final process = await Process.start(
      Platform.isWindows ? 'cmd' : 'true',
      Platform.isWindows ? ['/c', 'exit'] : [],
    );
    await process.exitCode;
    return process.pid;
  }

  void write(String path, String text) => File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  group('POSIX helper', () {
    Future<void> run(String archive, String target) async {
      final script = File('${root.path}/work/install.sh')
        ..createSync(recursive: true)
        ..writeAsStringSync(posixInstallScript);
      final result = await Process.run('/bin/sh', [
        script.path,
        '${await exitedPid()}',
        archive,
        target,
        'povad',
        '0',
      ]);
      expect(result.exitCode, anyOf(0, 1), reason: '${result.stderr}');
    }

    Future<String> pack(
      Map<String, String> files, {
      bool executable = true,
    }) async {
      final source = Directory('${root.path}/source')..createSync();
      files.forEach((name, text) => write('${source.path}/$name', text));
      if (executable && files.containsKey('povad')) {
        await Process.run('chmod', ['+x', '${source.path}/povad']);
      }
      final archive = '${root.path}/work/Povad.tar.xz';
      Directory('${root.path}/work').createSync(recursive: true);
      final tar = await Process.run('tar', [
        '-C',
        source.path,
        '-cJf',
        archive,
        '.',
      ]);
      expect(tar.exitCode, 0, reason: '${tar.stderr}');
      return archive;
    }

    test('replaces the bundle and removes the previous one', () async {
      final target = '${root.path}/app/bundle';
      write('$target/povad', 'old');
      write('$target/stale.txt', 'old only');
      final archive = await pack({'povad': 'new', 'lib/new.so': 'new lib'});
      await run(archive, target);
      expect(File('$target/povad').readAsStringSync(), 'new');
      expect(File('$target/lib/new.so').existsSync(), isTrue);
      expect(File('$target/stale.txt').existsSync(), isFalse);
      expect(Directory('${root.path}/app').listSync(), hasLength(1));
      expect(
        File('${root.path}/work/install.log').readAsStringSync(),
        contains('Installed'),
      );
    });

    test('keeps the current bundle when the update is unusable', () async {
      final target = '${root.path}/app/bundle';
      write('$target/povad', 'old');
      final archive = await pack({'readme.txt': 'no executable'});
      await run(archive, target);
      expect(File('$target/povad').readAsStringSync(), 'old');
      expect(
        File('${root.path}/work/install.log').readAsStringSync(),
        contains('has no povad'),
      );
    });
  }, skip: Platform.isWindows ? 'POSIX only' : null);

  group('Windows helper', () {
    Future<void> run(String archive, String target) async {
      final script = File('${root.path}\\work\\install.ps1')
        ..createSync(recursive: true)
        ..writeAsStringSync(windowsInstallScript);
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script.path,
        '-ProcessId',
        '${await exitedPid()}',
        '-Archive',
        archive,
        '-Target',
        target,
        '-Executable',
        'povad.exe',
        '-Relaunch',
        '0',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    }

    Future<String> pack(Map<String, String> files) async {
      final source = Directory('${root.path}\\source')..createSync();
      files.forEach((name, text) => write('${source.path}\\$name', text));
      Directory('${root.path}\\work').createSync(recursive: true);
      final archive = '${root.path}\\work\\Povad.zip';
      final zip = await Process.run('powershell.exe', [
        '-NoProfile',
        '-Command',
        "Compress-Archive -Path '${source.path}\\*' -DestinationPath '$archive'",
      ]);
      expect(zip.exitCode, 0, reason: '${zip.stderr}');
      return archive;
    }

    test('installs new files over the app folder', () async {
      final target = '${root.path}\\app';
      write('$target\\povad.exe', 'old');
      write('$target\\data\\keep.txt', 'user-visible data');
      final archive = await pack({
        'povad.exe': 'new',
        'data\\flutter_assets\\new.txt': 'new asset',
      });
      await run(archive, target);
      expect(File('$target\\povad.exe').readAsStringSync(), 'new');
      expect(
        File('$target\\data\\flutter_assets\\new.txt').existsSync(),
        isTrue,
      );
      expect(
        File('${root.path}\\work\\install.log').readAsStringSync(),
        contains('Installed'),
      );
    });

    test('keeps the app folder when the update is unusable', () async {
      final target = '${root.path}\\app';
      write('$target\\povad.exe', 'old');
      final archive = await pack({'readme.txt': 'no executable'});
      await run(archive, target);
      expect(File('$target\\povad.exe').readAsStringSync(), 'old');
      expect(
        File('${root.path}\\work\\install.log').readAsStringSync(),
        contains('has no povad.exe'),
      );
    });
  }, skip: Platform.isWindows ? null : 'Windows only');
}
