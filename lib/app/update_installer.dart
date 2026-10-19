import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'release_updates.dart';

/// Where the in-app update stands, for the interface.
enum UpdateStage {
  none,
  available,
  downloading,
  ready,
  installing,
  failed,
  manual,
  notWritable,
  needsPermission,
}

/// How this build replaces itself.
enum InstallMethod { windowsZip, linuxTarXz, androidApk, manual }

enum UpdateFailure {
  notInstallable,
  checksumMissing,
  checksumMismatch,
  tooLarge,
  untrustedHost,
  network,
  installerUnavailable,
}

final class UpdateError implements Exception {
  const UpdateError(this.failure, [this.detail = '']);

  final UpdateFailure failure;
  final String detail;

  @override
  String toString() => 'UpdateError(${failure.name}) $detail';
}

/// A verified package waiting to be installed.
final class StagedUpdate {
  const StagedUpdate({
    required this.version,
    required this.file,
    required this.sha256,
  });

  final String version;
  final File file;
  final String sha256;
}

final class DownloadResponse {
  const DownloadResponse(this.body, {this.length, required this.finalUri});

  final Stream<List<int>> body;
  final int? length;
  final Uri finalUri;
}

typedef DownloadOpener = Future<DownloadResponse> Function(Uri uri);
typedef DetachedStarter = Future<void> Function(
  String executable,
  List<String> arguments,
);

/// GitHub serves release files from these hosts after a redirect.
const _trustedHosts = {
  'github.com',
  'objects.githubusercontent.com',
  'release-assets.githubusercontent.com',
};

const _maxPackageBytes = 400 * 1024 * 1024;
const _maxChecksumBytes = 64 * 1024;

/// What the interface needs from an installer.
abstract interface class AppUpdater {
  InstallMethod get method;
  Future<bool> canInstall();
  Future<StagedUpdate> download(
    AvailableRelease release, {
    void Function(double progress)? onProgress,
  });
  Future<bool> launch(StagedUpdate update, {bool relaunch = true});
}

/// Downloads, verifies, and hands over an update. Installation always runs
/// after Povad has exited, so no file of the running build is replaced and
/// the native worker has confirmed shutdown before it starts.
final class UpdateInstaller implements AppUpdater {
  UpdateInstaller({
    String? operatingSystem,
    String? executable,
    Future<Directory> Function()? workRoot,
    DownloadOpener? open,
    DetachedStarter? start,
    MethodChannel? channel,
    int? processId,
    this.helperReadyTimeout = const Duration(seconds: 10),
  }) : _os = operatingSystem ?? Platform.operatingSystem,
       _executable = executable ?? Platform.resolvedExecutable,
       _workDirectory = workRoot,
       _open = open ?? _openHttps,
       _start = start ?? _startDetached,
       _channel = channel ?? const MethodChannel('povad/update'),
       _pid = processId ?? pid;

  final String _os;
  final String _executable;
  final Future<Directory> Function()? _workDirectory;
  final DownloadOpener _open;
  final DetachedStarter _start;
  final MethodChannel _channel;
  final int _pid;
  final Duration helperReadyTimeout;

  @override
  InstallMethod get method => switch (_os) {
    'windows' => InstallMethod.windowsZip,
    'linux' => InstallMethod.linuxTarXz,
    'android' => InstallMethod.androidApk,
    _ => InstallMethod.manual,
  };

  Directory get _installDirectory => File(_executable).parent;

  /// Desktop builds replace their own folder, so they need write access to
  /// it (and, on Linux, to its parent for an atomic folder swap).
  @override
  Future<bool> canInstall() async {
    switch (method) {
      case InstallMethod.manual:
        return false;
      case InstallMethod.androidApk:
        return true;
      case InstallMethod.windowsZip:
        return _writable(_installDirectory);
      case InstallMethod.linuxTarXz:
        return await _writable(_installDirectory) &&
            await _writable(_installDirectory.parent);
    }
  }

