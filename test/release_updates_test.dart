import 'package:flutter_test/flutter_test.dart';
import 'package:povad/app/release_updates.dart';

Map<String, Object> release(
  String tag, {
  bool prerelease = false,
  bool draft = false,
  String platform = 'android-arm64.apk',
  String state = 'uploaded',
}) => {
  'tag_name': tag,
  'prerelease': prerelease,
  'draft': draft,
  'assets': [
    {'name': 'Povad-$tag-$platform', 'state': state},
  ],
};

void main() {
  test('RC installation sees newer RC and chooses highest available', () async {
    final updates = ReleaseUpdates(
      assetPlatform: 'android-arm64.apk',
      readBuild: () async => const AppBuild('0.1.0-rc.1', '2'),
      loadReleases: () async => [
        release('v0.1.0-rc.2', prerelease: true),
        release('v0.1.0-rc.10', prerelease: true),
        release('v0.1.0-rc.3', prerelease: true),
      ],
    );
    final installed = await updates.installedBuild();
    expect(installed.label, '0.1.0-rc.1 (2)');
    final result = await updates.check(installed);
    expect(result?.version, '0.1.0-rc.10');
    expect(
      result?.page.toString(),
      'https://github.com/ialexpovad/povad/releases/tag/v0.1.0-rc.10',
    );
  });

  test('stable installation ignores prereleases and invalid assets', () async {
    final updates = ReleaseUpdates(
      assetPlatform: 'windows-x64.zip',
      loadReleases: () async => [
        release('v1.2.0-rc.1', prerelease: true, platform: 'windows-x64.zip'),
        release('v1.1.0', platform: 'linux-x64.tar.xz'),
        release('v1.1.0', platform: 'windows-x64.zip', state: 'starter'),
        release('v1.0.1', platform: 'windows-x64.zip'),
      ],
    );
    final result = await updates.check(const AppBuild('1.0.0', '7'));
    expect(result?.version, '1.0.1');
  });

  test('drafts, source-only releases, and invalid tags never update', () async {
    final updates = ReleaseUpdates(
      assetPlatform: 'macos-arm64.dmg',
      loadReleases: () async => [
        release('v9.0.0', draft: true, platform: 'macos-arm64.dmg'),
        release('v8.0.0', platform: 'linux-x64.tar.xz'),
        release('v7.0.0/elsewhere', platform: 'macos-arm64.dmg'),
      ],
    );
    expect(await updates.check(const AppBuild('0.1.0-rc.1', '2')), isNull);
  });

  test('macOS QA ZIP is visible but never handed to an installer', () async {
    final updates = ReleaseUpdates(
      assetPlatform: 'macos-unsigned-qa.zip',
      loadReleases: () async => [
        release(
          'v0.1.0-rc.2',
          prerelease: true,
          platform: 'macos-unsigned-qa.zip',
        ),
      ],
    );
    final result = await updates.check(const AppBuild('0.1.0-rc.1', '2'));
    expect(result?.version, '0.1.0-rc.2');
    expect(result?.installable, isFalse);
  });

  test('stable release outranks prerelease of same version', () async {
    final updates = ReleaseUpdates(
      assetPlatform: 'linux-x64.tar.xz',
      loadReleases: () async => [
        release('v0.1.0-rc.20', prerelease: true, platform: 'linux-x64.tar.xz'),
        release('v0.1.0', platform: 'linux-x64.tar.xz'),
      ],
    );
    final result = await updates.check(const AppBuild('0.1.0-rc.1', '2'));
    expect(result?.version, '0.1.0');
  });
}
