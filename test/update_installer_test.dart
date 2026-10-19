import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/app/release_updates.dart';
import 'package:povad/app/update_installer.dart';

const _tag = 'v0.1.0-rc.2';
const _asset = 'Povad-$_tag-linux-x64.tar.xz';

AvailableRelease _release({bool checksums = true}) => AvailableRelease(
  '0.1.0-rc.2',
  Uri.https('github.com', '/ialexpovad/povad/releases/tag/$_tag'),
  tag: _tag,
  assetName: _asset,
  asset: Uri.https(
    'github.com',
    '/ialexpovad/povad/releases/download/$_tag/$_asset',
  ),
  checksums: checksums
      ? Uri.https(
          'github.com',
          '/ialexpovad/povad/releases/download/$_tag/SHA256SUMS.txt',
        )
      : null,
);

void main() {
  late Directory work;
  final package = utf8.encode('verified package bytes');
  final digest = sha256.convert(package).toString();

  setUp(() => work = Directory.systemTemp.createTempSync('povad-update-test'));
  tearDown(() => work.deleteSync(recursive: true));

  UpdateInstaller installer({
    String sums = '',
    List<int>? body,
    String landingHost = 'release-assets.githubusercontent.com',
    int? length,
    List<(String, List<String>)>? started,
    String os = 'linux',
  }) => UpdateInstaller(
    operatingSystem: os,
    executable: '${work.path}/app/povad',
    workRoot: () async => work,
    processId: 4242,
    start: (exe, args) async => started?.add((exe, args)),
    open: (uri) async {
      final checksums = uri.path.endsWith('SHA256SUMS.txt');
      final bytes = checksums ? utf8.encode(sums) : body ?? package;
      return DownloadResponse(
        Stream.value(bytes),
        length: checksums ? bytes.length : length ?? bytes.length,
        finalUri: Uri.https(landingHost, '/file'),
      );
    },
  );

  test('checksum lists accept sha256sum output only', () {
    final sums = parseChecksums(
      '${'A' * 64}  Povad-a.zip\n'
      '${'b' * 64} *Povad-b.apk\n'
      'not a checksum line\n'
      '${'c' * 64}  ../escape.zip\n'
      '${'d' * 63}  short.zip\n',
    );
    expect(sums, {'Povad-a.zip': 'a' * 64, 'Povad-b.apk': 'b' * 64});
  });

  test('a matching download is staged with progress', () async {
    final progress = <double>[];
    final staged = await installer(sums: '$digest  $_asset\n')
        .download(_release(), onProgress: progress.add);
    expect(staged.sha256, digest);
    expect(staged.file.readAsBytesSync(), package);
    expect(progress.last, 1);
    expect(File('${staged.file.path}.part').existsSync(), isFalse);
  });

  test('a mismatched download is rejected and removed', () async {
    await expectLater(
      installer(sums: '${'0' * 64}  $_asset\n').download(_release()),
      throwsA(
        isA<UpdateError>().having(
          (e) => e.failure,
          'failure',
          UpdateFailure.checksumMismatch,
        ),
      ),
    );
    expect(
      work
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.tar.xz') || f.path.endsWith('.part')),
      isEmpty,
    );
  });

  test(
    'missing checksums, foreign hosts, and oversize files are refused',
    () async {
      Future<UpdateFailure> failure(Future<void> future) async {
        try {
          await future;
        } on UpdateError catch (error) {
          return error.failure;
        }
        fail('expected an UpdateError');
      }

      expect(
        await failure(installer().download(_release(checksums: false))),
        UpdateFailure.notInstallable,
      );
      expect(
        await failure(
          installer(sums: '$digest  other.zip').download(_release()),
        ),
        UpdateFailure.checksumMissing,
      );
      expect(
        await failure(
          installer(
            sums: '$digest  $_asset',
            landingHost: 'example.com',
          ).download(_release()),
        ),
        UpdateFailure.untrustedHost,
      );
      expect(
        await failure(
          installer(
            sums: '$digest  $_asset',
            length: 500 * 1024 * 1024,
          ).download(_release()),
        ),
        UpdateFailure.tooLarge,
      );
    },
  );

  test(
    'desktop launch hands the verified package to a detached helper',
    () async {
      final started = <(String, List<String>)>[];
      final linux = installer(sums: '$digest  $_asset\n', started: started);
      final staged = await linux.download(_release());
      expect(await linux.launch(staged, relaunch: false), isTrue);
      final (exe, args) = started.single;
      expect(exe, '/bin/sh');
      expect(args, [
        '${staged.file.parent.path}/install.sh',
        '4242',
        staged.file.path,
        '${work.path}/app',
        'povad',
        '0',
      ]);
      expect(
        File('${staged.file.parent.path}/install.sh').readAsStringSync(),
        posixInstallScript,
      );

      // A file changed after verification is never handed over.
      staged.file.writeAsStringSync('tampered');
      await expectLater(linux.launch(staged), throwsA(isA<UpdateError>()));
    },
  );

  test('install methods follow the platform', () {
    expect(installer(os: 'windows').method, InstallMethod.windowsZip);
    expect(installer(os: 'linux').method, InstallMethod.linuxTarXz);
    expect(installer(os: 'android').method, InstallMethod.androidApk);
    expect(installer(os: 'macos').method, InstallMethod.manual);
  });

  test('Android only accepts a started package installer', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('povad/update');
    String outcome = 'started';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => outcome);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final file = File('${work.path}/verified.apk')..writeAsBytesSync(package);
    final staged = StagedUpdate(
      version: '0.1.0-rc.2',
      file: file,
      sha256: digest,
    );
    final android = installer(os: 'android');
    expect(await android.launch(staged), isTrue);
    outcome = 'permission';
    expect(await android.launch(staged), isFalse);
    outcome = 'missing';
    await expectLater(
      android.launch(staged),
      throwsA(
        isA<UpdateError>().having(
          (error) => error.failure,
          'failure',
          UpdateFailure.installerUnavailable,
        ),
      ),
    );
  });
}