  static Future<bool> _writable(Directory directory) async {
    final probe = File(
      '${directory.path}${Platform.pathSeparator}.povad-write-probe',
    );
    try {
      await probe.writeAsString('', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Directory> _work(String tag) async {
    final Directory root;
    if (_workDirectory != null) {
      root = await _workDirectory();
    } else if (method == InstallMethod.androidApk) {
      // The FileProvider exposes only the app cache directory.
      final cache = await _channel.invokeMethod<String>('cacheDir');
      root = Directory('$cache${Platform.pathSeparator}povad-update');
    } else {
      root = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}povad-update',
      );
    }
    final directory = Directory('${root.path}${Platform.pathSeparator}$tag');
    await directory.create(recursive: true);
    return directory;
  }

  /// Downloads the platform package and checks it against the release's
  /// SHA256SUMS.txt before it can be staged.
  @override
  Future<StagedUpdate> download(
    AvailableRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    final asset = release.asset, sums = release.checksums;
    final name = release.assetName, tag = release.tag;
    if (asset == null || sums == null || name == null || tag == null) {
      throw const UpdateError(UpdateFailure.notInstallable);
    }
    final expected = parseChecksums(await _fetchText(sums))[name];
    if (expected == null) {
      throw UpdateError(UpdateFailure.checksumMissing, name);
    }

    final directory = await _work(tag);
    final target = File('${directory.path}${Platform.pathSeparator}$name');
    if (await target.exists() && await _digest(target.openRead()) == expected) {
      onProgress?.call(1);
      return StagedUpdate(
        version: release.version,
        file: target,
        sha256: expected,
      );
    }
    final partial = File('${target.path}.part');
    final response = await _openTrusted(asset);
    final length = response.length;
    if (length != null && length > _maxPackageBytes) {
      throw const UpdateError(UpdateFailure.tooLarge);
    }
    final sink = partial.openWrite();
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    var received = 0;
    try {
      await for (final chunk in response.body.timeout(
        const Duration(seconds: 30),
      )) {
        received += chunk.length;
        if (received > _maxPackageBytes) {
          throw const UpdateError(UpdateFailure.tooLarge);
        }
        hasher.add(chunk);
        sink.add(chunk);
        if (length != null && length > 0) onProgress?.call(received / length);
      }
      hasher.close();
      await sink.close();
    } catch (error) {
      await sink.close();
      await _deleteQuietly(partial);
      if (error is UpdateError) rethrow;
      throw UpdateError(UpdateFailure.network, '$error');
    }
    final actual = digestSink.value.toString();
    if (actual != expected) {
      await _deleteQuietly(partial);
      throw UpdateError(UpdateFailure.checksumMismatch, name);
    }
    if (await target.exists()) await target.delete();
    await partial.rename(target.path);
    onProgress?.call(1);
    return StagedUpdate(version: release.version, file: target, sha256: actual);
  }

  /// Starts the platform installer. On desktop the helper waits for this
  /// process to exit, so the caller must quit right after this returns.
  /// Returns false when Android first needs the install-apps permission.
  @override
  Future<bool> launch(StagedUpdate update, {bool relaunch = true}) async {
    if (await _digest(update.file.openRead()) != update.sha256) {
      throw UpdateError(UpdateFailure.checksumMismatch, update.file.path);
    }
    final directory = update.file.parent.path;
    final executableName = _executable.split(RegExp(r'[\\/]')).last;
    switch (method) {
      case InstallMethod.windowsZip:
        final script = File('$directory\\install.ps1');
        final ready = File('$directory\\helper.ready');
        if (await ready.exists()) await ready.delete();
        await script.writeAsString(windowsInstallScript, flush: true);
        await _start('powershell.exe', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          script.path,
          '-ProcessId',
          '$_pid',
          '-Archive',
          update.file.path,
          '-Target',
          _installDirectory.path,
          '-Executable',
          executableName,
          '-Relaunch',
          relaunch ? '1' : '0',
        ]);
        final deadline = DateTime.now().add(helperReadyTimeout);
        while (!await ready.exists()) {
          if (DateTime.now().isAfter(deadline)) {
            throw const UpdateError(
              UpdateFailure.installerUnavailable,
              'Windows update helper did not start',
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        return true;
      case InstallMethod.linuxTarXz:
        final script = File('$directory/install.sh');
        await script.writeAsString(posixInstallScript, flush: true);
        await _start('/bin/sh', [
          script.path,
          '$_pid',
          update.file.path,
          _installDirectory.path,
          executableName,
          relaunch ? '1' : '0',
        ]);
        return true;
      case InstallMethod.androidApk:
        final outcome = await _channel.invokeMethod<String>('install', {
          'path': update.file.path,
        });
        if (outcome == 'permission') return false;
        if (outcome == 'started') return true;
        throw UpdateError(
          UpdateFailure.installerUnavailable,
          'Android package installer returned $outcome',
        );
      case InstallMethod.manual:
        throw const UpdateError(UpdateFailure.installerUnavailable);
    }
  }

  Future<String> _fetchText(Uri uri) async {
    final response = await _openTrusted(uri);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.body.timeout(
      const Duration(seconds: 15),
    )) {
      bytes.add(chunk);
      if (bytes.length > _maxChecksumBytes) {
        throw const UpdateError(UpdateFailure.tooLarge);
      }
    }
    return utf8.decode(bytes.takeBytes());
  }

  Future<DownloadResponse> _openTrusted(Uri uri) async {
    if (uri.scheme != 'https' || !_trustedHosts.contains(uri.host)) {
      throw UpdateError(UpdateFailure.untrustedHost, uri.host);
    }
    final DownloadResponse response;
    try {
      response = await _open(uri);
    } on UpdateError {
      rethrow;
    } catch (error) {
      throw UpdateError(UpdateFailure.network, '$error');
    }
    final landed = response.finalUri;
    if (landed.scheme != 'https' || !_trustedHosts.contains(landed.host)) {
      throw UpdateError(UpdateFailure.untrustedHost, landed.host);
    }
    return response;
  }
}

/// Parses `sha256sum` output: one `<64 hex>  <file name>` pair per line.
Map<String, String> parseChecksums(String text) {
  final result = <String, String>{};
  final line = RegExp(r'^([0-9a-fA-F]{64}) [ *]([^\s/\\]+)$');
  for (final raw in const LineSplitter().convert(text)) {
    final match = line.firstMatch(raw.trim());
    if (match != null) result[match.group(2)!] = match.group(1)!.toLowerCase();
  }
  return result;
}

Future<String> _digest(Stream<List<int>> bytes) async =>
    (await sha256.bind(bytes).first).toString();

Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {
    // A leftover partial file is overwritten by the next download.
  }
}

final class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

Future<DownloadResponse> _openHttps(Uri uri) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..userAgent = 'Povad updater';
  final request = await client.getUrl(uri).timeout(const Duration(seconds: 15));
  request.followRedirects = true;
  request.maxRedirects = 5;
  final response = await request.close().timeout(const Duration(seconds: 30));
  if (response.statusCode != HttpStatus.ok) {
    client.close(force: true);
    throw HttpException('HTTP ${response.statusCode}', uri: uri);
  }
  var landed = uri;
  for (final redirect in response.redirects) {
    landed = landed.resolveUri(redirect.location);
  }
  final controller = StreamController<List<int>>();
  response.listen(
    controller.add,
    onError: controller.addError,
    onDone: () {
      client.close();
      controller.close();
    },
    cancelOnError: true,
  );
  return DownloadResponse(
    controller.stream,
    length: response.contentLength >= 0 ? response.contentLength : null,
    finalUri: landed,
  );
}

