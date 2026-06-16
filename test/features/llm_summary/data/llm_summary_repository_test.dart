import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_data_db_fixture.dart';

void main() {
  late Database db;
  late LlmSummaryRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    db = await openInMemoryNovelDataDb();
    repository = LlmSummaryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('LlmSummaryRepository', () {
    group('saveSnapshot', () {
      test('inserts a new snapshot row', () async {
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: 'アリスは少女。',
          sourceFile: '030_chapter.txt',
        );

        final snapshots = await repository.findSnapshotsForWord(word: 'アリス');

        expect(snapshots, hasLength(1));
        expect(snapshots.first.coveredUpToEpisode, 30);
        expect(snapshots.first.summary, 'アリスは少女。');
        expect(snapshots.first.sourceFile, '030_chapter.txt');
      });

      test('upserts when (word, episode) collides', () async {
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: '初回',
          sourceFile: '030_chapter.txt',
        );
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: '上書き',
          sourceFile: '030_chapter.txt',
        );

        final snapshots = await repository.findSnapshotsForWord(word: 'アリス');

        expect(snapshots, hasLength(1),
            reason: 'colliding PK SHALL upsert, not duplicate');
        expect(snapshots.first.summary, '上書き');
      });

      test('different episodes coexist for the same word', () async {
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: '30話時点',
          sourceFile: '030_chapter.txt',
        );
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 120,
          summary: '全話時点',
          sourceFile: '120_chapter.txt',
        );

        final snapshots = await repository.findSnapshotsForWord(word: 'アリス');

        expect(snapshots, hasLength(2));
        expect(
            snapshots.map((s) => s.coveredUpToEpisode).toList(), [30, 120]);
      });

      test('rejects 1-character word', () async {
        await expectLater(
          repository.saveSnapshot(
            word: 'の',
            coveredUpToEpisode: 1,
            summary: '要約',
          ),
          throwsArgumentError,
        );
      });

      test('accepts 2-character word', () async {
        await repository.saveSnapshot(
          word: '聖印',
          coveredUpToEpisode: 5,
          summary: '騎士の証',
        );
        final snapshots = await repository.findSnapshotsForWord(word: '聖印');
        expect(snapshots, hasLength(1));
      });

      test('allows null source_file', () async {
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'レガシー扱い',
          sourceFile: null,
        );
        final snapshots = await repository.findSnapshotsForWord(word: 'アリス');
        expect(snapshots.first.sourceFile, isNull);
      });
    });

    group('findSnapshotsForWord', () {
      test('returns snapshots sorted by coveredUpToEpisode ascending', () async {
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 60,
          summary: 'b',
          sourceFile: '060.txt',
        );
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'a',
          sourceFile: '010.txt',
        );
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: 'm',
          sourceFile: '030.txt',
        );

        final snapshots = await repository.findSnapshotsForWord(word: 'アリス');

        expect(
            snapshots.map((s) => s.coveredUpToEpisode).toList(), [10, 30, 60]);
      });

      test('returns empty list when no snapshots exist', () async {
        final snapshots = await repository.findSnapshotsForWord(word: '未知');
        expect(snapshots, isEmpty);
      });

      test('only returns rows for the requested word', () async {
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'a',
          sourceFile: '010.txt',
        );
        await repository.saveSnapshot(
          word: 'ボブ',
          coveredUpToEpisode: 30,
          summary: 'bob',
          sourceFile: '030.txt',
        );

        final snapshots = await repository.findSnapshotsForWord(word: 'アリス');

        expect(snapshots, hasLength(1));
        expect(snapshots.first.word, 'アリス');
      });
    });

    group('deleteAllForWord', () {
      test('removes every snapshot for the word', () async {
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'a',
          sourceFile: '010.txt',
        );
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: 'b',
          sourceFile: '030.txt',
        );

        await repository.deleteAllForWord(word: 'アリス');

        final snapshots = await repository.findSnapshotsForWord(word: 'アリス');
        expect(snapshots, isEmpty);
      });

      test('leaves other words untouched', () async {
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'a',
          sourceFile: '010.txt',
        );
        await repository.saveSnapshot(
          word: 'ボブ',
          coveredUpToEpisode: 10,
          summary: 'b',
          sourceFile: '010.txt',
        );

        await repository.deleteAllForWord(word: 'アリス');

        final bob = await repository.findSnapshotsForWord(word: 'ボブ');
        expect(bob, hasLength(1));
      });
    });

    group('findAll', () {
      test('returns rows ordered by (word, coveredUpToEpisode) ascending',
          () async {
        await repository.saveSnapshot(
          word: 'ボブ',
          coveredUpToEpisode: 5,
          summary: 'bob5',
          sourceFile: '005.txt',
        );
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 30,
          summary: 'a30',
          sourceFile: '030.txt',
        );
        await repository.saveSnapshot(
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'a10',
          sourceFile: '010.txt',
        );
        await repository.saveSnapshot(
          word: 'ボブ',
          coveredUpToEpisode: 50,
          summary: 'bob50',
          sourceFile: '050.txt',
        );

        final rows = await repository.findAll();

        expect(
          rows.map((r) => '${r.word}/${r.coveredUpToEpisode}').toList(),
          ['アリス/10', 'アリス/30', 'ボブ/5', 'ボブ/50'],
        );
      });

      test('returns empty list when there are no rows', () async {
        final rows = await repository.findAll();
        expect(rows, isEmpty);
      });
    });

    test('legacy null source_file reads back as null', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('word_summaries', {
        'word': 'アリス',
        'covered_up_to_episode': 10,
        'summary': '古いネタバレ要約',
        'source_file': null,
        'created_at': now,
        'updated_at': now,
      });

      final snapshots = await repository.findSnapshotsForWord(word: 'アリス');

      expect(snapshots, hasLength(1));
      expect(snapshots.first.sourceFile, isNull);
      expect(snapshots.first.summary, '古いネタバレ要約');
    });

    test('WordSummary symbol is wired', () {
      final ws = WordSummary(
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
