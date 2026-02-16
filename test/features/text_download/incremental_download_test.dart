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

class _FakeSite implements NovelSite {
  final List<Episode>? customEpisodes;

  _FakeSite({this.customEpisodes});

  @override
  String get siteType => 'test';

  @override
  bool canHandle(Uri url) => true;

  @override
  String extractNovelId(Uri url) => 'novel1';

  @override
  Uri normalizeUrl(Uri url) => url;

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) {
    return NovelIndex(
      title: 'テスト小説',
      episodes: customEpisodes ?? [
        Episode(
          index: 1,
          title: '第一話',
          url: Uri.parse('https://example.com/1'),
          updatedAt: '2025/01/01 00:00',
        ),
        Episode(
          index: 2,
          title: '第二話',
          url: Uri.parse('https://example.com/2'),
          updatedAt: '2025/01/01 00:00',
        ),
        Episode(
          index: 3,
          title: '第三話',
          url: Uri.parse('https://example.com/3'),
          updatedAt: '2025/01/01 00:00',
        ),
      ],
    );
  }

  @override
  String parseEpisode(String html) => html;
}

class _ShortStorySite implements NovelSite {
  @override
  String get siteType => 'test';

  @override
  bool canHandle(Uri url) => true;

  @override
  String extractNovelId(Uri url) => 'short1';

  @override
  Uri normalizeUrl(Uri url) => url;

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) {
    return const NovelIndex(
      title: '短編テスト小説',
      episodes: [],
      bodyContent: '短編の本文です。',
    );
  }

  @override
  String parseEpisode(String html) => html;
}

class _MultiPageSite implements NovelSite {
  final int totalPages;
  final int episodesPerPage;

  _MultiPageSite({this.totalPages = 2, this.episodesPerPage = 3});

  @override
  String get siteType => 'test';

  @override
  bool canHandle(Uri url) => true;

  @override
  String extractNovelId(Uri url) => 'novel1';

  @override
  Uri normalizeUrl(Uri url) {
    // Strip ?p=N query parameter
    if (url.queryParameters.containsKey('p')) {
      return url.replace(queryParameters: {});
    }
    return url;
  }

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) {
    // Determine current page from URL query parameter
    final pageParam = baseUrl.queryParameters['p'];
    final currentPage = pageParam != null ? int.parse(pageParam) : 1;

    final episodes = <Episode>[];
    for (var i = 1; i <= episodesPerPage; i++) {
      final localIndex = i;
      episodes.add(Episode(
        index: localIndex,
        title: 'ページ$currentPage第$i話',
        url: Uri.parse('https://example.com/p$currentPage/$i'),
        updatedAt: '2025/01/01 00:00',
      ));
    }

    Uri? nextPageUrl;
    if (currentPage < totalPages) {
      nextPageUrl = Uri.parse(
        'https://example.com/index?p=${currentPage + 1}',
      );
    }

    return NovelIndex(
      title: 'マルチページ小説',
      episodes: episodes,
      nextPageUrl: nextPageUrl,
    );
  }

  @override
  String parseEpisode(String html) => html;
}

class _InfinitePageSite implements NovelSite {
  @override
  String get siteType => 'test';

  @override
  bool canHandle(Uri url) => true;

  @override
  String extractNovelId(Uri url) => 'novel1';

  @override
  Uri normalizeUrl(Uri url) => url;

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) {
    final pageParam = baseUrl.queryParameters['p'];
    final currentPage = pageParam != null ? int.parse(pageParam) : 1;

    return NovelIndex(
      title: '無限ページ小説',
      episodes: [
        Episode(
          index: 1,
          title: 'ページ$currentPage第1話',
          url: Uri.parse('https://example.com/p$currentPage/1'),
        ),
      ],
      nextPageUrl: Uri.parse(
        'https://example.com/index?p=${currentPage + 1}',
      ),
    );
  }

  @override
  String parseEpisode(String html) => html;
}

class _EmptyNovelSite implements NovelSite {
  @override
  String get siteType => 'test';

