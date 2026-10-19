import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:package_info_plus/package_info_plus.dart';

const _releasesApi =
    'https://api.github.com/repos/ialexpovad/povad/releases?per_page=20';

typedef ReleaseLoader = Future<List<dynamic>> Function();
typedef AppBuildReader = Future<AppBuild> Function();

final class AppBuild {
  const AppBuild(this.version, this.buildNumber);

  final String version;
  final String buildNumber;

  String get label => buildNumber.isEmpty ? version : '$version ($buildNumber)';
}

final class AvailableRelease {
  const AvailableRelease(this.version, this.page);

  final String version;
  final Uri page;
}

/// Discovers published, platform-compatible GitHub releases. Installation is
/// delegated to the operating system until signed installers are available.
final class ReleaseUpdates {
  ReleaseUpdates({
    ReleaseLoader? loadReleases,
    AppBuildReader? readBuild,
    String? assetPlatform,
  }) : _loadReleases = loadReleases ?? _loadGitHubReleases,
       _readBuild = readBuild ?? _readPlatformBuild,
       _assetPlatform = assetPlatform ?? _currentAssetPlatform();

  final ReleaseLoader _loadReleases;
  final AppBuildReader _readBuild;
  final String? _assetPlatform;

  Future<AppBuild> installedBuild() => _readBuild();

  Future<AvailableRelease?> check(AppBuild installed) async {
    final current = _ReleaseVersion.parse(installed.version);
    final platform = _assetPlatform;
    if (current == null || platform == null) return null;

    _ReleaseVersion? newest;
    AvailableRelease? selected;
    for (final item in await _loadReleases()) {
      if (item is! Map || item['draft'] == true) continue;
      final tag = item['tag_name'];
      if (tag is! String) continue;
      final version = _ReleaseVersion.parse(tag);
      if (version == null || version.compareTo(current) <= 0) continue;
      if (!current.isPrerelease &&
          (version.isPrerelease || item['prerelease'] == true)) {
        continue;
      }
      final wanted = 'Povad-$tag-$platform';
      final assets = item['assets'];
      if (assets is! List ||
          !assets.any(
            (asset) =>
                asset is Map &&
                asset['name'] == wanted &&
                asset['state'] == 'uploaded',
          )) {
        continue;
      }
      if (newest != null && newest.compareTo(version) >= 0) continue;
      newest = version;
      selected = AvailableRelease(
        version.display,
        Uri.https('github.com', '/ialexpovad/povad/releases/tag/$tag'),
      );
    }
    return selected;
  }
}

Future<AppBuild> _readPlatformBuild() async {
  final info = await PackageInfo.fromPlatform();
  return AppBuild(info.version, info.buildNumber);
}

String? _currentAssetPlatform() {
  if (Platform.isAndroid) return 'android-arm64.apk';
  if (Platform.isMacOS) return 'macos-arm64.dmg';
  if (Platform.isWindows) return 'windows-x64.zip';
  if (Platform.isLinux) return 'linux-x64.tar.xz';
  return null;
}

Future<List<dynamic>> _loadGitHubReleases() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final request = await client
        .getUrl(Uri.parse(_releasesApi))
        .timeout(const Duration(seconds: 8));
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/vnd.github+json',
    );
    request.headers.set(HttpHeaders.userAgentHeader, 'Povad update check');
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != HttpStatus.ok) {
      throw const HttpException('GitHub releases are unavailable');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 8))) {
      if (bytes.length + chunk.length > 512 * 1024) {
        throw const FormatException('GitHub release response is too large');
      }
      bytes.add(chunk);
    }
    final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (decoded is! List) {
      throw const FormatException('Invalid GitHub release response');
    }
    return decoded;
  } finally {
    client.close(force: true);
  }
}

final class _ReleaseVersion implements Comparable<_ReleaseVersion> {
  const _ReleaseVersion(this.major, this.minor, this.patch, this.prerelease);

  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;

  bool get isPrerelease => prerelease.isNotEmpty;

  String get display =>
      '$major.$minor.$patch'
      '${isPrerelease ? '-${prerelease.join('.')}' : ''}';

  static final _pattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z]+(?:\.[0-9A-Za-z]+)*))?(?:\+[0-9A-Za-z.-]+)?$',
  );

  static _ReleaseVersion? parse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) return null;
    final prerelease = match.group(4);
    return _ReleaseVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      prerelease == null ? const [] : prerelease.split('.'),
    );
  }

  @override
  int compareTo(_ReleaseVersion other) {
    for (final pair in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      final difference = pair.$1.compareTo(pair.$2);
      if (difference != 0) return difference;
    }
    if (!isPrerelease && other.isPrerelease) return 1;
    if (isPrerelease && !other.isPrerelease) return -1;
    for (var i = 0; i < prerelease.length && i < other.prerelease.length; i++) {
      final a = prerelease[i];
      final b = other.prerelease[i];
      final aNumber = int.tryParse(a);
      final bNumber = int.tryParse(b);
      final difference = switch ((aNumber, bNumber)) {
        (int a, int b) => a.compareTo(b),
        (int _, null) => -1,
        (null, int _) => 1,
        _ => a.compareTo(b),
      };
      if (difference != 0) return difference;
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }
}
