import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_repository.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fake adapter that returns a per-URL (title, body) so collection append tests
/// can simulate distinct articles. `parseIndex` keys on the base URL.
class _ArticleSite extends NovelSite {
  final Map<String, ({String title, String? body})> pages;

  _ArticleSite(this.pages);

  @override
  String get siteType => 'web';

  @override
  bool canHandle(Uri url) => true;

  @override
  String extractNovelId(Uri url) => 'ignored';

  @override
  Uri normalizeUrl(Uri url) => url;

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) {
    final page = pages[baseUrl.toString()];
    return NovelIndex(
      title: page?.title ?? 'untitled',
      episodes: const [],
      bodyContent: page?.body,
    );
  }

  @override
  String parseEpisode(String html) => pages[html]?.body ?? '';
}

MockClient _okClient() =>
    MockClient((request) async => http.Response('ok', 200));

List<String> _txtFiles(Directory dir) => dir
    .listSync()
    .whereType<File>()
    .map((f) => f.uri.pathSegments.last)
    .where((n) => n.endsWith('.txt'))
    .toList()
  ..sort();

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('formatCollectionEpisodeFileName', () {
    test('uses a fixed 4-digit zero-padded index', () {
      expect(formatCollectionEpisodeFileName(1, 'はじめに'), '0001_はじめに.txt');
      expect(formatCollectionEpisodeFileName(12, '応用編'), '0012_応用編.txt');
      expect(formatCollectionEpisodeFileName(2, 'a/b'), '0002_a_b.txt');
    });
  });

  group('createCollectionDirectory', () {
    late Directory root;
    late DownloadService service;

    setUp(() {
      root = Directory.systemTemp.createTempSync('coll_dir_test_');
      service = DownloadService(client: _okClient(), requestDelay: Duration.zero);
    });
    tearDown(() => root.deleteSync(recursive: true));

    test('creates a web_<slug> folder from the collection name', () async {
      final collection = await service.createCollectionDirectory(root.path, 'AI論文まとめ');
      expect(collection.folderName, 'web_AI論文まとめ');
      expect(collection.novelId, 'AI論文まとめ');
      expect(Directory(collection.dir.path).existsSync(), isTrue);
    });

    test('appends a suffix when the folder already exists', () async {
      final first = await service.createCollectionDirectory(root.path, '同名');
      final second = await service.createCollectionDirectory(root.path, '同名');
      expect(first.folderName, 'web_同名');
      expect(second.folderName, isNot('web_同名'));
      expect(second.dir.path, isNot(first.dir.path));
    });
  });

  group('downloadArticleIntoCollection', () {
    late Directory root;
    late Directory collectionDir;
    late EpisodeCacheDatabase cacheDb;
    late EpisodeCacheRepository cacheRepo;

    setUp(() async {
      root = Directory.systemTemp.createTempSync('coll_dl_test_');
      collectionDir = Directory('${root.path}/web_collection')..createSync();
      cacheDb = EpisodeCacheDatabase(collectionDir.path);
      cacheRepo = EpisodeCacheRepository(cacheDb);
    });
    tearDown(() async {
      await cacheDb.close();
      root.deleteSync(recursive: true);
    });

    DownloadService serviceFor(Map<String, ({String title, String? body})> pages) =>
        DownloadService(client: _okClient(), requestDelay: Duration.zero);

    test('saves the first article as episode 1 with its own title', () async {
      const url = 'https://blog.example.com/basic';
      final service = serviceFor({});
      final site = _ArticleSite({
        url: (title: '基礎編', body: '基礎的な内容の記事本文です。'),
      });

      final result = await service.downloadArticleIntoCollection(
        site: site,
        url: Uri.parse(url),
        collectionDir: collectionDir,
        episodeCacheRepository: cacheRepo,
      );

      expect(result.episodeIndex, 1);
      expect(result.updated, isFalse);
      expect(result.title, '基礎編');
      expect(_txtFiles(collectionDir), ['0001_基礎編.txt']);
      expect(await cacheRepo.findByUrl(url), isNotNull);
    });

    test('appends a second article as episode 2 and keeps episode 1', () async {
      const basic = 'https://blog.example.com/basic';
      const applied = 'https://blog.example.com/applied';
      final site = _ArticleSite({
        basic: (title: '基礎編', body: '基礎的な内容。'),
        applied: (title: '応用編', body: '応用的な内容。'),
      });
      final service = serviceFor({});

      await service.downloadArticleIntoCollection(
        site: site,
        url: Uri.parse(basic),
        collectionDir: collectionDir,
        episodeCacheRepository: cacheRepo,
      );
      final second = await service.downloadArticleIntoCollection(
        site: site,
        url: Uri.parse(applied),
        collectionDir: collectionDir,
        episodeCacheRepository: cacheRepo,
      );

      expect(second.episodeIndex, 2);
      expect(_txtFiles(collectionDir), ['0001_基礎編.txt', '0002_応用編.txt']);
    });

    test('re-downloading the same URL updates the episode without duplicating',
        () async {
      const url = 'https://blog.example.com/basic';
      final service = serviceFor({});
      final site = _ArticleSite({
        url: (title: '基礎編', body: '初版の本文。'),
      });

      await service.downloadArticleIntoCollection(
        site: site,
        url: Uri.parse(url),
        collectionDir: collectionDir,
        episodeCacheRepository: cacheRepo,
      );

      final site2 = _ArticleSite({
        url: (title: '基礎編', body: '改訂版の本文。'),
      });
      final again = await service.downloadArticleIntoCollection(
        site: site2,
        url: Uri.parse(url),
        collectionDir: collectionDir,
        episodeCacheRepository: cacheRepo,
      );

      expect(again.episodeIndex, 1);
      expect(again.updated, isTrue);
      expect(_txtFiles(collectionDir), ['0001_基礎編.txt']);
      final saved = File('${collectionDir.path}/0001_基礎編.txt').readAsStringSync();
      expect(saved, contains('改訂版'));
    });

    test('updating with a changed title removes the old episode file', () async {
      const url = 'https://blog.example.com/basic';
      final service = serviceFor({});
      await service.downloadArticleIntoCollection(
        site: _ArticleSite({url: (title: '旧タイトル', body: '本文。')}),
        url: Uri.parse(url),
        collectionDir: collectionDir,
        episodeCacheRepository: cacheRepo,
      );
      await service.downloadArticleIntoCollection(
        site: _ArticleSite({url: (title: '新タイトル', body: '本文。')}),
        url: Uri.parse(url),
        collectionDir: collectionDir,
        episodeCacheRepository: cacheRepo,
      );

      expect(_txtFiles(collectionDir), ['0001_新タイトル.txt']);
    });

    test('throws EmptyIndexException and saves nothing when body is empty',
        () async {
      const url = 'https://blog.example.com/spa';
      final service = serviceFor({});
      final site = _ArticleSite({url: (title: 'JSページ', body: null)});

      await expectLater(
        service.downloadArticleIntoCollection(
          site: site,
          url: Uri.parse(url),
          collectionDir: collectionDir,
          episodeCacheRepository: cacheRepo,
        ),
        throwsA(isA<EmptyIndexException>()),
      );
      expect(_txtFiles(collectionDir), isEmpty);
      expect(await cacheRepo.findByUrl(url), isNull);
    });
  });

  group('same URL across separate collections is independent', () {
    test('each collection numbers the shared URL as episode 1', () async {
      final root = Directory.systemTemp.createTempSync('coll_indep_test_');
      final dirA = Directory('${root.path}/web_a')..createSync();
      final dirB = Directory('${root.path}/web_b')..createSync();
      final dbA = EpisodeCacheDatabase(dirA.path);
      final dbB = EpisodeCacheDatabase(dirB.path);
      final cacheA = EpisodeCacheRepository(dbA);
      final cacheB = EpisodeCacheRepository(dbB);
      final service =
          DownloadService(client: _okClient(), requestDelay: Duration.zero);

      const shared = 'https://blog.example.com/shared';
      final site = _ArticleSite({shared: (title: '共有記事', body: '本文。')});

      // Pre-seed collection A with one other article so its next index is 2.
      await service.downloadArticleIntoCollection(
        site: _ArticleSite({'https://blog.example.com/other': (title: '別記事', body: '本文。')}),
        url: Uri.parse('https://blog.example.com/other'),
        collectionDir: dirA,
        episodeCacheRepository: cacheA,
      );

      final inA = await service.downloadArticleIntoCollection(
        site: site,
        url: Uri.parse(shared),
        collectionDir: dirA,
        episodeCacheRepository: cacheA,
      );
      final inB = await service.downloadArticleIntoCollection(
        site: site,
        url: Uri.parse(shared),
        collectionDir: dirB,
        episodeCacheRepository: cacheB,
      );

      expect(inA.episodeIndex, 2);
      expect(inB.episodeIndex, 1);

      await dbA.close();
      await dbB.close();
      root.deleteSync(recursive: true);
    });
  });
}