  @override
  bool canHandle(Uri url) => true;

  @override
  String extractNovelId(Uri url) => 'empty1';

  @override
  Uri normalizeUrl(Uri url) => url;

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) {
    return const NovelIndex(
      title: '空の小説',
      episodes: [],
    );
  }

  @override
  String parseEpisode(String html) => html;
}

void main() {
  late Directory tempDir;
  late Directory novelDir;
  late EpisodeCacheDatabase cacheDb;
  late EpisodeCacheRepository cacheRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('incremental_dl_test_');
    novelDir = Directory('${tempDir.path}/test_novel1');
    await novelDir.create(recursive: true);
    cacheDb = EpisodeCacheDatabase(novelDir.path);
    cacheRepo = EpisodeCacheRepository(cacheDb);
  });

  tearDown(() async {
    await cacheDb.close();
    tempDir.deleteSync(recursive: true);
  });

  group('Incremental download', () {
    test('downloads all episodes when cache is empty (new novel)', () async {
      final getRequests = <String>[];

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          getRequests.add(request.url.toString());
          if (request.url.toString() == 'https://example.com/index') {
            return http.Response('index html', 200);
          }
          return http.Response('episode content', 200);
        }
        return http.Response('', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: _FakeSite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      expect(result.episodeCount, 3);
      expect(result.skippedCount, 0);

      // All 3 episodes should have been fetched via GET
      final episodeGets = getRequests.where((u) => u != 'https://example.com/index').toList();
      expect(episodeGets, hasLength(3));
    });

    test('skips cached episodes when updatedAt has not changed', () async {
      // Pre-populate cache and create local files for all 3 episodes
      final titles = ['第一話', '第二話', '第三話'];
      for (var i = 1; i <= 3; i++) {
        final title = titles[i - 1];
        await cacheRepo.upsert(EpisodeCache(
          url: 'https://example.com/$i',
          episodeIndex: i,
          title: title,
          lastModified: '2025/01/01 00:00',
          downloadedAt: DateTime.utc(2025, 1, 1),
        ));
        final fileName = formatEpisodeFileName(i, title, 3);
        File('${novelDir.path}/$fileName').writeAsStringSync('cached content');
      }

      final getRequests = <String>[];

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          getRequests.add(request.url.toString());
          if (request.url.toString() == 'https://example.com/index') {
            return http.Response('index html', 200);
          }
          return http.Response('episode content', 200);
        }
        return http.Response('', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: _FakeSite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      expect(result.skippedCount, 3);
      expect(result.episodeCount, 3);
      // No HEAD requests should be sent - only index page GET
      expect(getRequests, equals(['https://example.com/index']));
    });

    test('downloads episode when updatedAt differs from cached value', () async {
      // Pre-populate cache with old dates and create local files
      await cacheRepo.upsert(EpisodeCache(
        url: 'https://example.com/1',
        episodeIndex: 1,
        title: '第一話',
        lastModified: '2024/12/01 00:00',
        downloadedAt: DateTime.utc(2025, 1, 1),
      ));
      File('${novelDir.path}/${formatEpisodeFileName(1, '第一話', 3)}')
          .writeAsStringSync('old content');
      await cacheRepo.upsert(EpisodeCache(
        url: 'https://example.com/2',
        episodeIndex: 2,
        title: '第二話',
        lastModified: '2025/01/01 00:00',
        downloadedAt: DateTime.utc(2025, 1, 1),
      ));
      File('${novelDir.path}/${formatEpisodeFileName(2, '第二話', 3)}')
          .writeAsStringSync('old content');

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          if (request.url.toString() == 'https://example.com/index') {
            return http.Response('index html', 200);
          }
          return http.Response('updated content', 200);
        }
        return http.Response('', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      // Episodes have updatedAt='2025/01/01 00:00'
      // Episode 1 cache has '2024/12/01 00:00' → should re-download
      // Episode 2 cache has '2025/01/01 00:00' → should skip
      // Episode 3 not in cache → should download
      final result = await service.downloadNovel(
        site: _FakeSite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      expect(result.episodeCount, 3);
      expect(result.skippedCount, 1);
    });

    test('downloads episode when updatedAt is null (always download)', () async {
      // Pre-populate cache and create local file
      await cacheRepo.upsert(EpisodeCache(
        url: 'https://example.com/1',
        episodeIndex: 1,
        title: '第一話',
        lastModified: '2025/01/01 00:00',
        downloadedAt: DateTime.utc(2025, 1, 1),
      ));
      File('${novelDir.path}/${formatEpisodeFileName(1, '第一話', 1)}')
          .writeAsStringSync('cached content');

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          if (request.url.toString() == 'https://example.com/index') {
            return http.Response('index html', 200);
          }
          return http.Response('new content', 200);
        }
        return http.Response('', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      // Episode with updatedAt=null should always be downloaded
      final site = _FakeSite(customEpisodes: [
        Episode(
          index: 1,
          title: '第一話',
          url: Uri.parse('https://example.com/1'),
          updatedAt: null,
        ),
      ]);

      final result = await service.downloadNovel(
        site: site,
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      expect(result.episodeCount, 1);
      expect(result.skippedCount, 0);
    });

    test('saves updatedAt as lastModified in cache after download', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          if (request.url.toString() == 'https://example.com/index') {
            return http.Response('index html', 200);
          }
          return http.Response('episode content', 200);
        }
        return http.Response('', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      await service.downloadNovel(
        site: _FakeSite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      final cached = await cacheRepo.getAllAsMap();
      expect(cached, hasLength(3));
      expect(cached['https://example.com/1']!.title, '第一話');
      expect(cached['https://example.com/1']!.lastModified, '2025/01/01 00:00');
    });

    test('works without cache repository (backward compatible)', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          if (request.url.toString() == 'https://example.com/index') {
            return http.Response('index html', 200);
          }
          return http.Response('episode content', 200);
        }
        return http.Response('', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: _FakeSite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.episodeCount, 3);
      expect(result.skippedCount, 0);
    });

    test('reports progress with skipped count', () async {
      // Pre-populate cache for episodes 1 and 2 and create local files
      final titles = ['第一話', '第二話'];
      for (var i = 1; i <= 2; i++) {
        final title = titles[i - 1];
        await cacheRepo.upsert(EpisodeCache(
          url: 'https://example.com/$i',
          episodeIndex: i,
          title: title,
          lastModified: '2025/01/01 00:00',
          downloadedAt: DateTime.utc(2025, 1, 1),
        ));
        final fileName = formatEpisodeFileName(i, title, 3);
        File('${novelDir.path}/$fileName').writeAsStringSync('cached content');
      }

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          if (request.url.toString() == 'https://example.com/index') {
            return http.Response('index html', 200);
          }
          return http.Response('episode content', 200);
        }
        return http.Response('', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final progressCalls = <(int, int, int)>[];

      await service.downloadNovel(
        site: _FakeSite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
        onProgress: (current, total, skipped) {
          progressCalls.add((current, total, skipped));
        },
      );

      expect(progressCalls, hasLength(3));
      // Episode 1: skipped
      expect(progressCalls[0], (1, 3, 1));
      // Episode 2: skipped
      expect(progressCalls[1], (2, 3, 2));
      // Episode 3: downloaded (new)
      expect(progressCalls[2], (3, 3, 2));
    });

    test('does not apply delay when episode is skipped', () async {
      // Pre-populate cache and create local files for all 3 episodes
      final titles = ['第一話', '第二話', '第三話'];
      for (var i = 1; i <= 3; i++) {
        final title = titles[i - 1];
        await cacheRepo.upsert(EpisodeCache(
          url: 'https://example.com/$i',
          episodeIndex: i,
          title: title,
          lastModified: '2025/01/01 00:00',
          downloadedAt: DateTime.utc(2025, 1, 1),
        ));
        final fileName = formatEpisodeFileName(i, title, 3);
        File('${novelDir.path}/$fileName').writeAsStringSync('cached content');
      }

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('index html', 200);
        }
        return http.Response('', 200);
      });

      // Use a long delay to make the test timing-sensitive
      final service = DownloadService(
        client: mockClient,
        requestDelay: const Duration(seconds: 2),
      );

      final stopwatch = Stopwatch()..start();

      await service.downloadNovel(
        site: _FakeSite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      stopwatch.stop();

      // All 3 episodes are skipped, so no delay should be applied
      // If delays were applied, it would take at least 4 seconds (2s * 2 delays)
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test('applies delay only before actual downloads', () async {
      // Episode 1: new (download), Episode 2: cached (skip), Episode 3: new (download)
      // Delay should be applied once: before episode 3's GET (not before skip)
      await cacheRepo.upsert(EpisodeCache(
        url: 'https://example.com/2',
        episodeIndex: 2,
        title: '第二話',
        lastModified: '2025/01/01 00:00',
        downloadedAt: DateTime.utc(2025, 1, 1),
      ));
      final fileName = formatEpisodeFileName(2, '第二話', 3);
      File('${novelDir.path}/$fileName').writeAsStringSync('cached content');

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          if (request.url.toString() == 'https://example.com/index') {
            return http.Response('index html', 200);
          }
          return http.Response('episode content', 200);
        }
        return http.Response('', 200);
      });

      // Use a long delay
      final service = DownloadService(
        client: mockClient,
        requestDelay: const Duration(seconds: 2),
      );

      final stopwatch = Stopwatch()..start();

      await service.downloadNovel(
        site: _FakeSite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      stopwatch.stop();

      // 1 delay between ep1 download and ep3 download (~2s)
      // NOT 2 delays (~4s) - the skip doesn't add a delay
      expect(stopwatch.elapsedMilliseconds, greaterThan(1500));
      expect(stopwatch.elapsedMilliseconds, lessThan(4000));
    });
  });

  group('Short story download', () {
    test('downloads short story with episodeCount=1', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('index html', 200, headers: {
            'last-modified': 'Thu, 01 Jan 2025 00:00:00 GMT',
          });
        }
        return http.Response('', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: _ShortStorySite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      expect(result.episodeCount, 1);
      expect(result.skippedCount, 0);
      expect(result.title, '短編テスト小説');
      expect(result.folderName, 'test_short1');

      // Verify file was saved
      final file = File('${tempDir.path}/test_short1/1_短編テスト小説.txt');
      expect(file.existsSync(), isTrue);
      expect(await file.readAsString(), '短編の本文です。');
    });

    test('saves short story to episode cache with index page URL', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('index html', 200, headers: {
            'last-modified': 'Thu, 01 Jan 2025 00:00:00 GMT',
          });
        }
        return http.Response('', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      await service.downloadNovel(
        site: _ShortStorySite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      final cached = await cacheRepo.getAllAsMap();
      expect(cached, hasLength(1));
      expect(cached['https://example.com/index'], isNotNull);
      expect(cached['https://example.com/index']!.title, '短編テスト小説');
      expect(cached['https://example.com/index']!.episodeIndex, 1);
    });

    test('skips short story re-download when cache is valid', () async {
      // Pre-populate cache for the short story
      final novelDir = Directory('${tempDir.path}/test_short1');
      await novelDir.create(recursive: true);
      await cacheRepo.upsert(EpisodeCache(
        url: 'https://example.com/index',
        episodeIndex: 1,
        title: '短編テスト小説',
        lastModified: 'Thu, 01 Jan 2025 00:00:00 GMT',
        downloadedAt: DateTime.utc(2025, 1, 1),
      ));
      File('${novelDir.path}/1_短編テスト小説.txt')
          .writeAsStringSync('cached content');

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('index html', 200, headers: {
            'last-modified': 'Thu, 01 Jan 2025 00:00:00 GMT',
          });
        }
        return http.Response('', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: _ShortStorySite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      expect(result.episodeCount, 1);
      expect(result.skippedCount, 1);
    });

    test('returns episodeCount=0 for empty novel (no episodes, no body)', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('index html', 200);
        }
        return http.Response('', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: _EmptyNovelSite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      expect(result.episodeCount, 0);
      expect(result.skippedCount, 0);
      expect(result.title, '空の小説');
    });

    test('reports progress 1/1 for short story download', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('index html', 200, headers: {
            'last-modified': 'Thu, 01 Jan 2025 00:00:00 GMT',
          });
        }
        return http.Response('', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final progressCalls = <(int, int, int)>[];

      await service.downloadNovel(
        site: _ShortStorySite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        onProgress: (current, total, skipped) {
          progressCalls.add((current, total, skipped));
        },
      );

      expect(progressCalls, hasLength(1));
      expect(progressCalls[0], (1, 1, 0));
    });
  });

  group('Multi-page download', () {
    test('fetches all pages and merges episodes with continuous numbering (2 pages)', () async {
      final getRequests = <String>[];

      final mockClient = MockClient((request) async {
        getRequests.add(request.url.toString());
        return http.Response('episode content', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: _MultiPageSite(totalPages: 2, episodesPerPage: 3),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      // 2 pages * 3 episodes = 6 total episodes
      expect(result.episodeCount, 6);

      // Verify files have continuous numbering
      final dir = Directory('${tempDir.path}/test_novel1');
      final files = dir.listSync().whereType<File>().toList();
      files.sort((a, b) => a.path.compareTo(b.path));
      expect(files.length, 6);

      // Check that file names use continuous numbering (1-6)
      expect(files[0].path, contains('1_'));
      expect(files[5].path, contains('6_'));
    });

    test('fetches all pages and merges episodes with continuous numbering (3 pages)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('episode content', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final result = await service.downloadNovel(
        site: _MultiPageSite(totalPages: 3, episodesPerPage: 2),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      // 3 pages * 2 episodes = 6 total episodes
      expect(result.episodeCount, 6);

      final dir = Directory('${tempDir.path}/test_novel1');
      final files = dir.listSync().whereType<File>().toList();
      expect(files.length, 6);
    });

    test('enforces maximum page limit (100 pages)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('episode content', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      // _InfinitePageSite always returns a nextPageUrl
      final result = await service.downloadNovel(
        site: _InfinitePageSite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
      );

      // Should stop at 100 pages * 1 episode per page = 100 episodes
      expect(result.episodeCount, 100);
    });

    test('normalizes URL with page parameter and downloads all pages', () async {
      final getRequests = <String>[];

      final mockClient = MockClient((request) async {
        getRequests.add(request.url.toString());
        return http.Response('episode content', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      // Use a site that supports normalizeUrl
      final site = _MultiPageSite(totalPages: 2, episodesPerPage: 2);

      final result = await service.downloadNovel(
        site: site,
        url: Uri.parse('https://example.com/index?p=2'),
        outputPath: tempDir.path,
      );

      // Should still get all pages (4 episodes total)
      expect(result.episodeCount, 4);

      // First request should be to the base URL (normalized, no ?p=)
      // But since _MultiPageSite doesn't implement normalizeUrl on the interface,
      // the DownloadService needs to handle this via site-specific normalizeUrl
      // For now, verify all episodes are downloaded
      final dir = Directory('${tempDir.path}/test_novel1');
      final files = dir.listSync().whereType<File>().toList();
      expect(files.length, 4);
    });

    test('reports progress with total episodes across all pages', () async {
      final mockClient = MockClient((request) async {
        return http.Response('episode content', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final progressCalls = <(int, int, int)>[];

      await service.downloadNovel(
        site: _MultiPageSite(totalPages: 2, episodesPerPage: 2),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        onProgress: (current, total, skipped) {
          progressCalls.add((current, total, skipped));
        },
      );

      // 4 total episodes across 2 pages
      expect(progressCalls, hasLength(4));
      expect(progressCalls[0], (1, 4, 0));
      expect(progressCalls[1], (2, 4, 0));
      expect(progressCalls[2], (3, 4, 0));
      expect(progressCalls[3], (4, 4, 0));
    });
  });
}
