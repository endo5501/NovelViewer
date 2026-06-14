import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/app_update/data/installer_downloader.dart';
import 'package:novel_viewer/features/app_update/data/installer_updater.dart';
import 'package:novel_viewer/features/app_update/data/installer_verifier.dart';
import 'package:novel_viewer/features/app_update/data/process_starter.dart';
import 'package:novel_viewer/features/app_update/data/release_info.dart';
import 'package:path/path.dart' as p;

class _SpyProcessStarter implements ProcessStarter {
  _SpyProcessStarter({this.throwOnStart = false});

  final bool throwOnStart;
  String? executable;
  List<String>? arguments;
  int startCount = 0;

  @override
  Future<void> start(String executable, List<String> arguments) async {
    startCount++;
    this.executable = executable;
    this.arguments = arguments;
    if (throwOnStart) throw StateError('cannot start process');
  }
}

/// Writes real temp files so the real InstallerVerifier can run; the sha256
/// content is matched or corrupted per [matchHash].
class _FakeDownloader implements InstallerDownloader {
  _FakeDownloader(this.tempDir, {this.matchHash = true, this.throwError = false});

  final Directory tempDir;
  final bool matchHash;
  final bool throwError;
  int downloadCount = 0;

  @override
  Future<DownloadedInstaller> download(
    ReleaseInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    downloadCount++;
    if (throwError) throw InstallerDownloadException('boom');
    final bytes = [1, 2, 3, 4, 5];
    final exePath = p.join(tempDir.path, 'setup.exe');
    final sha256Path = p.join(tempDir.path, 'setup.exe.sha256');
    await File(exePath).writeAsBytes(bytes);
    final hash = matchHash
        ? sha256.convert(bytes).toString()
        : '0' * 64;
    await File(sha256Path).writeAsString('$hash  setup.exe\n');
    return DownloadedInstaller(exePath: exePath, sha256Path: sha256Path);
  }
}

ReleaseInfo _releaseWithInstaller() => const ReleaseInfo(
      tagName: 'v1.3.0',
      body: 'notes',
      assets: [
        ReleaseAsset(
          name: 'novel_viewer-setup-v1.3.0.exe',
          downloadUrl: 'https://example.com/setup.exe',
        ),
        ReleaseAsset(
          name: 'novel_viewer-setup-v1.3.0.exe.sha256',
          downloadUrl: 'https://example.com/setup.exe.sha256',
        ),
      ],
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('updater_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('happy path: downloads, verifies, launches with flags, then exits',
      () async {
    final spy = _SpyProcessStarter();
    int? exitCode;
    final updater = InstallerUpdater(
      downloader: _FakeDownloader(tempDir, matchHash: true),
      verifier: const InstallerVerifier(),
      processStarter: spy,
      onExit: (code) => exitCode = code,
    );

    final result = await updater.apply(_releaseWithInstaller());

    expect(result.outcome, UpdateOutcome.launched);
    expect(spy.startCount, 1);
    expect(spy.arguments, ['/SILENT', '/SP-', '/UPDATELAUNCH']);
    expect(spy.executable, endsWith('setup.exe'));
    expect(exitCode, 0);
  });

  test('missing installer asset returns missingAsset without downloading',
      () async {
    final fake = _FakeDownloader(tempDir);
    final spy = _SpyProcessStarter();
    final updater = InstallerUpdater(
      downloader: fake,
      verifier: const InstallerVerifier(),
      processStarter: spy,
      onExit: (_) {},
    );

    final result = await updater.apply(
      const ReleaseInfo(tagName: 'v1.3.0', body: '', assets: []),
    );

    expect(result.outcome, UpdateOutcome.missingAsset);
    expect(fake.downloadCount, 0);
    expect(spy.startCount, 0);
  });

  test('checksum mismatch deletes files and does not launch', () async {
    final spy = _SpyProcessStarter();
    int? exitCode;
    final updater = InstallerUpdater(
      downloader: _FakeDownloader(tempDir, matchHash: false),
      verifier: const InstallerVerifier(),
      processStarter: spy,
      onExit: (code) => exitCode = code,
    );

    final result = await updater.apply(_releaseWithInstaller());

    expect(result.outcome, UpdateOutcome.checksumMismatch);
    expect(spy.startCount, 0);
    expect(exitCode, isNull);
    expect(File(p.join(tempDir.path, 'setup.exe')).existsSync(), isFalse);
    expect(File(p.join(tempDir.path, 'setup.exe.sha256')).existsSync(), isFalse);
  });

  test('successful post-mismatch cleanup does not emit a WARNING', () async {
    final records = <LogRecord>[];
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(sub.cancel);

    final updater = InstallerUpdater(
      downloader: _FakeDownloader(tempDir, matchHash: false),
      verifier: const InstallerVerifier(),
      processStarter: _SpyProcessStarter(),
      onExit: (_) {},
    );

    await updater.apply(_releaseWithInstaller());

    // Cleanup of deletable files succeeds, so the best-effort catch must stay
    // silent — guards against logging on every checksum mismatch.
    expect(
      records.any((r) => r.loggerName == 'app_update.installer'),
      isFalse,
    );
  });

  test('download failure returns downloadFailed and does not launch', () async {
    final spy = _SpyProcessStarter();
    final updater = InstallerUpdater(
      downloader: _FakeDownloader(tempDir, throwError: true),
      verifier: const InstallerVerifier(),
      processStarter: spy,
      onExit: (_) {},
    );

    final result = await updater.apply(_releaseWithInstaller());

    expect(result.outcome, UpdateOutcome.downloadFailed);
    expect(spy.startCount, 0);
  });

  test('launch failure returns launchFailed and does not exit', () async {
    final spy = _SpyProcessStarter(throwOnStart: true);
    int? exitCode;
    final updater = InstallerUpdater(
      downloader: _FakeDownloader(tempDir, matchHash: true),
      verifier: const InstallerVerifier(),
      processStarter: spy,
      onExit: (code) => exitCode = code,
    );

    final result = await updater.apply(_releaseWithInstaller());

    expect(result.outcome, UpdateOutcome.launchFailed);
    expect(spy.startCount, 1);
    expect(exitCode, isNull);
  });
}
