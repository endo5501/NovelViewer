import 'dart:io';

import 'package:novel_viewer/features/app_update/data/installer_downloader.dart';
import 'package:novel_viewer/features/app_update/data/installer_verifier.dart';
import 'package:novel_viewer/features/app_update/data/process_starter.dart';
import 'package:novel_viewer/features/app_update/data/release_info.dart';

enum UpdateOutcome {
  launched,
  missingAsset,
  checksumMismatch,
  downloadFailed,
  launchFailed,
}

class UpdateResult {
  const UpdateResult(this.outcome, [this.message]);
  final UpdateOutcome outcome;
  final String? message;
}

/// Orchestrates the Level 2 update: download -> verify -> launch installer ->
/// exit the app. Collaborators are injected so the flow is unit-testable
/// without real network/process/exit side effects.
class InstallerUpdater {
  InstallerUpdater({
    required InstallerDownloader downloader,
    required InstallerVerifier verifier,
    required ProcessStarter processStarter,
    void Function(int code)? onExit,
  })  : _downloader = downloader,
        _verifier = verifier,
        _processStarter = processStarter,
        _onExit = onExit ?? exit;

  static const installerArgs = ['/SILENT', '/SP-', '/UPDATELAUNCH'];

  final InstallerDownloader _downloader;
  final InstallerVerifier _verifier;
  final ProcessStarter _processStarter;
  final void Function(int code) _onExit;

  Future<UpdateResult> apply(
    ReleaseInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    if (info.installerAsset() == null || info.installerSha256Asset() == null) {
      return const UpdateResult(
          UpdateOutcome.missingAsset, 'installer assets not found in release');
    }

    DownloadedInstaller downloaded;
    try {
      downloaded = await _downloader.download(info, onProgress: onProgress);
    } catch (e) {
      return UpdateResult(UpdateOutcome.downloadFailed, '$e');
    }

    final verified = await _verifier.verify(
      exePath: downloaded.exePath,
      sha256Path: downloaded.sha256Path,
    );
    if (!verified) {
      await _deleteQuietly(downloaded.exePath);
      await _deleteQuietly(downloaded.sha256Path);
      return const UpdateResult(
          UpdateOutcome.checksumMismatch, 'checksum verification failed');
    }

    try {
      await _processStarter.start(downloaded.exePath, installerArgs);
    } catch (e) {
      return UpdateResult(UpdateOutcome.launchFailed, '$e');
    }
    _onExit(0);
    return const UpdateResult(UpdateOutcome.launched);
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // best-effort cleanup
    }
  }
}
