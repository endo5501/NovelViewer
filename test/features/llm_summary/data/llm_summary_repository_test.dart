import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late LlmSummaryRepository repository;

  Future<void> createV5Schema(Database db) async {
    await db.execute('''
      CREATE TABLE word_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_name TEXT NOT NULL,
        word TEXT NOT NULL,
        covered_up_to_episode INTEGER NOT NULL,
        summary TEXT NOT NULL,
        source_file TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_word_summaries_unique
      ON word_summaries(folder_name, word, covered_up_to_episode)
    ''');
  }

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => createV5Schema(db),
      ),
    );
    repository = LlmSummaryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('LlmSummaryRepository', () {
    group('saveSnapshot', () {
      test('inserts a new snapshot row', () async {
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: 'アリスは少女。',
          sourceFile: '030_chapter.txt',
        );

        final snapshots = await repository.findSnapshotsForWord(
          folderName: 'my_novel',
          word: 'アリス',
        );

        expect(snapshots, hasLength(1));
        expect(snapshots.first.coveredUpToEpisode, 30);
        expect(snapshots.first.summary, 'アリスは少女。');
        expect(snapshots.first.sourceFile, '030_chapter.txt');
      });

      test('upserts when (folder, word, episode) collides', () async {
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: '初回',
          sourceFile: '030_chapter.txt',
        );
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: '上書き',
          sourceFile: '030_chapter.txt',
        );

        final snapshots = await repository.findSnapshotsForWord(
          folderName: 'my_novel',
          word: 'アリス',
        );

        expect(snapshots, hasLength(1),
            reason: 'colliding PK SHALL upsert, not duplicate');
        expect(snapshots.first.summary, '上書き');
      });

      test('different episodes coexist for the same word', () async {
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: '30話時点',
          sourceFile: '030_chapter.txt',
        );
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 120,
          summary: '全話時点',
          sourceFile: '120_chapter.txt',
        );

        final snapshots = await repository.findSnapshotsForWord(
          folderName: 'my_novel',
          word: 'アリス',
        );

        expect(snapshots, hasLength(2));
        expect(
            snapshots.map((s) => s.coveredUpToEpisode).toList(), [30, 120]);
      });

      test('rejects 1-character word', () async {
        await expectLater(
          repository.saveSnapshot(
            folderName: 'my_novel',
            word: 'の',
            coveredUpToEpisode: 1,
            summary: '要約',
          ),
          throwsArgumentError,
        );
      });

      test('accepts 2-character word', () async {
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: '聖印',
          coveredUpToEpisode: 5,
          summary: '騎士の証',
        );
        final snapshots = await repository.findSnapshotsForWord(
          folderName: 'my_novel',
          word: '聖印',
        );
        expect(snapshots, hasLength(1));
      });

      test('allows null source_file', () async {
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'レガシー扱い',
          sourceFile: null,
        );
        final snapshots = await repository.findSnapshotsForWord(
          folderName: 'my_novel',
          word: 'アリス',
        );
        expect(snapshots.first.sourceFile, isNull);
      });
    });

    group('findSnapshotsForWord', () {
      test('returns snapshots sorted by coveredUpToEpisode ascending', () async {
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 60,
          summary: 'b',
          sourceFile: '060.txt',
        );
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'a',
          sourceFile: '010.txt',
        );
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: 'm',
          sourceFile: '030.txt',
        );

        final snapshots = await repository.findSnapshotsForWord(
          folderName: 'my_novel',
          word: 'アリス',
        );

        expect(
            snapshots.map((s) => s.coveredUpToEpisode).toList(), [10, 30, 60]);
      });

      test('returns empty list when no snapshots exist', () async {
        final snapshots = await repository.findSnapshotsForWord(
          folderName: 'my_novel',
          word: '未知',
        );
        expect(snapshots, isEmpty);
      });

      test('only returns rows for the requested (folder, word)', () async {
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'a',
          sourceFile: '010.txt',
        );
        await repository.saveSnapshot(
          folderName: 'other_novel',
          word: 'アリス',
          coveredUpToEpisode: 20,
          summary: 'other',
          sourceFile: '020.txt',
        );
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'ボブ',
          coveredUpToEpisode: 30,
          summary: 'bob',
          sourceFile: '030.txt',
        );

        final snapshots = await repository.findSnapshotsForWord(
          folderName: 'my_novel',
          word: 'アリス',
        );

        expect(snapshots, hasLength(1));
        expect(snapshots.first.folderName, 'my_novel');
        expect(snapshots.first.word, 'アリス');
      });
    });

    group('deleteAllForWord', () {
      test('removes every snapshot for the (folder, word)', () async {
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'a',
          sourceFile: '010.txt',
        );
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: 'b',
          sourceFile: '030.txt',
        );

        await repository.deleteAllForWord(
            folderName: 'my_novel', word: 'アリス');

        final snapshots = await repository.findSnapshotsForWord(
          folderName: 'my_novel',
          word: 'アリス',
        );
        expect(snapshots, isEmpty);
      });

      test('leaves other words and folders untouched', () async {
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'a',
          sourceFile: '010.txt',
        );
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'ボブ',
          coveredUpToEpisode: 10,
          summary: 'b',
          sourceFile: '010.txt',
        );
        await repository.saveSnapshot(
          folderName: 'other_novel',
          word: 'アリス',
          coveredUpToEpisode: 20,
          summary: 'c',
          sourceFile: '020.txt',
        );

        await repository.deleteAllForWord(
            folderName: 'my_novel', word: 'アリス');

        final bob = await repository.findSnapshotsForWord(
            folderName: 'my_novel', word: 'ボブ');
        final otherAlice = await repository.findSnapshotsForWord(
            folderName: 'other_novel', word: 'アリス');
        expect(bob, hasLength(1));
        expect(otherAlice, hasLength(1));
      });
    });

    group('deleteByFolderName', () {
      test('removes every snapshot row for the folder', () async {
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'a',
          sourceFile: '010.txt',
        );
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'ボブ',
          coveredUpToEpisode: 10,
          summary: 'b',
          sourceFile: '010.txt',
        );
        await repository.saveSnapshot(
          folderName: 'other_novel',
          word: 'キャラ',
          coveredUpToEpisode: 20,
          summary: 'c',
          sourceFile: '020.txt',
        );

        await repository.deleteByFolderName('my_novel');

        final survived = await repository.findAllByFolder('my_novel');
        expect(survived, isEmpty);
        final other = await repository.findAllByFolder('other_novel');
        expect(other, hasLength(1));
      });
    });

    group('findAllByFolder', () {
      test('returns rows ordered by (word, coveredUpToEpisode) ascending',
          () async {
        // Insert out of order; result should be deterministic.
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'ボブ',
          coveredUpToEpisode: 5,
          summary: 'bob5',
          sourceFile: '005.txt',
        );
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: 'a30',
          sourceFile: '030.txt',
        );
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'a10',
          sourceFile: '010.txt',
        );
        await repository.saveSnapshot(
          folderName: 'my_novel',
          word: 'ボブ',
          coveredUpToEpisode: 50,
          summary: 'bob50',
          sourceFile: '050.txt',
        );

        final rows = await repository.findAllByFolder('my_novel');

        expect(
          rows.map((r) => '${r.word}/${r.coveredUpToEpisode}').toList(),
          ['アリス/10', 'アリス/30', 'ボブ/5', 'ボブ/50'],
        );
      });

      test('returns empty list when folder has no rows', () async {
        final rows = await repository.findAllByFolder('empty_novel');
        expect(rows, isEmpty);
      });
    });

    test('legacy null source_file reads back as null', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': 'アリス',
        'covered_up_to_episode': 10,
        'summary': '古いネタバレ要約',
        'source_file': null,
        'created_at': now,
        'updated_at': now,
      });

      final snapshots = await repository.findSnapshotsForWord(
        folderName: 'my_novel',
        word: 'アリス',
      );

      expect(snapshots, hasLength(1));
      expect(snapshots.first.sourceFile, isNull);
      expect(snapshots.first.summary, '古いネタバレ要約');
    });

    // Construct WordSummary to ensure the test references the symbol cleanly.
    test('WordSummary symbol is wired', () {
      final ws = WordSummary(
        folderName: 'f',
        word: 'wd',
        coveredUpToEpisode: 1,
        summary: 's',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      expect(ws.coveredUpToEpisode, 1);
    });
  });
}
