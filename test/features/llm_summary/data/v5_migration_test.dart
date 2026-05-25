import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _insertNovel(
  Database db, {
  required String folderName,
  required int episodeCount,
}) async {
  await db.insert('novels', {
    'site_type': 'narou',
    'novel_id': 'n_$folderName',
    'title': folderName,
    'url': 'https://example.com/$folderName',
    'folder_name': folderName,
    'episode_count': episodeCount,
    'downloaded_at': '2026-01-01T00:00:00.000',
  });
}

Future<void> _insertV4Summary(
  Database db, {
  required String folder,
  required String word,
  required String summaryType,
  String? sourceFile,
  required String summary,
  required String updatedAt,
}) async {
  await db.insert('word_summaries', {
    'folder_name': folder,
    'word': word,
    'summary_type': summaryType,
    'summary': summary,
    'source_file': sourceFile,
    'created_at': updatedAt,
    'updated_at': updatedAt,
  });
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('NovelDatabase v4 → v5 migration', () {
    test('no_spoiler row with numeric prefix uses prefix as episode', () async {
      final result = await NovelDatabase.runMigrationForTesting(
        snapshotResolver: NovelDatabaseSnapshotResolver(
          folderFileLister: (_) => const [],
        ),
        seedV4: (db) async {
          await _insertNovel(db, folderName: 'my_novel', episodeCount: 100);
          await _insertV4Summary(
            db,
            folder: 'my_novel',
            word: 'アリス',
            summaryType: 'no_spoiler',
            sourceFile: '030_chapter.txt',
            summary: '序盤要約',
            updatedAt: '2026-01-01T00:00:00.000',
          );
        },
      );

      expect(result, hasLength(1));
      expect(result.first['folder_name'], 'my_novel');
      expect(result.first['word'], 'アリス');
      expect(result.first['covered_up_to_episode'], 30);
      expect(result.first['source_file'], '030_chapter.txt');
      expect(result.first['summary'], '序盤要約');
    });

    test('no_spoiler row without numeric prefix uses lexical rank', () async {
      final result = await NovelDatabase.runMigrationForTesting(
        snapshotResolver: NovelDatabaseSnapshotResolver(
          folderFileLister: (folder) {
            if (folder == 'my_novel') {
              return const ['intro.txt', 'part1.txt', 'part2.txt'];
            }
            return const [];
          },
        ),
        seedV4: (db) async {
          await _insertNovel(db, folderName: 'my_novel', episodeCount: 0);
          await _insertV4Summary(
            db,
            folder: 'my_novel',
            word: 'アリス',
            summaryType: 'no_spoiler',
            sourceFile: 'part1.txt',
            summary: '中盤要約',
            updatedAt: '2026-01-01T00:00:00.000',
          );
        },
      );

      expect(result, hasLength(1));
      expect(result.first['covered_up_to_episode'], 2,
          reason: 'part1.txt is the 2nd file in lexical order');
    });

    test('no_spoiler row with NULL source_file falls back to 1', () async {
      final result = await NovelDatabase.runMigrationForTesting(
        snapshotResolver: NovelDatabaseSnapshotResolver(
          folderFileLister: (_) => const [],
        ),
        seedV4: (db) async {
          await _insertNovel(db, folderName: 'my_novel', episodeCount: 10);
          await _insertV4Summary(
            db,
            folder: 'my_novel',
            word: 'アリス',
            summaryType: 'no_spoiler',
            sourceFile: null,
            summary: '謎の要約',
            updatedAt: '2026-01-01T00:00:00.000',
          );
        },
      );

      expect(result, hasLength(1));
      expect(result.first['covered_up_to_episode'], 1);
    });

    test('spoiler row with NULL source_file uses novels.episode_count',
        () async {
      final result = await NovelDatabase.runMigrationForTesting(
        snapshotResolver: NovelDatabaseSnapshotResolver(
          folderFileLister: (_) => const [],
        ),
        seedV4: (db) async {
          await _insertNovel(db, folderName: 'my_novel', episodeCount: 10);
          await _insertV4Summary(
            db,
            folder: 'my_novel',
            word: 'アリス',
            summaryType: 'spoiler',
            sourceFile: null,
            summary: 'ネタバレあり',
            updatedAt: '2026-01-01T00:00:00.000',
          );
        },
      );

      expect(result, hasLength(1));
      expect(result.first['covered_up_to_episode'], 10);
      expect(result.first['source_file'], isNull);
    });

    test('spoiler row with episode_count=0 falls back to 1', () async {
      final result = await NovelDatabase.runMigrationForTesting(
        snapshotResolver: NovelDatabaseSnapshotResolver(
          folderFileLister: (_) => const [],
        ),
        seedV4: (db) async {
          await _insertNovel(db, folderName: 'my_novel', episodeCount: 0);
          await _insertV4Summary(
            db,
            folder: 'my_novel',
            word: 'アリス',
            summaryType: 'spoiler',
            sourceFile: null,
            summary: 'ネタバレ',
            updatedAt: '2026-01-01T00:00:00.000',
          );
        },
      );

      expect(result, hasLength(1));
      expect(result.first['covered_up_to_episode'], 1);
    });

    test(
        'spoiler row with non-null source_file uses '
        'max(prefix, episode_count)', () async {
      final result = await NovelDatabase.runMigrationForTesting(
        snapshotResolver: NovelDatabaseSnapshotResolver(
          folderFileLister: (_) => const [],
        ),
        seedV4: (db) async {
          await _insertNovel(db, folderName: 'my_novel', episodeCount: 40);
          await _insertV4Summary(
            db,
            folder: 'my_novel',
            word: 'アリス',
            summaryType: 'spoiler',
            sourceFile: '025_chapter.txt',
            summary: 'a',
            updatedAt: '2026-01-01T00:00:00.000',
          );
          await _insertV4Summary(
            db,
            folder: 'my_novel',
            word: 'ボブ',
            summaryType: 'spoiler',
            sourceFile: '060_chapter.txt',
            summary: 'b',
            updatedAt: '2026-01-01T00:00:00.000',
          );
        },
      );

      final aliceRow = result.firstWhere((r) => r['word'] == 'アリス');
      final bobRow = result.firstWhere((r) => r['word'] == 'ボブ');
      expect(aliceRow['covered_up_to_episode'], 40,
          reason: 'max(25, 40) = 40');
      expect(bobRow['covered_up_to_episode'], 60, reason: 'max(60, 40) = 60');
    });

    test('collision: same (folder, word, episode) keeps latest updated_at',
        () async {
      final result = await NovelDatabase.runMigrationForTesting(
        snapshotResolver: NovelDatabaseSnapshotResolver(
          folderFileLister: (_) => const [],
        ),
        seedV4: (db) async {
          await _insertNovel(db, folderName: 'my_novel', episodeCount: 30);
          // Two rows that both convert to covered_up_to_episode=30.
          await _insertV4Summary(
            db,
            folder: 'my_novel',
            word: 'アリス',
            summaryType: 'no_spoiler',
            sourceFile: '030_chapter.txt',
            summary: '古い (10:00)',
            updatedAt: '2026-01-01T10:00:00.000',
          );
          await _insertV4Summary(
            db,
            folder: 'my_novel',
            word: 'アリス',
            summaryType: 'spoiler',
            sourceFile: '030_chapter.txt',
            summary: '新しい (12:00)',
            updatedAt: '2026-01-01T12:00:00.000',
          );
        },
      );

      expect(result, hasLength(1),
          reason: 'colliding rows SHALL collapse to one');
      expect(result.first['summary'], '新しい (12:00)');
      expect(result.first['covered_up_to_episode'], 30);
    });

    test('non-conflicting rows for the same word are preserved', () async {
      final result = await NovelDatabase.runMigrationForTesting(
        snapshotResolver: NovelDatabaseSnapshotResolver(
          folderFileLister: (_) => const [],
        ),
        seedV4: (db) async {
          await _insertNovel(db, folderName: 'my_novel', episodeCount: 100);
          await _insertV4Summary(
            db,
            folder: 'my_novel',
            word: 'アリス',
            summaryType: 'no_spoiler',
            sourceFile: '030_chapter.txt',
            summary: '序盤',
            updatedAt: '2026-01-01T10:00:00.000',
          );
          await _insertV4Summary(
            db,
            folder: 'my_novel',
            word: 'アリス',
            summaryType: 'spoiler',
            sourceFile: '100_chapter.txt',
            summary: '全話',
            updatedAt: '2026-01-01T12:00:00.000',
          );
        },
      );

      expect(result, hasLength(2));
      final episodes = result
          .map((r) => r['covered_up_to_episode'] as int)
          .toList()
        ..sort();
      expect(episodes, [30, 100]);
    });

    test('migration creates the v5 unique index', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, version) async {
            // Use the production onCreate via NovelDatabase if possible.
            // Here, we directly invoke the schema creation.
            await NovelDatabase.createV5SchemaForTesting(db);
          },
        ),
      );

      final indices = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='word_summaries'");
      expect(
        indices.any((row) => row['name'] == 'idx_word_summaries_unique'),
        isTrue,
      );

      // Schema sanity: covered_up_to_episode column must exist with NOT NULL.
      final pragma = await db.rawQuery('PRAGMA table_info(word_summaries)');
      final cols = {
        for (final row in pragma) row['name'] as String: row,
      };
      expect(cols.containsKey('covered_up_to_episode'), isTrue);
      expect(cols['covered_up_to_episode']!['notnull'], 1);
      expect(cols.containsKey('summary_type'), isFalse,
          reason: 'v5 SHALL NOT carry summary_type');

      await db.close();
    });
  });
}
