import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/progress_sync/data/progress_sync_repository.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_progress_record.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_entry_providers.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_prompt_actions.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_position_writer.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_position_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

const _dir = '/library/narou_a';
final _readAt = DateTime.utc(2026, 10, 1);

FileEntry _file(String name) => FileEntry(name: name, path: '$_dir/$name');

SyncPromptRequest _request(String fileName, {int offset = 4321}) {
  return SyncPromptRequest(
    novelId: 'narou_a',
    directory: _dir,
    fileName: fileName,
    remote: RemoteProgress(
      deviceId: 'win',
      deviceName: 'Windows',
      record: SyncProgressRecord(
        novelId: 'narou_a',
        episode: int.parse(fileName.split('_')[0]),
        fileName: fileName,
        bodyOffset: offset,
        bodyHash: 'hash',
        readAt: _readAt,
      ),
    ),
  );
}

void main() {
  late NovelDatabase novelDatabase;
  late ReadingProgressRepository progress;
  late ProgressSyncRepository sync;
  late List<String> calls;
  late ProviderContainer container;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    progress = ReadingProgressRepository(novelDatabase);
    sync = ProgressSyncRepository(novelDatabase);
    calls = [];
    await progress.upsert(novelId: 'narou_a', fileName: '003_t.txt');
    container = ProviderContainer(
      overrides: [
        libraryPathProvider.overrideWithValue('/library'),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier(_dir),
        ),
        readingProgressRepositoryProvider.overrideWithValue(progress),
        progressSyncEntryProvider.overrideWithValue(
          ProgressSyncEntry(sync, syncableNovelIds: () async => {'narou_a'}),
        ),
        readingPositionWriterProvider.overrideWith((ref) {
          final writer = _RecordingWriter(calls);
          ref.onDispose(writer.dispose);
          return writer;
        }),
        directoryContentsProvider.overrideWith(
          (ref) async => DirectoryContents(
            files: [_file('003_t.txt'), _file('005_t.txt')],
            subdirectories: const [],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(selectedFileProvider.notifier)
        .selectFile(_file('003_t.txt'));
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  SyncPromptActions actions() => container.read(syncPromptActionsProvider);

  test('moving opens the other device\'s episode at its position', () async {
    await actions().answer(_request('005_t.txt'), move: true);

    expect(container.read(selectedFileProvider)!.name, '005_t.txt');
    final local = await progress.findByNovelId('narou_a');
    expect(local!.fileName, '005_t.txt');
    expect(local.bodyOffset, 4321);
    expect((await sync.findAllOwn())['narou_a']!.readAt, _readAt);
    expect(await sync.findHandled('narou_a'), _readAt);
    expect(calls.first, 'flush');
  });

  test('moving within the open episode asks the viewer to restore', () async {
    container
        .read(selectedFileProvider.notifier)
        .selectFile(_file('005_t.txt'));
    await progress.upsert(novelId: 'narou_a', fileName: '005_t.txt');
    final before = container.read(readingPositionRestoreRequestProvider);

    await actions().answer(_request('005_t.txt', offset: 9999), move: true);

    expect(container.read(selectedFileProvider)!.name, '005_t.txt');
    expect(container.read(readingPositionRestoreRequestProvider), before + 1);
    expect((await progress.findByNovelId('narou_a'))!.bodyOffset, 9999);
  });

  test('staying changes nothing but answers the record', () async {
    await actions().answer(_request('005_t.txt'), move: false);

    expect(container.read(selectedFileProvider)!.name, '003_t.txt');
    expect((await progress.findByNovelId('narou_a'))!.fileName, '003_t.txt');
    expect(await sync.findHandled('narou_a'), _readAt);
  });
}

/// A writer that saves nowhere and records each flush.
class _RecordingWriter extends ReadingPositionWriter {
  final List<String> _calls;

  _RecordingWriter(this._calls) : super(save: (_) async {});

  @override
  Future<void> flush() {
    _calls.add('flush');
    return super.flush();
  }
}
