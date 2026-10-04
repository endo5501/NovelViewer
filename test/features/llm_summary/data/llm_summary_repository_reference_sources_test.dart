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

  const part1 = SnapshotReferenceSource(folderName: 'narou_p1', title: '第1部');
  const wiki = SnapshotReferenceSource(folderName: 'web_wiki', title: 'Wiki');

  test('records the reference sources in the order given', () async {
    await repository.saveSnapshot(
      word: 'アリス',
      coveredUpToEpisode: 10,
      summary: 's',
      referenceSources: const [part1, wiki],
    );

    final snapshot = (await repository.findSnapshotsForWord(word: 'アリス'))
        .single;
    expect(snapshot.referenceSources, const [part1, wiki]);
  });

  test('a snapshot saved without reference sources reads as empty', () async {
    await repository.saveSnapshot(
      word: 'アリス',
      coveredUpToEpisode: 10,
      summary: 's',
    );

    final snapshot = (await repository.findSnapshotsForWord(word: 'アリス'))
        .single;
    expect(snapshot.referenceSources, isEmpty);
  });

  test('a NULL column, as left by the v3 upgrade, reads as empty', () async {
    await db.insert('word_summaries', {
      'word': 'アリス',
      'covered_up_to_episode': 3,
      'summary': 'old',
      'reference_sources': null,
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });

    final snapshot = (await repository.findAll()).single;
    expect(snapshot.referenceSources, isEmpty);
  });

  test('re-analysis at the same bound replaces the list', () async {
    await repository.saveSnapshot(
      word: 'アリス',
      coveredUpToEpisode: 10,
      summary: 'first',
    );
    await repository.saveSnapshot(
      word: 'アリス',
      coveredUpToEpisode: 10,
      summary: 'second',
      referenceSources: const [part1],
    );

    final snapshot = (await repository.findSnapshotsForWord(word: 'アリス'))
        .single;
    expect(snapshot.summary, 'second');
    expect(snapshot.referenceSources, const [part1]);
  });

  test('re-analysis without reference sources clears the list', () async {
    await repository.saveSnapshot(
      word: 'アリス',
      coveredUpToEpisode: 10,
      summary: 'first',
      referenceSources: const [part1],
    );
    await repository.saveSnapshot(
      word: 'アリス',
      coveredUpToEpisode: 10,
      summary: 'second',
    );

    final snapshot = (await repository.findSnapshotsForWord(word: 'アリス'))
        .single;
    expect(snapshot.referenceSources, isEmpty);
  });
}