Future<void> _startDetached(String executable, List<String> arguments) async {
  // PowerShell exits before running -File when started with DETACHED_PROCESS
  // on Windows. A normal child keeps running after Povad exits.
  final process = await Process.start(
    executable,
    arguments,
    mode: Platform.isWindows
        ? ProcessStartMode.normal
        : ProcessStartMode.detached,
  );
  if (Platform.isWindows) {
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
  }
}

/// Remembers an update across the restart so the next launch can report
/// whether it took effect, and the operator's automatic-download choice.
abstract interface class UpdatePreferences {
  Future<({String from, String to})?> readPending();
  Future<void> savePending(String from, String to);
  Future<void> clearPending();
  Future<bool> readAutoDownload();
  Future<void> saveAutoDownload(bool value);
}

final class DeviceUpdatePreferences implements UpdatePreferences {
  DeviceUpdatePreferences() : _store = SharedPreferencesAsync();

  final SharedPreferencesAsync _store;

  static const _fromKey = 'update.pendingFrom';
  static const _toKey = 'update.pendingTo';
  static const _autoKey = 'update.autoDownload';

  @override
  Future<({String from, String to})?> readPending() async {
    final from = await _store.getString(_fromKey);
    final to = await _store.getString(_toKey);
    return from == null || to == null ? null : (from: from, to: to);
  }

