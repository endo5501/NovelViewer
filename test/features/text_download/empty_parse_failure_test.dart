import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_repository.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/narou_site.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/download_test_helpers.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late Directory novelDir;
  late EpisodeCacheDatabase cacheDb;
  late EpisodeCacheRepository cacheRepo;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('empty_parse_test_');
    novelDir = Directory('${tempDir.path}/test_novel1');
    await novelDir.create(recursive: true);
    cacheDb = EpisodeCacheDatabase(novelDir.path);
    cacheRepo = EpisodeCacheRepository(cacheDb);
  });

  tearDown(() async {
    await cacheDb.close();
    tempDir.deleteSync(recursive: true);
  });

  Episode ep(int i) => Episode(
        index: i,
        title: '第$i話',
        url: Uri.parse('https://example.com/$i'),
        updatedAt: '2025/01/01 00:00',
      );

  // The episode_cache.db lives in the same folder, so count only saved episodes.
  List<File> txtFiles() => novelDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.txt'))
      .toList();

  group('Empty parse is treated as failure (F105)', () {
    test('does not save a .txt file when parseEpisode returns empty', () async {
      final site = FakeNovelSite(episodes: [ep(1)], episodeBody: '');
      final service = DownloadService(
        client: routingClient(const []),
        requestDelay: Duration.zero,
      );

      await service.downloadNovel(
        site: site,
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      expect(txtFiles(), isEmpty,
          reason: 'an episode that parses to empty must not be written to disk');
    });

    test('does not register the episode in the cache when parse is empty',
        () async {
      final site = FakeNovelSite(episodes: [ep(1)], episodeBody: '');
      final service = DownloadService(
        client: routingClient(const []),
        requestDelay: Duration.zero,
      );

      await service.downloadNovel(
        site: site,
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      final cached = await cacheRepo.getAllAsMap();
      expect(cached, isEmpty,
          reason: 'empty parse must not poison the cache (would skip forever)');
    });

    test('counts the empty-parse episode as failed', () async {
      final site = FakeNovelSite(episodes: [ep(1), ep(2)], episodeBody: '');
      final service = DownloadService(
        client: routingClient(const []),
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: site,
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      expect(result.failedCount, 2);
    });

    test('episode is retried on a later run because it was not cached',
        () async {
      // First run: site is broken (empty parse). Nothing cached.
      final brokenSite = FakeNovelSite(episodes: [ep(1)], episodeBody: '');
      final service1 = DownloadService(
        client: routingClient(const []),
        requestDelay: Duration.zero,
      );
      await service1.downloadNovel(
        site: brokenSite,
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      // Second run: site recovered. The episode must be downloaded (not skipped).
      final fixedSite =
          FakeNovelSite(episodes: [ep(1)], episodeBody: '回復した本文');
      final service2 = DownloadService(
        client: routingClient(const []),
        requestDelay: Duration.zero,
      );
      final result = await service2.downloadNovel(
        site: fixedSite,
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      expect(result.skippedCount, 0,
          reason: 'previously-empty episode must not be skipped');
      final files = txtFiles();
      expect(files, hasLength(1));
      expect(await files.first.readAsString(), '回復した本文');
    });

    test('non-empty episodes are still saved and cached normally', () async {
      final site = FakeNovelSite(episodes: [ep(1)], episodeBody: '正常な本文');
      final service = DownloadService(
        client: routingClient(const []),
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: site,
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      expect(result.failedCount, 0);
      final cached = await cacheRepo.getAllAsMap();
      expect(cached, hasLength(1));
    });
  });

  group('Short story path is unaffected by the empty-parse guard (F105 2.5)',
      () {
    test('short story body is still saved (guard only applies to episodes)',
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
        episodeCacheRepository: cacheRepo,
      );

      expect(result.episodeCount, 1);
      expect(result.failedCount, 0);
      final files = txtFiles();
      expect(files, hasLength(1));
      expect(await files.first.readAsString(), '短編の本文です。');
    });
  });

  group('Adapter markup drift produces empty parse (F122 root trigger)', () {
    test('NarouSite.parseEpisode returns empty on a drifted body container',
        () {
      final html = File('test/fixtures/text_download/narou_episode_drifted.html')
          .readAsStringSync();
      expect(NarouSite().parseEpisode(html), isEmpty);
    });

    test('NarouSite.parseEpisode returns text on a valid body container', () {
      final html = File('test/fixtures/text_download/narou_episode_valid.html')
          .readAsStringSync();
      final text = NarouSite().parseEpisode(html);
      expect(text, contains('朝の光が窓から差し込んでいた。'));
    });
  });
}
