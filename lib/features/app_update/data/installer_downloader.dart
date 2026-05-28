import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/app_update/data/release_info.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DownloadedInstaller {
  const DownloadedInstaller({required this.exePath, required this.sha256Path});
  final String exePath;
  final String sha256Path;
}

class InstallerDownloadException implements Exception {
  InstallerDownloadException(this.message);
  final String message;
  @override
  String toString() => 'InstallerDownloadException: $message';
}

/// Downloads the installer EXE and its `.sha256` sidecar to a temp directory.
abstract class InstallerDownloader {
  Future<DownloadedInstaller> download(
    ReleaseInfo info, {
    void Function(double progress)? onProgress,
  });
}

class HttpInstallerDownloader implements InstallerDownloader {
  HttpInstallerDownloader({
    required http.Client httpClient,
    required String userAgent,
    Future<Directory> Function()? tempDirProvider,
    this.downloadTimeout = const Duration(minutes: 5),
  })  : _httpClient = httpClient,
        _userAgent = userAgent,
        _tempDirProvider = tempDirProvider ?? getTemporaryDirectory;

  final http.Client _httpClient;
  final String _userAgent;
  final Future<Directory> Function() _tempDirProvider;

  /// Overall cap per file so a stalled connection cannot freeze the update
  /// dialog (which is non-dismissable during download).
  final Duration downloadTimeout;

  @override
  Future<DownloadedInstaller> download(
    ReleaseInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final exeAsset = info.installerAsset();
    final shaAsset = info.installerSha256Asset();
    if (exeAsset == null || shaAsset == null) {
      throw InstallerDownloadException('installer assets not found in release');
    }

    final base = await _tempDirProvider();
    final dir = Directory(p.join(base.path, 'novel_viewer_update'));
    if (dir.existsSync()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final exePath = p.join(dir.path, exeAsset.name);
    final sha256Path = p.join(dir.path, shaAsset.name);

    try {
      await _downloadTo(exeAsset.downloadUrl, exePath, onProgress)
          .timeout(downloadTimeout);
      await _downloadTo(shaAsset.downloadUrl, sha256Path, null)
          .timeout(downloadTimeout);
    } catch (_) {
      // Don't leave a partial (potentially large) installer behind on failure.
      if (dir.existsSync()) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      }
      rethrow;
    }

    return DownloadedInstaller(exePath: exePath, sha256Path: sha256Path);
  }

  Future<void> _downloadTo(
    String url,
    String destPath,
    void Function(double progress)? onProgress,
  ) async {
    final request = http.Request('GET', Uri.parse(url))
      ..headers['User-Agent'] = _userAgent;
    final response = await _httpClient.send(request);
    if (response.statusCode != 200) {
      throw InstallerDownloadException(
          'download failed for $url (status ${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = File(destPath).openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null && total > 0) {
          onProgress(received / total);
        }
      }
    } finally {
      await sink.close();
    }
  }
}
