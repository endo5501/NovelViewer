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

  List<({int index, String title, Uri url})> episodesUpTo(int n) => [
        for (var i = 1; i <= n; i++)
          (index: i, title: '第$i話', url: Uri.parse('https://example.com/$i')),
      ];

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

    test('migrates files with an empty sanitised title (01_.txt)', () async {
      // formatEpisodeFileName(1, '', 99) -> '01_.txt'. The migration must still
      // match such files (regex title group is (.*), not (.+)).
      expect(formatEpisodeFileName(1, '', 99), '01_.txt');
      File('${dir.path}/01_.txt').writeAsStringSync('empty title');

      await migrateEpisodeFileNamePadding(
        directory: dir,
        // safeName('   ') == ''
        episodes: [
          (index: 1, title: '   ', url: Uri.parse('https://example.com/1'))
        ],
        totalEpisodes: 100,
      );

      final names = _txtNames(dir);
      expect(names, contains('001_.txt'));
      expect(names, isNot(contains('01_.txt')));
      expect(File('${dir.path}/001_.txt').readAsStringSync(), 'empty title');
    });

    test('does not migrate a title-changed file when no cache entry exists',
        () async {
      // Same index but a different title, and nothing in the cache proves the
      // file belongs to this episode (e.g. an episode was inserted mid-list and
      // every later index shifted): must be left untouched.
      File('${dir.path}/01_古いタイトル.txt').writeAsStringSync('old title');

      await migrateEpisodeFileNamePadding(
        directory: dir,
        episodes: [
          (index: 1, title: '新しいタイトル', url: Uri.parse('https://example.com/1'))
        ],
        totalEpisodes: 100,
      );

      final names = _txtNames(dir);
      expect(names, contains('01_古いタイトル.txt'));
      expect(names, isNot(contains('001_新しいタイトル.txt')));
    });

    test('migrates a title-changed file when the cache records the old title',
        () async {
      // The adapter now derives a different title for the same episode URL
      // (e.g. Hameln stopped stripping the author's leading number). The cache
      // says this URL was last written as "古いタイトル" at index 1, so the
      // existing file is that episode under a stale name.
      File('${dir.path}/01_古いタイトル.txt').writeAsStringSync('old content');

      await migrateEpisodeFileNamePadding(
        directory: dir,
        episodes: [
          (index: 1, title: '新しいタイトル', url: Uri.parse('https://example.com/1'))
        ],
        totalEpisodes: 100,
        cache: {
          'https://example.com/1': EpisodeCache(
            url: 'https://example.com/1',
            episodeIndex: 1,
            title: '古いタイトル',
            lastModified: '2025/01/01 00:00',
            downloadedAt: DateTime.utc(2025, 1, 1),
          ),
        },
      );

      final names = _txtNames(dir);
      expect(names, contains('001_新しいタイトル.txt'));
      expect(names, isNot(contains('01_古いタイトル.txt')));
      expect(File('${dir.path}/001_新しいタイトル.txt').readAsStringSync(),
          'old content');
    });

    test('deletes the stale title-changed file when the new name already exists',
        () async {
      File('${dir.path}/001_新しいタイトル.txt').writeAsStringSync('canonical');
      File('${dir.path}/001_古いタイトル.txt').writeAsStringSync('garbage');

      await migrateEpisodeFileNamePadding(
        directory: dir,
        episodes: [
          (index: 1, title: '新しいタイトル', url: Uri.parse('https://example.com/1'))
        ],
        totalEpisodes: 100,
        cache: {
          'https://example.com/1': EpisodeCache(
            url: 'https://example.com/1',
            episodeIndex: 1,
            title: '古いタイトル',
            lastModified: '2025/01/01 00:00',
            downloadedAt: DateTime.utc(2025, 1, 1),
          ),
        },
      );

      final names = _txtNames(dir);
      expect(names, contains('001_新しいタイトル.txt'));
      expect(names, isNot(contains('001_古いタイトル.txt')));
      expect(File('${dir.path}/001_新しいタイトル.txt').readAsStringSync(),
          'canonical');
    });

    test('does not claim a same-titled file written for a different episode',
        () async {
      // Two episodes share the title "閑話". Episode Y (previously index 9)
      // moved to index 5 and was renamed, so its cached title still matches the
      // file name of episode X at index 5. That file is X's content, not Y's,
      // so the migration must not rename it under Y's new title.
      File('${dir.path}/05_閑話.txt').writeAsStringSync('episode X content');

      await migrateEpisodeFileNamePadding(
        directory: dir,
        episodes: [
          (index: 5, title: '閑話 改題', url: Uri.parse('https://example.com/y'))
        ],
        totalEpisodes: 99,
        cache: {
          'https://example.com/y': EpisodeCache(
            url: 'https://example.com/y',
            episodeIndex: 9, // Y was written at index 9, not 5.
            title: '閑話',
            lastModified: '2025/01/01 00:00',
            downloadedAt: DateTime.utc(2025, 1, 1),
          ),
        },
      );

      final names = _txtNames(dir);
      expect(names, contains('05_閑話.txt'));
      expect(names, isNot(contains('05_閑話 改題.txt')));
      expect(
          File('${dir.path}/05_閑話.txt').readAsStringSync(), 'episode X content');
    });

    test('does not pad-migrate a same-titled file of a shifted episode',
        () async {
      // Same failure as the title-change case, on the pad-width path: an
      // episode was deleted above index 5, so the episode now at 5 is the one
      // the cache recorded at 6. The file at index 5 carries the same title but
      // is the other episode's content, so it must not be claimed.
      File('${dir.path}/05_閑話.txt').writeAsStringSync('other episode content');

      await migrateEpisodeFileNamePadding(
        directory: dir,
        episodes: [
          (index: 5, title: '閑話', url: Uri.parse('https://example.com/y'))
        ],
        totalEpisodes: 100,
        cache: {
          'https://example.com/y': EpisodeCache(
            url: 'https://example.com/y',
            episodeIndex: 6,
            title: '閑話',
            lastModified: '2025/01/01 00:00',
            downloadedAt: DateTime.utc(2025, 1, 1),
          ),
        },
      );

      final names = _txtNames(dir);
      expect(names, contains('05_閑話.txt'));
      expect(names, isNot(contains('005_閑話.txt')));
      expect(File('${dir.path}/05_閑話.txt').readAsStringSync(),
          'other episode content');
    });

    test('leaves a title-changed file alone when the cached title differs too',
        () async {
      // The cache has an entry for this URL, but it does not describe the file
      // on disk, so the file belongs to something else.
      File('${dir.path}/01_無関係.txt').writeAsStringSync('unrelated');

      await migrateEpisodeFileNamePadding(
        directory: dir,
        episodes: [
          (index: 1, title: '新しいタイトル', url: Uri.parse('https://example.com/1'))
        ],
        totalEpisodes: 100,
        cache: {
          'https://example.com/1': EpisodeCache(
            url: 'https://example.com/1',
            episodeIndex: 1,
            title: '古いタイトル',
            lastModified: '2025/01/01 00:00',
            downloadedAt: DateTime.utc(2025, 1, 1),
          ),
        },
      );

      expect(_txtNames(dir), contains('01_無関係.txt'));
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
        episodes: [
          for (var i = 1; i <= 100; i++)
            (index: i, title: '第$i話', url: Uri.parse('https://example.com/$i')),
        ],
        totalEpisodes: 100,
      );

      final cacheAfter = await cacheRepo.getAllAsMap();
      expect(cacheAfter.keys.toSet(), equals(cacheBefore.keys.toSet()));
      expect(cacheAfter.length, 99);
    });
  });
}
