import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/app/release_updates.dart';
import 'package:povad/app/update_installer.dart';
import 'package:povad/main.dart';

import 'widget_test.dart' show MemoryUiPreferences;

const _tag = 'v0.1.0-rc.2';
const _asset = 'Povad-$_tag-linux-x64.tar.xz';

class MemoryUpdatePreferences implements UpdatePreferences {
  ({String from, String to})? pending;
  bool auto = true;

  @override
  Future<({String from, String to})?> readPending() async => pending;
  @override
  Future<void> savePending(String from, String to) async =>
      pending = (from: from, to: to);
  @override
  Future<void> clearPending() async => pending = null;
  @override
  Future<bool> readAutoDownload() async => auto;
  @override
  Future<void> saveAutoDownload(bool value) async => auto = value;
}

/// The real installer's I/O is covered by update_installer_test.dart; widget
/// tests use this fake because file I/O never completes under fake time.
class FakeUpdater implements AppUpdater {
  FakeUpdater(this.started, this.file);

  final List<List<String>> started;
  final File file;

  @override
  InstallMethod get method => InstallMethod.linuxTarXz;

  @override
  Future<bool> canInstall() async => true;

  @override
  Future<StagedUpdate> download(
    AvailableRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    onProgress?.call(1);
    return StagedUpdate(version: release.version, file: file, sha256: 'x');
  }

  @override
  Future<bool> launch(StagedUpdate update, {bool relaunch = true}) async {
    started.add(['launch', update.version, relaunch ? '1' : '0']);
    return true;
  }
}

void main() {
  late Directory work;
  setUp(() {
    work = Directory.systemTemp.createTempSync('povad-flow');
    Directory('${work.path}/app').createSync();
  });
  tearDown(() => work.deleteSync(recursive: true));

  ReleaseUpdates updates({String installed = '0.1.0-rc.1'}) => ReleaseUpdates(
    assetPlatform: 'linux-x64.tar.xz',
    readBuild: () async => AppBuild(installed, '2'),
    loadReleases: () async => [
      {
        'tag_name': _tag,
        'prerelease': true,
        'draft': false,
        'assets': [
          {'name': _asset, 'state': 'uploaded'},
          {'name': 'SHA256SUMS.txt', 'state': 'uploaded'},
        ],
      },
    ],
  );

  FakeUpdater installer(List<List<String>> started) =>
      FakeUpdater(started, File('${work.path}/staged'));

  Future<void> settle(WidgetTester tester) async {
    // File I/O in the installer completes outside the fake clock.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a verified update downloads itself and installs on restart', (
    tester,
  ) async {
    final started = <List<String>>[];
    final store = MemoryUpdatePreferences();
    var exited = false;
    await tester.pumpWidget(
      PovadApp(
        preferences: MemoryUiPreferences(),
        updates: updates(),
        installer: installer(started),
        updatePreferences: store,
        exitForUpdate: () async => exited = true,
      ),
    );
    await settle(tester);
    // Overview offers the ready update in one line.
    expect(find.byKey(const ValueKey('update-notice')), findsOneWidget);
    expect(find.text('Povad 0.1.0-rc.2 is ready to install'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('Restart to update'), findsOneWidget);
    expect(find.text('Download updates automatically'), findsOneWidget);

    await tester.tap(find.text('Restart to update'));
    await settle(tester);
    expect(store.pending, (from: '0.1.0-rc.1', to: '0.1.0-rc.2'));
    expect(started.single, ['launch', '0.1.0-rc.2', '1']);
    expect(exited, isTrue);
  });

  testWidgets('the next launch reports whether the update took effect', (
    tester,
  ) async {
    final store = MemoryUpdatePreferences()
      ..pending = (from: '0.1.0-rc.1', to: '0.1.0-rc.2');
    await tester.pumpWidget(
      PovadApp(
        preferences: MemoryUiPreferences(),
        updates: updates(installed: '0.1.0-rc.2'),
        updatePreferences: store,
      ),
    );
    await settle(tester);
    expect(find.text('Povad was updated to 0.1.0-rc.2.'), findsOneWidget);
    expect(store.pending, isNull);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-result')), findsNothing);

    store.pending = (from: '0.1.0-rc.1', to: '0.1.0-rc.2');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      PovadApp(
        preferences: MemoryUiPreferences(),
        updates: updates(),
        updatePreferences: store,
      ),
    );
    await settle(tester);
    expect(
      find.text(
        'The update to 0.1.0-rc.2 did not complete. Install it from the '
        'release page.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a running bridge defers installation', (tester) async {
    final started = <List<String>>[];
    await tester.pumpWidget(
      PovadApp(
        preferences: MemoryUiPreferences(),
        updates: updates(),
        installer: installer(started),
        updatePreferences: MemoryUpdatePreferences(),
      ),
    );
    await settle(tester);
    // Preview mode lets the test put the bridge into a live state.
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listening').last);
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-notice')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart to update'));
    await tester.pumpAndSettle();
    expect(find.text('Stop the bridge to install the update.'), findsOneWidget);
    expect(started, isEmpty);
  });

  testWidgets('automatic download can be turned off', (tester) async {
    final started = <List<String>>[];
    await tester.pumpWidget(
      PovadApp(
        preferences: MemoryUiPreferences(),
        updates: updates(),
        installer: installer(started),
        updatePreferences: MemoryUpdatePreferences()..auto = false,
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('Download update'), findsOneWidget);
    await tester.tap(find.text('Download update'));
    await settle(tester);
    expect(find.text('Restart to update'), findsOneWidget);
  });
}
