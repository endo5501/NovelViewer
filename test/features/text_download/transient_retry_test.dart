import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:novel_viewer/shared/utils/cancellation_token.dart';

import 'helpers/download_test_helpers.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('transient_retry_test_');
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

  // ---- 1.2 sequencedClient helper sanity ----------------------------------

  group('sequencedClient helper (1.2)', () {
    test('503 then 200, last entry repeats', () async {
      final log = <String>[];
      final c = sequencedClient({
        '/x': [
          const FakeRoute('/x', statusCode: 503),
          const FakeRoute('/x', statusCode: 200, body: 'ok'),
        ],
      }, requestLog: log);

      expect((await c.get(Uri.parse('https://e/x'))).statusCode, 503);
      expect((await c.get(Uri.parse('https://e/x'))).statusCode, 200);
      // exhausted -> repeats last (200)
      expect((await c.get(Uri.parse('https://e/x'))).statusCode, 200);
      expect(log.length, 3);
    });

    test('single 503 entry repeats forever', () async {
      final c = sequencedClient({
        '/x': [const FakeRoute('/x', statusCode: 503)],
      });
      expect((await c.get(Uri.parse('https://e/x'))).statusCode, 503);
      expect((await c.get(Uri.parse('https://e/x'))).statusCode, 503);
    });

    test('single 404 entry', () async {
      final c = sequencedClient({
        '/x': [const FakeRoute('/x', statusCode: 404)],
      });
      expect((await c.get(Uri.parse('https://e/x'))).statusCode, 404);
    });

    test('TimeoutException then 200', () async {
      final c = sequencedClient({
        '/x': [
          FakeRoute('/x', error: TimeoutException('t')),
          const FakeRoute('/x', statusCode: 200, body: 'ok'),
        ],
      });
      await expectLater(
        c.get(Uri.parse('https://e/x')),
        throwsA(isA<TimeoutException>()),
      );
      expect((await c.get(Uri.parse('https://e/x'))).statusCode, 200);
    });
  });

  // ---- 2.x retry behaviour through DownloadService -------------------------

  group('Transient fetch retry (F121)', () {
    test('2.1 episode 503 then 200 is retried and saved', () async {
      final log = <String>[];
      final client = sequencedClient({
        '/index': [const FakeRoute('/index', body: 'index')],
        '/ep/1': [
          const FakeRoute('/ep/1', statusCode: 503),
          const FakeRoute('/ep/1', body: 'episode body'),
        ],
      }, requestLog: log);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
        retryBaseDelay: Duration.zero,
        maxRetries: 2,
      );

      final result = await service.downloadNovel(
        site: FakeNovelSite(episodes: [ep(1)]),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.failedCount, 0);
      expect(result.episodeCount, 1);
      expect(log.where((u) => u.contains('/ep/1')).length, 2);
      expect(
        File('${tempDir.path}/test_novel1/1_第1話.txt').existsSync(),
        isTrue,
      );
    });

    test('2.2 later index page 503 then 200 is retried (not truncated)',
        () async {
      final log = <String>[];
      final client = sequencedClient({
        'p=2': [
          const FakeRoute('p=2', statusCode: 503),
          const FakeRoute('p=2', body: 'index2'),
        ],
        '/index': [const FakeRoute('/index', body: 'index1')],
      }, fallback: const FakeRoute('', body: 'episode'), requestLog: log);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
        retryBaseDelay: Duration.zero,
        maxRetries: 2,
      );

      final result = await service.downloadNovel(
        site: FakePagedSite(totalPages: 2, episodesPerPage: 2),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.indexTruncated, isFalse);
      expect(result.episodeCount, 4);
      expect(log.where((u) => u.contains('p=2')).length, 2);
    });

    test('2.3 episode 5xx exhausted -> failedCount + WARNING', () async {
      final logs = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(logs.add);
      addTearDown(sub.cancel);

      final log = <String>[];
      final client = sequencedClient({
        '/index': [const FakeRoute('/index', body: 'index')],
        '/ep/1': [const FakeRoute('/ep/1', statusCode: 503)],
      }, requestLog: log);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
        retryBaseDelay: Duration.zero,
        maxRetries: 2,
      );

      final result = await service.downloadNovel(
        site: FakeNovelSite(episodes: [ep(1)]),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.failedCount, 1);
      // maxRetries + 1 = 3 attempts
      expect(log.where((u) => u.contains('/ep/1')).length, 3);
      expect(
        logs.any((r) =>
            r.level == Level.WARNING &&
            r.message.contains('Failed to download episode')),
        isTrue,
      );
    });

    test('2.4 later index 5xx exhausted -> truncated, prior episodes kept',
        () async {
      final log = <String>[];
      final client = sequencedClient({
        'p=2': [const FakeRoute('p=2', statusCode: 503)],
        '/index': [const FakeRoute('/index', body: 'index1')],
      }, fallback: const FakeRoute('', body: 'episode'), requestLog: log);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
        retryBaseDelay: Duration.zero,
        maxRetries: 2,
      );

      final result = await service.downloadNovel(
        site: FakePagedSite(totalPages: 2, episodesPerPage: 2),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.indexTruncated, isTrue);
      expect(result.episodeCount, 2); // only page 1
      expect(log.where((u) => u.contains('p=2')).length, 3);
    });

    test('2.5 first index 5xx exhausted -> propagates, no empty folder',
        () async {
      final log = <String>[];
      final client = sequencedClient({
        '/index': [const FakeRoute('/index', statusCode: 503)],
      }, requestLog: log);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
        retryBaseDelay: Duration.zero,
        maxRetries: 2,
      );

      await expectLater(
        service.downloadNovel(
          site: FakeNovelSite(episodes: [ep(1)]),
          url: Uri.parse('https://example.com/index'),
          outputPath: tempDir.path,
        ),
        throwsA(isA<HttpException>()),
      );

      expect(log.where((u) => u.contains('/index')).length, 3);
      expect(
        Directory('${tempDir.path}/test_novel1').existsSync(),
        isFalse,
      );
    });

    test('2.6 4xx is not retried (exactly one request)', () async {
      final log = <String>[];
      final client = sequencedClient({
        '/index': [const FakeRoute('/index', body: 'index')],
        '/ep/1': [const FakeRoute('/ep/1', statusCode: 404)],
      }, requestLog: log);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
        retryBaseDelay: Duration.zero,
        maxRetries: 2,
      );

      final result = await service.downloadNovel(
        site: FakeNovelSite(episodes: [ep(1)]),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.failedCount, 1);
      expect(log.where((u) => u.contains('/ep/1')).length, 1);
    });

    test('2.7 TimeoutException then 200 is retried', () async {
      final log = <String>[];
      final client = sequencedClient({
        '/index': [const FakeRoute('/index', body: 'index')],
        '/ep/1': [
          FakeRoute('/ep/1', error: TimeoutException('t')),
          const FakeRoute('/ep/1', body: 'episode body'),
        ],
      }, requestLog: log);
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
        retryBaseDelay: Duration.zero,
        maxRetries: 2,
      );

      final result = await service.downloadNovel(
        site: FakeNovelSite(episodes: [ep(1)]),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.failedCount, 0);
      expect(log.where((u) => u.contains('/ep/1')).length, 2);
    });

    test('2.8 cancellation during retry surfaces as CancelledException',
        () async {
      final token = CancellationToken();
      final client = MockClient((req) async {
        final u = req.url.toString();
        if (u.contains('/index')) return http.Response('index', 200);
        // First (and only) episode fetch returns 503 and triggers cancel, so
        // the retry backoff's cancellation check throws before re-fetching.
        token.cancel();
        return http.Response('', 503);
      });
      final service = DownloadService(
        client: client,
        requestDelay: Duration.zero,
        retryBaseDelay: Duration.zero,
        maxRetries: 2,
      );

      await expectLater(
        service.downloadNovel(
          site: FakeNovelSite(episodes: [ep(1)]),
          url: Uri.parse('https://example.com/index'),
          outputPath: tempDir.path,
          cancelToken: token,
        ),
        throwsA(isA<CancelledException>()),
      );
    });

    test('2.9 maxRetries / retryBaseDelay are injectable with sane defaults',
        () {
      final custom = DownloadService(
        maxRetries: 5,
        retryBaseDelay: const Duration(seconds: 1),
      );
      expect(custom.maxRetries, 5);
      expect(custom.retryBaseDelay, const Duration(seconds: 1));

      final defaults = DownloadService();
      expect(defaults.maxRetries, 2);
      expect(defaults.retryBaseDelay, const Duration(milliseconds: 500));
    });
  });
}
