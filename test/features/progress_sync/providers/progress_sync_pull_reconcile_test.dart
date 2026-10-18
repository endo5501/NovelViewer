import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/progress_sync/data/progress_sync_repository.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_progress_record.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_entry_providers.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_providers.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

const _dir = '/library/narou_a';

FileEntry _file(String name) => FileEntry(name: name, path: '$_dir/$name');

NovelMetadata _novel() => NovelMetadata(
  siteType: 'narou',
  novelId: 'narou_a',
  title: 'a',
  url: 'https://example.com/a',
  folderName: 'narou_a',
  episodeCount: 7,
  downloadedAt: DateTime(2026, 1, 1),
);

Future<void> _settle() async {
  // The FFI database answers from another isolate, so let real time pass.
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late NovelDatabase novelDatabase;
  late ReadingProgressRepository progress;
  late ProgressSyncRepository sync;
  late StreamController<void> pulls;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    progress = ReadingProgressRepository(novelDatabase);
    sync = ProgressSyncRepository(novelDatabase);
    pulls = StreamController<void>.broadcast();
    addTearDown(pulls.close);
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  Future<void> receive(int episode, DateTime readAt) {
    return sync.replaceRemote(
      selfDeviceId: 'self',
      devices: [
        DeviceProgress(
          deviceId: 'win',
          deviceName: 'Windows',
          records: [
            SyncProgressRecord(
              novelId: 'narou_a',
              episode: episode,
              fileName: '${episode.toString().padLeft(3, '0')}_t.txt',
              bodyOffset: 500,
              bodyHash: 'hash',
              readAt: readAt,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> oldLocal(String fileName) async {
    await progress.upsert(novelId: 'narou_a', fileName: fileName);
    await novelDatabase.database.then(
      (db) => db.update('reading_progress', {
        'updated_at': DateTime.utc(2026, 9, 1).toIso8601String(),
      }),
    );
  }

  ProviderContainer container({String initialDirectory = '/library'}) {
    final c = ProviderContainer(
      overrides: [
        libraryPathProvider.overrideWithValue('/library'),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier(initialDirectory),
        ),
        readingProgressRepositoryProvider.overrideWithValue(progress),
        allNovelsProvider.overrideWith((ref) => [_novel()]),
        directoryContentsProvider.overrideWith((ref) async {
          if (ref.watch(currentDirectoryProvider) != _dir) {
            return DirectoryContents.empty();
          }
          return DirectoryContents(
            files: [_file('003_t.txt'), _file('005_t.txt')],
            subdirectories: const [],
          );
        }),
        progressSyncEntryProvider.overrideWithValue(
          ProgressSyncEntry(sync, syncableNovelIds: () async => {'narou_a'}),
        ),
        progressSyncPulledProvider.overrideWithValue(pulls.stream),
      ],
    );
    addTearDown(c.dispose);
    c.read(readingProgressAutoOpenListenerProvider);
    c.read(progressSyncPullReconcileProvider);
    return c;
  }

  test('asks after a pull without changing the open file', () async {
    await oldLocal('003_t.txt');
    final c = container(initialDirectory: _dir);
    c.read(selectedFileProvider.notifier).selectFile(_file('003_t.txt'));

    await receive(5, DateTime.utc(2026, 10, 1));
    pulls.add(null);
    await _settle();

    expect(c.read(selectedFileProvider)!.name, '003_t.txt');
    final prompt = c.read(syncPromptProvider)!;
    expect(prompt.fileName, '005_t.txt');
  });

  test(
    'opens the received progress after a pull when there was none',
    () async {
      final c = container(initialDirectory: _dir);

      await receive(5, DateTime.utc(2026, 10, 1));
      pulls.add(null);
      await _settle();

      expect(c.read(selectedFileProvider)!.name, '005_t.txt');
      expect((await progress.findByNovelId('narou_a'))!.bodyOffset, 500);
    },
  );

  test('does nothing after a pull outside any novel', () async {
    final c = container();

    await receive(5, DateTime.utc(2026, 10, 1));
    pulls.add(null);
    await _settle();

    expect(c.read(selectedFileProvider), isNull);
    expect(c.read(syncPromptProvider), isNull);
  });

  test('a startup restore after the pull still asks', () async {
    // The pull has already finished when the startup restore puts the reader
    // back in the novel: it sets the folder and the file at once.
    await oldLocal('003_t.txt');
    await receive(5, DateTime.utc(2026, 10, 1));
    final c = container();

    c.read(currentDirectoryProvider.notifier).setDirectory(_dir);
    c.read(selectedFileProvider.notifier).selectFile(_file('003_t.txt'));
    await _settle();

    expect(c.read(selectedFileProvider)!.name, '003_t.txt');
    expect(c.read(syncPromptProvider)?.fileName, '005_t.txt');
  });
}
