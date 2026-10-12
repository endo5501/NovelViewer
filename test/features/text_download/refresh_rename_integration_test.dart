import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_repository.dart';
import 'package:novel_viewer/features/episode_cache/domain/episode_cache.dart';
import 'package:novel_viewer/features/episode_navigation/providers/adjacent_files_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_context/providers/reading_context_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_position_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/db_provider_container.dart';
import '../../helpers/novel_metadata_db_fixture.dart';

/// A site whose index lists [count] episodes, so the test can drive the
/// zero-pad width across a boundary.
class _ListSite extends NovelSite {
  _ListSite(this.count);

  final int count;

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
  NovelIndex parseIndex(String html, Uri baseUrl) => NovelIndex(
    title: 'テスト小説',
    episodes: [
      for (var i = 1; i <= count; i++)
        Episode(
          index: i,
          title: '第$i話',
          url: Uri.parse('https://example.com/$i'),
          updatedAt: '2025/01/01 00:00',
        ),
    ],
  );

  @override
  String parseEpisode(String html) => html;
}

class _Registry extends Fake implements NovelSiteRegistry {
  _Registry(this.site);

  final NovelSite site;

  @override
  NovelSite? findSite(Uri url) => site;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'reading 9_x.txt of a 9-episode novel survives an update to 12',
    () async {
      final libraryDir = Directory.systemTemp.createTempSync('refresh_rename_');
      final novelDir = p.join(libraryDir.path, 'test_novel1');
      Directory(novelDir).createSync();
      final novelDatabase = await seedNovelDatabaseFixture();
      final container = ProviderContainer(
        overrides: [
          novelDatabaseProvider.overrideWithValue(novelDatabase),
          libraryPathProvider.overrideWithValue(libraryDir.path),
          novelSiteRegistryProvider.overrideWithValue(_Registry(_ListSite(12))),
          downloadServiceFactoryProvider.overrideWithValue(
            () => DownloadService(
              client: MockClient(
                (request) async => http.Response('episode body', 200),
              ),
              requestDelay: Duration.zero,
            ),
          ),
        ],
      );
      addTearDown(() async {
        await disposeContainerWithDatabases(container);
        await novelDatabase.close();
        libraryDir.deleteSync(recursive: true);
      });

      // Nine episodes downloaded earlier, at pad width 1.
      final db = await novelDatabase.database;
      await db.insert('novels', {
        'site_type': 'test',
        'novel_id': 'novel1',
        'title': 'テスト小説',
        'url': 'https://example.com/index',
        'folder_name': 'test_novel1',
        'episode_count': 9,
        'downloaded_at': DateTime(2026).toIso8601String(),
      });
      final cache = EpisodeCacheRepository(
        container.read(episodeCacheDatabaseProvider(folderDbKey(novelDir))),
      );
      for (var i = 1; i <= 9; i++) {
        await cache.upsert(
          EpisodeCache(
            url: 'https://example.com/$i',
            episodeIndex: i,
            title: '第$i話',
            lastModified: '2025/01/01 00:00',
            downloadedAt: DateTime.utc(2025),
          ),
        );
        File(
          p.join(novelDir, formatEpisodeFileName(i, '第$i話', 9)),
        ).writeAsStringSync('本文 $i');
      }

      container.read(readingProgressAutoSaveListenerProvider);
      container.read(readingProgressAutoOpenListenerProvider);
      final writer = container.read(readingPositionWriterProvider);
      final progress = container.read(readingProgressRepositoryProvider);

      // The reader is in the middle of episode 9.
      container.read(currentDirectoryProvider.notifier).setDirectory(novelDir);
      container
          .read(selectedFileProvider.notifier)
          .selectFile(
            FileEntry(name: '9_第9話.txt', path: p.join(novelDir, '9_第9話.txt')),
          );
      await pumpEventQueue();
      await writer.flush();
      await progress.savePosition(
        novelId: 'test_novel1',
        fileName: '9_第9話.txt',
        bodyOffset: 1200,
        bodyHash: 'hash',
      );

      await container
          .read(downloadProvider.notifier)
          .refreshNovel('test_novel1', parentPath: libraryDir.path);
      expect(container.read(downloadProvider).status, DownloadStatus.completed);
      // What the progress dialog does when it is closed.
      container.invalidate(allNovelsProvider);
      invalidateEpisodeListings(container.invalidate);
      await pumpEventQueue();
      await writer.flush();

      // Paging continues past the renamed episode.
      expect(container.read(selectedFileProvider)!.name, '09_第9話.txt');
      await container.read(readingEpisodesProvider.future);
      expect(container.read(adjacentFilesProvider).next?.name, '10_第10話.txt');

      // Leaving the novel and coming back reopens episode 9 where it was left.
      container.read(selectedFileProvider.notifier).clear();
      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory(libraryDir.path);
      container.read(currentDirectoryProvider.notifier).setDirectory(novelDir);
      for (
        var i = 0;
        i < 50 && container.read(selectedFileProvider) == null;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(container.read(selectedFileProvider)?.name, '09_第9話.txt');
      await writer.flush();
      final saved = await progress.findByNovelId('test_novel1');
      expect(saved!.fileName, '09_第9話.txt');
      expect(saved.bodyOffset, 1200);
    },
  );
}
