import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_repository.dart';
import 'package:novel_viewer/features/episode_cache/domain/episode_cache.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Site that returns an arbitrary list of episodes for the index, so tests can
/// drive the total episode count (and therefore the zero-pad width).
class _ListSite extends NovelSite {
  final List<Episode> episodes;

  _ListSite(this.episodes);

  @override
  String get siteType => 'test';

  @override
  bool canHandle(Uri url) => true;

  @override
  String extractNovelId(Uri url) => 'novel1';

  @override
  Uri normalizeUrl(Uri url) => url;

  @override
  Map<String, String> requestHeaders(Uri url) => const {};

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) =>
      NovelIndex(title: 'テスト小説', episodes: episodes);

  @override
  String parseEpisode(String html) => html;
}

/// Returns the set of `.txt` file names currently present in [dir].
Set<String> _txtNames(Directory dir) => dir
    .listSync()
    .whereType<File>()
    .map((f) => f.path.split(Platform.pathSeparator).last)
    .where((n) => n.endsWith('.txt'))
    .toSet();

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pad_migration_test_');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  List<({int index, String title})> episodesUpTo(int n) =>
      [for (var i = 1; i <= n; i++) (index: i, title: '第$i話')];

  group('migrateEpisodeFileNamePadding', () {
    test('pad width increase (99 -> 100) renames 2-digit files to 3-digit',
        () async {
      // Existing library: 99 episodes at pad width 2.
      for (var i = 1; i <= 99; i++) {
        File('${dir.path}/${formatEpisodeFileName(i, '第$i話', 99)}')
            .writeAsStringSync('content $i');
      }
      expect(_txtNames(dir), contains('01_第1話.txt'));

      // Now there are 100 episodes (pad width 3).
      await migrateEpisodeFileNamePadding(
        directory: dir,
        episodes: episodesUpTo(100),
        totalEpisodes: 100,
      );

      final names = _txtNames(dir);
      // All migrated to 3-digit, no 2-digit file remains.
      expect(names, contains('001_第1話.txt'));
      expect(names, contains('099_第99話.txt'));
      expect(names.any((n) => n.startsWith('01_')), isFalse);
      expect(names.any((n) => n.startsWith('99_')), isFalse);
      expect(names, hasLength(99));
      // Content preserved across rename.
      expect(File('${dir.path}/001_第1話.txt').readAsStringSync(), 'content 1');
    });

    test('pad width decrease (100 -> 99) renames 3-digit files to 2-digit',
        () async {
      for (var i = 1; i <= 99; i++) {
        File('${dir.path}/${formatEpisodeFileName(i, '第$i話', 100)}')
            .writeAsStringSync('content $i');
      }
      expect(_txtNames(dir), contains('001_第1話.txt'));

      await migrateEpisodeFileNamePadding(
        directory: dir,
        episodes: episodesUpTo(99),
        totalEpisodes: 99,
      );

      final names = _txtNames(dir);
      expect(names, contains('01_第1話.txt'));
      expect(names, contains('99_第99話.txt'));
      expect(names.any((n) => n.startsWith('001_')), isFalse);
      expect(names, hasLength(99));
    });

    test('residual old-width duplicate is deleted, canonical file untouched',
        () async {
      // Both the canonical 3-digit file and a stale 2-digit duplicate exist
      // (from a prior buggy re-download).
      File('${dir.path}/001_第1話.txt').writeAsStringSync('canonical');
      File('${dir.path}/01_第1話.txt').writeAsStringSync('garbage');

      await migrateEpisodeFileNamePadding(
        directory: dir,
        episodes: episodesUpTo(100),
        totalEpisodes: 100,
      );

      final names = _txtNames(dir);
      expect(names, contains('001_第1話.txt'));
      expect(names, isNot(contains('01_第1話.txt')));
      // Canonical file is never overwritten.
      expect(File('${dir.path}/001_第1話.txt').readAsStringSync(), 'canonical');
    });

    test('is a no-op when filenames already match the current pad width',
        () async {
      for (var i = 1; i <= 100; i++) {
        File('${dir.path}/${formatEpisodeFileName(i, '第$i話', 100)}')
            .writeAsStringSync('content $i');
      }
      final before = _txtNames(dir);

      await migrateEpisodeFileNamePadding(
        directory: dir,
        episodes: episodesUpTo(100),
        totalEpisodes: 100,
      );

      expect(_txtNames(dir), equals(before));
    });

    test('does not migrate a file whose title (safeName) differs', () async {
      // Same index but a different title: must be left untouched.
      File('${dir.path}/01_古いタイトル.txt').writeAsStringSync('old title');

      await migrateEpisodeFileNamePadding(
        directory: dir,
        episodes: [(index: 1, title: '新しいタイトル')],
        totalEpisodes: 100,
      );

      final names = _txtNames(dir);
      expect(names, contains('01_古いタイトル.txt'));
      expect(names, isNot(contains('001_新しいタイトル.txt')));
    });
  });

  group('Download skip detection after pad migration', () {
    late Directory tempDir;
    late Directory novelDir;
    late EpisodeCacheDatabase cacheDb;
    late EpisodeCacheRepository cacheRepo;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('pad_migration_dl_test_');
      novelDir = Directory('${tempDir.path}/test_novel1');
      await novelDir.create(recursive: true);
      cacheDb = EpisodeCacheDatabase(novelDir.path);
      cacheRepo = EpisodeCacheRepository(cacheDb);
    });

    tearDown(() async {
      await cacheDb.close();
      tempDir.deleteSync(recursive: true);
    });

    test('99->100 boundary: episodes 1-99 are skipped, only 100 is downloaded',
        () async {
      // Previous state: 99 episodes downloaded at pad width 2, cached.
      for (var i = 1; i <= 99; i++) {
        final title = '第$i話';
        await cacheRepo.upsert(EpisodeCache(
          url: 'https://example.com/$i',
          episodeIndex: i,
          title: title,
          lastModified: '2025/01/01 00:00',
          downloadedAt: DateTime.utc(2025, 1, 1),
        ));
        File('${novelDir.path}/${formatEpisodeFileName(i, title, 99)}')
            .writeAsStringSync('cached $i');
      }

      // Now the index has 100 episodes (episode 100 is new).
      final episodes = [
        for (var i = 1; i <= 100; i++)
          Episode(
            index: i,
            title: '第$i話',
            url: Uri.parse('https://example.com/$i'),
            updatedAt: '2025/01/01 00:00',
          ),
      ];

      final episodeGets = <String>[];
      final mockClient = MockClient((request) async {
        final u = request.url.toString();
        if (u == 'https://example.com/index') {
          return http.Response('index html', 200);
        }
        episodeGets.add(u);
        return http.Response('new episode content', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: _ListSite(episodes),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      expect(result.episodeCount, 100);
      expect(result.skippedCount, 99);
      expect(result.failedCount, 0);
      // Only the genuinely new episode 100 is fetched.
      expect(episodeGets, equals(['https://example.com/100']));

      // Files migrated to 3-digit width, no 2-digit file left behind.
      final names = _txtNames(novelDir);
      expect(names, contains('001_第1話.txt'));
      expect(names, contains('100_第100話.txt'));
      expect(names.any((n) => RegExp(r'^\d{2}_').hasMatch(n)), isFalse);
    });

    test('migration does not modify the episode cache', () async {
      for (var i = 1; i <= 99; i++) {
        final title = '第$i話';
        await cacheRepo.upsert(EpisodeCache(
          url: 'https://example.com/$i',
          episodeIndex: i,
          title: title,
          lastModified: '2025/01/01 00:00',
          downloadedAt: DateTime.utc(2025, 1, 1),
        ));
        File('${novelDir.path}/${formatEpisodeFileName(i, title, 99)}')
            .writeAsStringSync('cached $i');
      }
      final cacheBefore = await cacheRepo.getAllAsMap();

      await migrateEpisodeFileNamePadding(
        directory: novelDir,
        episodes: [for (var i = 1; i <= 100; i++) (index: i, title: '第$i話')],
        totalEpisodes: 100,
      );

      final cacheAfter = await cacheRepo.getAllAsMap();
      expect(cacheAfter.keys.toSet(), equals(cacheBefore.keys.toSet()));
      expect(cacheAfter.length, 99);
    });
  });
}
