import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/bookmark/data/bookmark_repository.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_position_writer.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_position_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/text_download/providers/episode_rename_propagation.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:novel_viewer/features/tts/domain/tts_episode_status.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';
import 'package:novel_viewer/shared/database/novel_data_database_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/db_provider_container.dart';
import '../../helpers/novel_metadata_db_fixture.dart';

void main() {
  late Directory libraryDir;
  late String novelDir;
  late NovelDatabase novelDatabase;
  late ProviderContainer container;

  const novelId = 'narou_n1';
  const renames = {'9_x.txt': '09_x.txt'};

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    libraryDir = Directory.systemTemp.createTempSync('rename_propagation_');
    novelDir = p.join(libraryDir.path, novelId);
    Directory(novelDir).createSync();
    // On disk the download has already renamed the file.
    File(p.join(novelDir, '09_x.txt')).writeAsStringSync('本文');
    File(p.join(novelDir, '10_y.txt')).writeAsStringSync('新しい話');

    novelDatabase = await seedNovelDatabaseFixture();
    final db = await novelDatabase.database;
    for (final folder in [novelId, 'kakuyomu_2']) {
      await db.insert('novels', {
        'site_type': 'narou',
        'novel_id': folder,
        'title': 'Title $folder',
        'url': 'https://example.com/$folder',
        'folder_name': folder,
        'episode_count': 12,
        'downloaded_at': DateTime.now().toIso8601String(),
      });
    }

    container = ProviderContainer(
      overrides: [
        novelDatabaseProvider.overrideWithValue(novelDatabase),
        libraryPathProvider.overrideWithValue(libraryDir.path),
      ],
    );
    addTearDown(() async {
      await disposeContainerWithDatabases(container);
      await novelDatabase.close();
      libraryDir.deleteSync(recursive: true);
    });
  });

  Future<void> propagate([Map<String, String> map = renames]) => container
      .read(episodeRenamePropagatorProvider)
      .propagate(novelFolderPath: novelDir, renames: map);

  Future<Database> novelDataDb() =>
      container.read(novelDataDatabaseProvider(folderDbKey(novelDir))).database;

  TtsAudioRepository ttsRepo() => TtsAudioRepository(
    container.read(ttsAudioDatabaseProvider(folderDbKey(novelDir))),
  );

  FileEntry entry(String dir, String name) =>
      FileEntry(name: name, path: p.join(dir, name));

  test('rekeys every store keyed by the episode file name', () async {
    final progress = container.read(readingProgressRepositoryProvider);
    await progress.upsert(novelId: novelId, fileName: '9_x.txt');
    final data = await novelDataDb();
    await BookmarkRepository(data).add(fileName: '9_x.txt', lineNumber: 3);
    await FactCacheRepository(data).upsert(
      word: 'アリス',
      fileName: '9_x.txt',
      facts: 'f',
      contentHash: 'h',
      promptVersion: 1,
      modelId: 'm',
    );
    await LlmSummaryRepository(data).saveSnapshot(
      word: 'アリス',
      coveredUpToEpisode: 9,
      summary: 's',
      sourceFile: '9_x.txt',
    );
    await ttsRepo().createEpisode(
      fileName: '9_x.txt',
      sampleRate: 24000,
      status: TtsEpisodeStatus.completed,
    );

    await propagate();

    expect((await progress.findByNovelId(novelId))!.fileName, '09_x.txt');
    expect(
      (await BookmarkRepository(data).findAll()).single.fileName,
      '09_x.txt',
    );
    expect(
      (await FactCacheRepository(
        data,
      ).findForWord(word: 'アリス')).single.fileName,
      '09_x.txt',
    );
    expect(
      (await LlmSummaryRepository(
        data,
      ).findSnapshotsForWord(word: 'アリス')).single.sourceFile,
      '09_x.txt',
    );
    expect(await ttsRepo().findEpisodeByFileName('09_x.txt'), isNotNull);
    expect(await ttsRepo().findEpisodeByFileName('9_x.txt'), isNull);
  });

  test("leaves another novel's reading progress alone", () async {
    final progress = container.read(readingProgressRepositoryProvider);
    await progress.upsert(novelId: 'kakuyomu_2', fileName: '9_x.txt');

    await propagate();

    expect((await progress.findByNovelId('kakuyomu_2'))!.fileName, '9_x.txt');
  });

  test('a pending body position is flushed before the rekey', () async {
    final progress = container.read(readingProgressRepositoryProvider);
    await progress.upsert(novelId: novelId, fileName: '9_x.txt');
    // Observed under the old name and not yet written: written after the
    // rekey, it would match no row and be lost.
    container
        .read(readingPositionWriterProvider)
        .observe(const PositionSnapshot(novelId, '9_x.txt', 1200, 'hash'));

    await propagate();

    final saved = await progress.findByNovelId(novelId);
    expect(saved!.fileName, '09_x.txt');
    expect(saved.bodyOffset, 1200);
    expect(saved.bodyHash, 'hash');
  });

  test('rebases the open episode without counting as opening a file', () async {
    container
        .read(selectedFileProvider.notifier)
        .rebase(entry(novelDir, '9_x.txt'));
    final opens = container.read(fileOpenRequestProvider);

    await propagate();

    final selected = container.read(selectedFileProvider)!;
    expect(selected.name, '09_x.txt');
    expect(p.equals(selected.path, p.join(novelDir, '09_x.txt')), isTrue);
    expect(container.read(fileOpenRequestProvider), opens);
  });

  test(
    'the auto-saved selection keeps the body position after the rebase',
    () async {
      container.read(readingProgressAutoSaveListenerProvider);
      final progress = container.read(readingProgressRepositoryProvider);
      await progress.upsert(novelId: novelId, fileName: '9_x.txt');
      await progress.savePosition(
        novelId: novelId,
        fileName: '9_x.txt',
        bodyOffset: 800,
        bodyHash: 'hash',
      );
      container
          .read(selectedFileProvider.notifier)
          .rebase(entry(novelDir, '9_x.txt'));
      // Let the listener's save of that selection land first.
      await container.read(readingPositionWriterProvider).flush();
      await Future<void>.delayed(Duration.zero);
      await container.read(readingPositionWriterProvider).flush();

      await propagate();
      // The rebase makes the auto-save listener upsert the new name.
      await Future<void>.delayed(Duration.zero);
      await container.read(readingPositionWriterProvider).flush();

      final saved = await progress.findByNovelId(novelId);
      expect(saved!.fileName, '09_x.txt');
      expect(saved.bodyOffset, 800);
    },
  );

  test('leaves a selection in another folder alone', () async {
    final otherDir = p.join(libraryDir.path, 'kakuyomu_2');
    container
        .read(selectedFileProvider.notifier)
        .rebase(entry(otherDir, '9_x.txt'));

    await propagate();

    expect(
      container.read(selectedFileProvider)!.path,
      p.join(otherDir, '9_x.txt'),
    );
  });

  test('leaves a selection that was not renamed alone', () async {
    container
        .read(selectedFileProvider.notifier)
        .rebase(entry(novelDir, '10_y.txt'));

    await propagate();

    expect(container.read(selectedFileProvider)!.name, '10_y.txt');
  });

  test('creates no per-folder database the novel never had', () async {
    await propagate();

    expect(File(p.join(novelDir, 'novel_data.db')).existsSync(), isFalse);
    expect(File(p.join(novelDir, 'tts_audio.db')).existsSync(), isFalse);
  });

  test('one failing store is logged and does not stop the others', () async {
    final progress = container.read(readingProgressRepositoryProvider);
    await progress.upsert(novelId: novelId, fileName: '9_x.txt');
    final data = await novelDataDb();
    await data.execute('DROP TABLE bookmarks');
    await ttsRepo().createEpisode(
      fileName: '9_x.txt',
      sampleRate: 24000,
      status: TtsEpisodeStatus.completed,
    );
    final warnings = <LogRecord>[];
    final sub = Logger.root.onRecord
        .where((r) => r.level == Level.WARNING)
        .listen(warnings.add);
    addTearDown(sub.cancel);

    await propagate();

    expect(warnings, isNotEmpty);
    expect((await progress.findByNovelId(novelId))!.fileName, '09_x.txt');
    expect(await ttsRepo().findEpisodeByFileName('09_x.txt'), isNotNull);
  });
}
