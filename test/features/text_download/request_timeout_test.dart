import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

import 'helpers/download_test_helpers.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('request_timeout_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Episode ep(int i) => Episode(
        index: i,
        title: '第$i話',
        url: Uri.parse('https://example.com/ep/$i'),
        updatedAt: '2025/01/01 00:00',
      );

  group('Request timeout (F103)', () {
    test('episode fetch that exceeds the timeout is counted as failed',
        () async {
      // Index responds immediately; the episode request stalls past the timeout.
      final client = routingClient([
        const FakeRoute('/index', body: 'index'),
        const FakeRoute('/ep/', delay: Duration(seconds: 10)),
      ]);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
        requestTimeout: const Duration(milliseconds: 200),
      );

      final result = await service.downloadNovel(
        site: FakeNovelSite(episodes: [ep(1)]),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.failedCount, 1);
    });

    test('first index page timeout propagates out of downloadNovel', () async {
      final client = hangingClient();
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
        requestTimeout: const Duration(milliseconds: 200),
      );

      expect(
        () => service.downloadNovel(
          site: FakeNovelSite(episodes: [ep(1)]),
          url: Uri.parse('https://example.com/index'),
          outputPath: tempDir.path,
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('timeout is configurable (default differs from injected)', () {
      final service =
          DownloadService(requestTimeout: const Duration(seconds: 5));
      expect(service.requestTimeout, const Duration(seconds: 5));
    });
  });
}
