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
  @override
  String get siteType => 'test';

  @override
  bool canHandle(Uri url) => true;

  @override
  String extractNovelId(Uri url) => 'novel1';

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) {
    return NovelIndex(
      title: 'テスト小説',
      episodes: [
        Episode(
          index: 1,
          title: '第一話',
          url: Uri.parse('https://example.com/1'),
        ),
        Episode(
          index: 2,
          title: '第二話',
          url: Uri.parse('https://example.com/2'),
        ),
        Episode(
          index: 3,
          title: '第三話',
          url: Uri.parse('https://example.com/3'),
        ),
      ],
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
      final requestedUrls = <String>[];

      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        if (request.method == 'GET') {
          if (request.url.toString() == 'https://example.com/index') {
            return http.Response('index html', 200);
          }
          return http.Response('episode content', 200, headers: {
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
        site: _FakeSite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      expect(result.episodeCount, 3);
      expect(result.skippedCount, 0);

      // All 3 episodes should have been fetched via GET
      final getRequests = requestedUrls.where((u) => u != 'https://example.com/index').toList();
      expect(getRequests, hasLength(3));
    });

    test('skips cached episodes when Last-Modified has not changed', () async {
      // Pre-populate cache and create local files for all 3 episodes
      final titles = ['第一話', '第二話', '第三話'];
      for (var i = 1; i <= 3; i++) {
        final title = titles[i - 1];
        await cacheRepo.upsert(EpisodeCache(
          url: 'https://example.com/$i',
          episodeIndex: i,
          title: title,
          lastModified: 'Thu, 01 Jan 2025 00:00:00 GMT',
          downloadedAt: DateTime.utc(2025, 1, 1),
        ));
        final fileName = formatEpisodeFileName(i, title, 3);
        File('${novelDir.path}/$fileName').writeAsStringSync('cached content');
      }

      final headRequests = <String>[];
      final getRequests = <String>[];

      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          headRequests.add(request.url.toString());
          return http.Response('', 200, headers: {
            'last-modified': 'Thu, 01 Jan 2025 00:00:00 GMT',
          });
        }
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
      expect(headRequests, hasLength(3));
      // No episode GET requests (only index page)
      expect(getRequests, equals(['https://example.com/index']));
    });

    test('downloads episode when Last-Modified is newer', () async {
      // Pre-populate cache with old Last-Modified and create local files
      await cacheRepo.upsert(EpisodeCache(
        url: 'https://example.com/1',
        episodeIndex: 1,
        title: '第一話',
        lastModified: 'Thu, 01 Jan 2025 00:00:00 GMT',
        downloadedAt: DateTime.utc(2025, 1, 1),
      ));
      File('${novelDir.path}/${formatEpisodeFileName(1, '第一話', 3)}')
          .writeAsStringSync('old content');
      await cacheRepo.upsert(EpisodeCache(
        url: 'https://example.com/2',
        episodeIndex: 2,
        title: '第二話',
        lastModified: 'Thu, 01 Jan 2025 00:00:00 GMT',
        downloadedAt: DateTime.utc(2025, 1, 1),
      ));
      File('${novelDir.path}/${formatEpisodeFileName(2, '第二話', 3)}')
          .writeAsStringSync('old content');

      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          if (request.url.toString() == 'https://example.com/1') {
            // Updated
            return http.Response('', 200, headers: {
              'last-modified': 'Fri, 01 Feb 2025 00:00:00 GMT',
            });
          }
          // Not updated
          return http.Response('', 200, headers: {
            'last-modified': 'Thu, 01 Jan 2025 00:00:00 GMT',
          });
        }
        if (request.method == 'GET') {
          if (request.url.toString() == 'https://example.com/index') {
            return http.Response('index html', 200);
          }
          return http.Response('updated content', 200, headers: {
            'last-modified': 'Fri, 01 Feb 2025 00:00:00 GMT',
          });
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

      // Episode 1 updated, Episode 2 skipped, Episode 3 new
      expect(result.episodeCount, 3);
      expect(result.skippedCount, 1);
    });

    test('skips cached episode when server does not return Last-Modified', () async {
      await cacheRepo.upsert(EpisodeCache(
        url: 'https://example.com/1',
        episodeIndex: 1,
        title: '第一話',
        lastModified: 'Thu, 01 Jan 2025 00:00:00 GMT',
        downloadedAt: DateTime.utc(2025, 1, 1),
      ));
      File('${novelDir.path}/${formatEpisodeFileName(1, '第一話', 3)}')
          .writeAsStringSync('cached content');

      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          // No Last-Modified header
          return http.Response('', 200, headers: {
            'content-type': 'text/html',
          });
        }
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
        episodeCacheRepository: cacheRepo,
      );

      // Episode 1 skipped (no Last-Modified), Episodes 2&3 new
      expect(result.skippedCount, 1);
      expect(result.episodeCount, 3);
    });

    test('skips cached episode when HEAD request fails', () async {
      await cacheRepo.upsert(EpisodeCache(
        url: 'https://example.com/1',
        episodeIndex: 1,
        title: '第一話',
        lastModified: 'Thu, 01 Jan 2025 00:00:00 GMT',
        downloadedAt: DateTime.utc(2025, 1, 1),
      ));
      File('${novelDir.path}/${formatEpisodeFileName(1, '第一話', 3)}')
          .writeAsStringSync('cached content');

      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          return http.Response('', 500);
        }
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
        episodeCacheRepository: cacheRepo,
      );

      // Episode 1 skipped (HEAD failed), Episodes 2&3 new
      expect(result.skippedCount, 1);
      expect(result.episodeCount, 3);
    });

    test('saves cache entry after successful download', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          if (request.url.toString() == 'https://example.com/index') {
            return http.Response('index html', 200);
          }
          return http.Response('episode content', 200, headers: {
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
        site: _FakeSite(),
        url: Uri.parse('https://example.com/index'),
        outputPath: tempDir.path,
        episodeCacheRepository: cacheRepo,
      );

      final cached = await cacheRepo.getAllAsMap();
      expect(cached, hasLength(3));
      expect(cached['https://example.com/1']!.title, '第一話');
      expect(cached['https://example.com/1']!.lastModified, 'Thu, 01 Jan 2025 00:00:00 GMT');
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
          lastModified: 'Thu, 01 Jan 2025 00:00:00 GMT',
          downloadedAt: DateTime.utc(2025, 1, 1),
        ));
        final fileName = formatEpisodeFileName(i, title, 3);
        File('${novelDir.path}/$fileName').writeAsStringSync('cached content');
      }

      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          return http.Response('', 200, headers: {
            'last-modified': 'Thu, 01 Jan 2025 00:00:00 GMT',
          });
        }
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
  });
}
