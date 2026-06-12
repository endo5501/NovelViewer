import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:novel_viewer/shared/utils/cancellation_token.dart';

import 'helpers/download_test_helpers.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('download_cancel_test_');
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

  List<File> txtFiles() => Directory('${tempDir.path}/test_novel1')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.txt'))
      .toList();

  group('Download cancellation (F103)', () {
    test('cancelling mid-download stops further downloads, keeps partial, '
        'and closes the client', () async {
      final token = CancellationToken();
      final recording =
          RecordingClient(routingClient(const [FakeRoute('', body: 'ok')]));
      final service = DownloadService(
        client: recording,
        requestDelay: Duration.zero,
      );

      await expectLater(
        service.downloadNovel(
          site: FakeNovelSite(episodes: [ep(1), ep(2), ep(3)]),
          url: Uri.parse('https://example.com/index'),
          outputPath: tempDir.path,
          cancelToken: token,
          onProgress: (current, total, skipped, failed) {
            if (current == 1) token.cancel();
          },
        ),
        throwsA(isA<CancelledException>()),
      );

      // Only the first episode was saved before cancellation.
      expect(txtFiles(), hasLength(1));
      // The in-flight client was closed by the cancellation hook.
      expect(recording.closed, isTrue);
    });

    test('already-downloaded episodes survive cancellation and are skipped on '
        'a later resumed run', () async {
      final cacheCarryingTempReuse = tempDir; // same library across runs

      // First run: cancel after episode 1.
      final token = CancellationToken();
      final service1 = DownloadService(
        client: routingClient(const [FakeRoute('', body: 'first content')]),
        requestDelay: Duration.zero,
      );
      await expectLater(
        service1.downloadNovel(
          site: FakeNovelSite(episodes: [ep(1), ep(2)]),
          url: Uri.parse('https://example.com/index'),
          outputPath: cacheCarryingTempReuse.path,
          cancelToken: token,
          onProgress: (current, total, skipped, failed) {
            if (current == 1) token.cancel();
          },
        ),
        throwsA(isA<CancelledException>()),
      );
      expect(txtFiles(), hasLength(1));

      // Second run (no cancellation): the saved episode 1 is still there.
      final service2 = DownloadService(
        client: routingClient(const [FakeRoute('', body: 'second content')]),
        requestDelay: Duration.zero,
      );
      final result = await service2.downloadNovel(
        site: FakeNovelSite(episodes: [ep(1), ep(2)]),
        url: Uri.parse('https://example.com/index'),
        outputPath: cacheCarryingTempReuse.path,
      );
      expect(result.episodeCount, 2);
      expect(txtFiles(), hasLength(2));
    });

    test('without a cancel token the download behaves normally', () async {
      final service = DownloadService(
        client: routingClient(const [FakeRoute('', body: 'ok')]),
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: FakeNovelSite(episodes: [ep(1), ep(2), ep(3)]),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.episodeCount, 3);
      expect(result.failedCount, 0);
      expect(txtFiles(), hasLength(3));
    });

    test('cancelling before the first index fetch aborts immediately',
        () async {
      final token = CancellationToken()..cancel();
      final service = DownloadService(
        client: routingClient(const [FakeRoute('', body: 'ok')]),
        requestDelay: Duration.zero,
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
      // Nothing was created.
      expect(Directory('${tempDir.path}/test_novel1').existsSync()
              ? txtFiles()
              : <File>[],
          isEmpty);
    });
  });
}
