import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';

import 'helpers/download_test_helpers.dart';

/// Tests for the F118 empty-index guard: when the first index page parses to no
/// episodes AND no body content (markup drift / site change), the download must
/// throw [EmptyIndexException] and must NOT create an empty novel folder, rather
/// than silently "completing" with episodeCount=0.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('empty_index_guard_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  List<Directory> novelDirs() =>
      tempDir.listSync().whereType<Directory>().toList();

  group('Empty index guard (F118)', () {
    test('throws EmptyIndexException when episodes empty and body null',
        () async {
      final site = FakeNovelSite(episodes: const [], bodyContent: null);
      final service = DownloadService(
        client: routingClient(const [FakeRoute('')]),
        requestDelay: Duration.zero,
      );

      await expectLater(
        service.downloadNovel(
          site: site,
          url: Uri.parse('https://example.com/index'),
          outputPath: tempDir.path,
        ),
        throwsA(isA<EmptyIndexException>()),
      );
    });

    test('does not create a novel folder when the index is empty', () async {
      final site = FakeNovelSite(episodes: const [], bodyContent: null);
      final service = DownloadService(
        client: routingClient(const [FakeRoute('')]),
        requestDelay: Duration.zero,
      );

      try {
        await service.downloadNovel(
          site: site,
          url: Uri.parse('https://example.com/index'),
          outputPath: tempDir.path,
        );
      } on EmptyIndexException {
        // expected
      }

      expect(novelDirs(), isEmpty,
          reason: 'an empty index must not leave a folder on disk');
    });

    test('EmptyIndexException carries the index URL', () async {
      final site = FakeNovelSite(episodes: const [], bodyContent: null);
      final service = DownloadService(
        client: routingClient(const [FakeRoute('')]),
        requestDelay: Duration.zero,
      );

      final url = Uri.parse('https://example.com/index');
      try {
        await service.downloadNovel(
          site: site,
          url: url,
          outputPath: tempDir.path,
        );
        fail('expected EmptyIndexException');
      } on EmptyIndexException catch (e) {
        expect(e.url, url);
      }
    });
  });

  group('Empty index guard does not affect short stories / Aozora (F118)', () {
    test('short story (empty episodes, non-null body) is still downloaded',
        () async {
      final site = FakeNovelSite(episodes: const [], bodyContent: '短編の本文です。');
      final service = DownloadService(
        client: routingClient(const [
          FakeRoute('',
              headers: {'last-modified': 'Thu, 01 Jan 2025 00:00:00 GMT'}),
        ]),
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: site,
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.episodeCount, 1);
      expect(novelDirs(), hasLength(1));
    });
  });
}
