import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/app_update/data/installer_downloader.dart';
import 'package:novel_viewer/features/app_update/data/release_info.dart';
import 'package:path/path.dart' as p;

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
    tempDir = await Directory.systemTemp.createTemp('downloader_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test(
      'removes the partial download dir and rethrows on a failed download, '
      'without logging when cleanup succeeds', () async {
    final records = <LogRecord>[];
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(sub.cancel);

    final client = MockClient((req) async => http.Response('', 500));
    final downloader = HttpInstallerDownloader(
      httpClient: client,
      userAgent: 'test-agent',
      tempDirProvider: () async => tempDir,
    );

    await expectLater(
      downloader.download(_releaseWithInstaller()),
      throwsA(isA<InstallerDownloadException>()),
    );

    // Partial directory must not be left behind.
    expect(
      Directory(p.join(tempDir.path, 'novel_viewer_update')).existsSync(),
      isFalse,
    );
    // Cleanup succeeded, so the best-effort cleanup catch must stay silent —
    // guards against logging on every failed download.
    expect(
      records.any((r) => r.loggerName == 'app_update.downloader'),
      isFalse,
    );
  });
}
