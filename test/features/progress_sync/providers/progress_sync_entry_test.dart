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
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

const _novelDir = '/library/narou_a';

NovelMetadata _novel(String folderName) => NovelMetadata(
  siteType: 'narou',
  novelId: folderName,
  title: folderName,
  url: 'https://example.com/$folderName',
  folderName: folderName,
  episodeCount: 7,
  downloadedAt: DateTime(2026, 1, 1),
);

FileEntry _file(String name) => FileEntry(name: name, path: '$_novelDir/$name');

SyncProgressRecord _record(
  int episode, {
  required DateTime readAt,
  int offset = 1234,
  String? hash = 'hash',
}) {
  return SyncProgressRecord(
    novelId: 'narou_a',
    episode: episode,
    fileName: '${episode.toString().padLeft(2, '0')}_t.txt',
    bodyOffset: offset,
    bodyHash: hash,
    readAt: readAt,
  );
}

void main() {
  late NovelDatabase novelDatabase;
  late ReadingProgressRepository progress;
  late ProgressSyncRepository sync;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    progress = ReadingProgressRepository(novelDatabase);
    sync = ProgressSyncRepository(novelDatabase);
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  Future<void> receive(SyncProgressRecord record) {
    return sync.replaceRemote(
      selfDeviceId: 'self',
      devices: [
        DeviceProgress(
          deviceId: 'win',
          deviceName: 'Windows (desk)',
          records: [record],
        ),
      ],
    );
  }

  ProviderContainer container({bool syncEnabled = true}) {
    final c = ProviderContainer(
      overrides: [
        libraryPathProvider.overrideWithValue('/library'),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier('/library'),
        ),
        readingProgressRepositoryProvider.overrideWithValue(progress),
        allNovelsProvider.overrideWith((ref) => [_novel('narou_a')]),
        directoryContentsProvider.overrideWith((ref) async {
          final dir = ref.watch(currentDirectoryProvider);
          if (dir != _novelDir) return DirectoryContents.empty();
          return DirectoryContents(
            files: [_file('003_t.txt'), _file('005_t.txt'), _file('007_t.txt')],
            subdirectories: const [],
          );
        }),
        progressSyncEntryProvider.overrideWithValue(
          syncEnabled ? ProgressSyncEntry(sync) : null,
        ),
      ],
    );
    addTearDown(c.dispose);
    c.read(readingProgressAutoOpenListenerProvider);
    return c;
  }

  Future<void> enterNovel(ProviderContainer c) async {
    c.read(currentDirectoryProvider.notifier).setDirectory(_novelDir);
    // The FFI database answers from another isolate, so let real time pass.
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('opens another device\'s progress when this device has none', () async {
    final readAt = DateTime.utc(2026, 10, 1);
    await receive(_record(5, readAt: readAt));
    final c = container();

    await enterNovel(c);

    expect(c.read(selectedFileProvider)?.name, '005_t.txt');
    final local = await progress.findByNovelId('narou_a');
    expect(local!.fileName, '005_t.txt');
    expect(local.bodyOffset, 1234);
    expect(local.bodyHash, 'hash');
    final own = (await sync.findAllOwn())['narou_a']!;
    expect(own.readAt, readAt, reason: 'adopting must keep the origin time');
    expect(own.fileName, '005_t.txt');
    expect(c.read(syncPromptProvider), isNull);
  });

  test('opens at the start when the received record has no hash', () async {
    await receive(_record(5, readAt: DateTime.utc(2026, 10, 1), hash: null));
    final c = container();

    await enterNovel(c);

    expect(c.read(selectedFileProvider)?.name, '005_t.txt');
    expect((await progress.findByNovelId('narou_a'))!.bodyOffset, 0);
  });

  test('opens the local progress first, then asks', () async {
    await progress.upsert(novelId: 'narou_a', fileName: '003_t.txt');
    // The local row was last touched long ago; the remote record is newer
    // than that but older than "now". A comparison made after the entry's own
    // selection (which touches updated_at) would wrongly see it as older.
    await novelDatabase.database.then(
      (db) => db.update('reading_progress', {
        'updated_at': DateTime.utc(2026, 9, 1).toIso8601String(),
      }),
    );
    await receive(_record(5, readAt: DateTime.utc(2026, 10, 1)));
    final c = container();

    await enterNovel(c);

    expect(c.read(selectedFileProvider)?.name, '003_t.txt');
    final prompt = c.read(syncPromptProvider)!;
    expect(prompt.novelId, 'narou_a');
    expect(prompt.fileName, '005_t.txt');
    expect(prompt.remote.deviceName, 'Windows (desk)');
    expect(prompt.remote.record.episode, 5);
    expect(prompt.directory, _novelDir);
  });

  test('marks a newer record at the same position handled', () async {
    await progress.upsert(novelId: 'narou_a', fileName: '005_t.txt');
    await novelDatabase.database.then(
      (db) => db.update('reading_progress', {
        'updated_at': DateTime.utc(2026, 9, 1).toIso8601String(),
        'body_offset': 1200,
      }),
    );
    final readAt = DateTime.utc(2026, 10, 1);
    await receive(_record(5, readAt: readAt));
    final c = container();

    await enterNovel(c);

    expect(c.read(selectedFileProvider)?.name, '005_t.txt');
    expect(c.read(syncPromptProvider), isNull);
    expect(await sync.findHandled('narou_a'), readAt);
  });

  test('without sync, a novel with no progress opens nothing', () async {
    await receive(_record(5, readAt: DateTime.utc(2026, 10, 1)));
    final c = container(syncEnabled: false);

    await enterNovel(c);

    expect(c.read(selectedFileProvider), isNull);
    expect(await progress.findByNovelId('narou_a'), isNull);
  });
}