  @override
  Future<void> savePending(String from, String to) async {
    await _store.setString(_fromKey, from);
    await _store.setString(_toKey, to);
  }

  @override
  Future<void> clearPending() async {
    await _store.remove(_fromKey);
    await _store.remove(_toKey);
  }

  @override
  Future<bool> readAutoDownload() async =>
      await _store.getBool(_autoKey) ?? true;

  @override
  Future<void> saveAutoDownload(bool value) => _store.setBool(_autoKey, value);
}

/// Replaces the Windows app folder after Povad exits. Robocopy merges the new
/// files; a failed copy restores the backup. Povad starts again afterwards
/// either way, and reports on its next launch whether the version changed.
const windowsInstallScript = r'''
param(
  [Parameter(Mandatory = $true)][int]$ProcessId,
  [Parameter(Mandatory = $true)][string]$Archive,
  [Parameter(Mandatory = $true)][string]$Target,
  [Parameter(Mandatory = $true)][string]$Executable,
  [int]$Relaunch = 1
)
$ErrorActionPreference = 'Stop'
$work = Split-Path -Parent $Archive
$log = Join-Path $work 'install.log'
function Write-Log([string]$Message) {
  Add-Content -LiteralPath $log -Value ("{0:o} {1}" -f (Get-Date), $Message)
}
Write-Log 'Started'
Set-Content -LiteralPath (Join-Path $work 'helper.ready') -Value 'ready'
function Copy-Tree([string]$From, [string]$To) {
  & robocopy $From $To /E /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed with $LASTEXITCODE" }
}
try {
  $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
  if ($process -and -not $process.WaitForExit(120000)) {
    throw 'Povad did not exit'
  }
  $stage = Join-Path $work 'stage'
  if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
  Expand-Archive -LiteralPath $Archive -DestinationPath $stage -Force
  if (-not (Test-Path -LiteralPath (Join-Path $stage $Executable))) {
    throw "The update has no $Executable"
  }
  $backup = Join-Path $work 'previous'
  if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
  Copy-Tree $Target $backup
  try {
    Copy-Tree $stage $Target
    Write-Log 'Installed'
  } catch {
    Write-Log "Install failed, restoring: $_"
    Copy-Tree $backup $Target
    throw
  }
} catch {
  Write-Log "Update failed: $_"
} finally {
  if ($Relaunch -eq 1) {
    Start-Process -FilePath (Join-Path $Target $Executable) -WorkingDirectory $Target
  }
}
''';

/// Swaps the Linux bundle folder after Povad exits. The previous folder is
/// kept until the new one is in place, then removed; a failed swap restores
/// it. Povad starts again afterwards either way.
const posixInstallScript = r'''#!/bin/sh
pid=$1
archive=$2
target=$3
executable=$4
relaunch=$5
work=$(dirname "$archive")
log="$work/install.log"
say() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >>"$log"; }
launch() {
  if [ "$relaunch" = 1 ]; then
    (cd "$target" && nohup "./$executable" >/dev/null 2>&1 &)
  fi
}
i=0
while kill -0 "$pid" 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -gt 1200 ]; then say 'Povad did not exit'; exit 1; fi
  sleep 0.1
done
stage="$work/stage"
rm -rf "$stage" && mkdir -p "$stage"
if ! tar -xJf "$archive" -C "$stage"; then
  say 'Cannot extract the update'; launch; exit 1
fi
if [ ! -x "$stage/$executable" ]; then
  say "The update has no $executable"; launch; exit 1
fi
backup="$target.previous-$$"
if ! mv "$target" "$backup"; then
  say 'Cannot move the current version'; launch; exit 1
fi
if mv "$stage" "$target"; then
  rm -rf "$backup"
  say 'Installed'
else
  rm -rf "$target"
  mv "$backup" "$target"
  say 'Install failed; restored the previous version'
fi
launch
''';
