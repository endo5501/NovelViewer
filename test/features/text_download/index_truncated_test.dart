import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';

import 'helpers/download_test_helpers.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('index_truncated_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  List<File> txtFiles() => Directory('${tempDir.path}/test_novel1')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.txt'))
      .toList();

  group('Index truncation surfaced (F102)', () {
    test('subsequent index page fetch failure sets indexTruncated and keeps '
        'page 1 episodes', () async {
      // Page 1 + episodes return ok; the page-2 index fetch returns HTTP 500.
      final client = routingClient([
        const FakeRoute('p=2', statusCode: 500),
        const FakeRoute('', body: 'ok'),
      ]);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
        // 500 is transient and retried; keep backoff at zero so the test does
        // not wait in real time (F121 retry + F123 no-wall-clock).
        retryBaseDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: FakePagedSite(totalPages: 2, episodesPerPage: 3),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.indexTruncated, isTrue);
      // Only page 1's 3 episodes are present.
      expect(result.episodeCount, 3);
      expect(txtFiles(), hasLength(3));
    });

    test('subsequent index page parse failure sets indexTruncated', () async {
      final client = routingClient(const [FakeRoute('', body: 'ok')]);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: FakePagedSite(
            totalPages: 2, episodesPerPage: 3, throwParseOnPage: 2),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.indexTruncated, isTrue);
      expect(result.episodeCount, 3);
    });

    test('subsequent index page timeout sets indexTruncated (F103 path)',
        () async {
      final client = routingClient([
        const FakeRoute('p=2', delay: Duration(seconds: 10)),
        const FakeRoute('', body: 'ok'),
      ]);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
        requestTimeout: const Duration(milliseconds: 200),
        // Timeout is transient and retried; zero backoff avoids real waits.
        retryBaseDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: FakePagedSite(totalPages: 2, episodesPerPage: 3),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.indexTruncated, isTrue);
      expect(result.episodeCount, 3);
    });

    test('fully fetched multi-page index reports indexTruncated == false',
        () async {
      final client = routingClient(const [FakeRoute('', body: 'ok')]);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: FakePagedSite(totalPages: 3, episodesPerPage: 2),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.indexTruncated, isFalse);
      expect(result.episodeCount, 6);
    });

    test('single-page index reports indexTruncated == false', () async {
      final client = routingClient(const [FakeRoute('', body: 'ok')]);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: FakePagedSite(totalPages: 1, episodesPerPage: 3),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.indexTruncated, isFalse);
      expect(result.episodeCount, 3);
    });

    test('reaching the 100-page limit does not set indexTruncated', () async {
      final client = routingClient(const [FakeRoute('', body: 'ok')]);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: FakePagedSite(totalPages: 1000, episodesPerPage: 1),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.episodeCount, 100); // page limit guard
      expect(result.indexTruncated, isFalse,
          reason: 'hitting the page limit is a deliberate guard, not a failure');
    });
  });
}
