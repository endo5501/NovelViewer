import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tts_audio_db_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('TtsAudioDatabase', () {
    test('creates tts_audio.db in the specified folder', () async {
      final db = TtsAudioDatabase(tempDir.path);
      await db.database;

      final dbFile = File('${tempDir.path}/tts_audio.db');
      expect(dbFile.existsSync(), isTrue);

      await db.close();
    });

    test('creates tts_episodes table with correct schema', () async {
      final db = TtsAudioDatabase(tempDir.path);
      final database = await db.database;

      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='tts_episodes'",
      );
      expect(tables, hasLength(1));

      final columns = await database.rawQuery(
        "PRAGMA table_info('tts_episodes')",
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames, contains('id'));
      expect(columnNames, contains('file_name'));
      expect(columnNames, contains('sample_rate'));
      expect(columnNames, contains('status'));
      expect(columnNames, contains('ref_wav_path'));
      expect(columnNames, contains('created_at'));
      expect(columnNames, contains('updated_at'));

      await db.close();
    });

    test('tts_episodes file_name has unique constraint', () async {
      final db = TtsAudioDatabase(tempDir.path);
      final database = await db.database;

      await database.insert('tts_episodes', {
        'file_name': '0001_プロローグ.txt',
        'sample_rate': 24000,
        'status': 'generating',
        'ref_wav_path': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });

      expect(
        () async => await database.insert('tts_episodes', {
          'file_name': '0001_プロローグ.txt',
          'sample_rate': 24000,
          'status': 'generating',
          'ref_wav_path': null,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        }),
        throwsA(isA<Exception>()),
      );

      await db.close();
    });

    test('creates tts_segments table with correct schema', () async {
      final db = TtsAudioDatabase(tempDir.path);
      final database = await db.database;

      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='tts_segments'",
      );
      expect(tables, hasLength(1));

      final columns = await database.rawQuery(
        "PRAGMA table_info('tts_segments')",
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames, contains('id'));
      expect(columnNames, contains('episode_id'));
      expect(columnNames, contains('segment_index'));
      expect(columnNames, contains('text'));
      expect(columnNames, contains('text_offset'));
      expect(columnNames, contains('text_length'));
      expect(columnNames, contains('audio_data'));
      expect(columnNames, contains('sample_count'));
      expect(columnNames, contains('ref_wav_path'));
      expect(columnNames, contains('created_at'));

      await db.close();
    });

    test('tts_segments has unique index on (episode_id, segment_index)',
        () async {
      final db = TtsAudioDatabase(tempDir.path);
      final database = await db.database;

      final episodeId = await database.insert('tts_episodes', {
        'file_name': '0001_プロローグ.txt',
        'sample_rate': 24000,
        'status': 'generating',
        'ref_wav_path': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });

      await database.insert('tts_segments', {
        'episode_id': episodeId,
        'segment_index': 0,
        'text': 'テスト文。',
        'text_offset': 0,
        'text_length': 5,
        'audio_data': Uint8List(10),
        'sample_count': 5,
        'ref_wav_path': null,
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(
        () async => await database.insert('tts_segments', {
          'episode_id': episodeId,
          'segment_index': 0,
          'text': '重複テスト。',
          'text_offset': 5,
          'text_length': 6,
          'audio_data': Uint8List(10),
          'sample_count': 5,
          'ref_wav_path': null,
          'created_at': '2026-01-01T00:00:00.000Z',
        }),
        throwsA(isA<Exception>()),
      );

      await db.close();
    });

    test('cascade delete removes segments when episode is deleted', () async {
      final db = TtsAudioDatabase(tempDir.path);
      final database = await db.database;

      final episodeId = await database.insert('tts_episodes', {
        'file_name': '0001_プロローグ.txt',
        'sample_rate': 24000,
        'status': 'completed',
        'ref_wav_path': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });

      await database.insert('tts_segments', {
        'episode_id': episodeId,
        'segment_index': 0,
        'text': 'テスト文。',
        'text_offset': 0,
        'text_length': 5,
        'audio_data': Uint8List(10),
        'sample_count': 5,
        'ref_wav_path': null,
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      await database.delete(
        'tts_episodes',
        where: 'id = ?',
        whereArgs: [episodeId],
      );

      final segments = await database.query(
        'tts_segments',
        where: 'episode_id = ?',
        whereArgs: [episodeId],
      );
      expect(segments, isEmpty);

      await db.close();
    });

    test('reuses existing database on subsequent opens', () async {
      final db1 = TtsAudioDatabase(tempDir.path);
      final database1 = await db1.database;
      await database1.insert('tts_episodes', {
        'file_name': '0001_プロローグ.txt',
        'sample_rate': 24000,
        'status': 'completed',
        'ref_wav_path': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });
      await db1.close();

      final db2 = TtsAudioDatabase(tempDir.path);
      final database2 = await db2.database;
      final rows = await database2.query('tts_episodes');
      expect(rows, hasLength(1));
      expect(rows.first['file_name'], '0001_プロローグ.txt');

      await db2.close();
    });

    test('creates tts_episodes table with text_hash column', () async {
      final db = TtsAudioDatabase(tempDir.path);
      final database = await db.database;

      final columns = await database.rawQuery(
        "PRAGMA table_info('tts_episodes')",
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames, contains('text_hash'));

      await db.close();
    });

    test('migrates existing database to add text_hash column', () async {
      // Create a v1 database without text_hash
      final dbPath = '${tempDir.path}/tts_audio.db';
      final oldDb = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('''
            CREATE TABLE tts_episodes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              file_name TEXT NOT NULL UNIQUE,
              sample_rate INTEGER NOT NULL,
              status TEXT NOT NULL,
              ref_wav_path TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE tts_segments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              episode_id INTEGER NOT NULL,
              segment_index INTEGER NOT NULL,
              text TEXT NOT NULL,
              text_offset INTEGER NOT NULL,
              text_length INTEGER NOT NULL,
              audio_data BLOB NOT NULL,
              sample_count INTEGER NOT NULL,
              ref_wav_path TEXT,
              created_at TEXT NOT NULL,
              FOREIGN KEY (episode_id) REFERENCES tts_episodes(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX idx_segments_episode_index
            ON tts_segments(episode_id, segment_index)
          ''');
        },
      );

      // Insert an episode without text_hash
      await oldDb.insert('tts_episodes', {
        'file_name': '0001_プロローグ.txt',
        'sample_rate': 24000,
        'status': 'completed',
        'ref_wav_path': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });
      await oldDb.close();

      // Open with TtsAudioDatabase which should migrate
      final db = TtsAudioDatabase(tempDir.path);
      final database = await db.database;

      // Verify text_hash column exists
      final columns = await database.rawQuery(
        "PRAGMA table_info('tts_episodes')",
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames, contains('text_hash'));

      // Verify existing data is preserved with null text_hash
      final episodes = await database.query('tts_episodes');
      expect(episodes, hasLength(1));
      expect(episodes.first['file_name'], '0001_プロローグ.txt');
      expect(episodes.first['text_hash'], isNull);

      await db.close();
    });

    test('creates tts_segments table with memo column', () async {
      final db = TtsAudioDatabase(tempDir.path);
      final database = await db.database;

      final columns = await database.rawQuery(
        "PRAGMA table_info('tts_segments')",
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames, contains('memo'));

      await db.close();
    });

    test('tts_segments audio_data and sample_count are nullable', () async {
      final db = TtsAudioDatabase(tempDir.path);
      final database = await db.database;

      final columns = await database.rawQuery(
        "PRAGMA table_info('tts_segments')",
      );

      final audioDataCol = columns.firstWhere(
        (c) => c['name'] == 'audio_data',
      );
      final sampleCountCol = columns.firstWhere(
        (c) => c['name'] == 'sample_count',
      );
      // notnull == 0 means nullable
      expect(audioDataCol['notnull'], 0);
      expect(sampleCountCol['notnull'], 0);

      await db.close();
    });

    test('allows inserting segment without audio_data', () async {
      final db = TtsAudioDatabase(tempDir.path);
      final database = await db.database;

      final episodeId = await database.insert('tts_episodes', {
        'file_name': '0001_プロローグ.txt',
        'sample_rate': 24000,
        'status': 'generating',
        'ref_wav_path': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });

      await database.insert('tts_segments', {
        'episode_id': episodeId,
        'segment_index': 0,
        'text': 'テスト文。',
        'text_offset': 0,
        'text_length': 5,
        'audio_data': null,
        'sample_count': null,
        'ref_wav_path': null,
        'memo': 'テストメモ',
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      final segments = await database.query(
        'tts_segments',
        where: 'episode_id = ?',
        whereArgs: [episodeId],
      );
      expect(segments, hasLength(1));
      expect(segments.first['audio_data'], isNull);
      expect(segments.first['sample_count'], isNull);
      expect(segments.first['memo'], 'テストメモ');

      await db.close();
    });

    test('migrates v2 database to v3 preserving data', () async {
      // Create a v2 database (with text_hash but NOT NULL audio_data)
      final dbPath = '${tempDir.path}/tts_audio.db';
      final oldDb = await openDatabase(
        dbPath,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('''
            CREATE TABLE tts_episodes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              file_name TEXT NOT NULL UNIQUE,
              sample_rate INTEGER NOT NULL,
              status TEXT NOT NULL,
              ref_wav_path TEXT,
              text_hash TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE tts_segments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              episode_id INTEGER NOT NULL,
              segment_index INTEGER NOT NULL,
              text TEXT NOT NULL,
              text_offset INTEGER NOT NULL,
              text_length INTEGER NOT NULL,
              audio_data BLOB NOT NULL,
              sample_count INTEGER NOT NULL,
              ref_wav_path TEXT,
              created_at TEXT NOT NULL,
              FOREIGN KEY (episode_id) REFERENCES tts_episodes(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX idx_segments_episode_index
            ON tts_segments(episode_id, segment_index)
          ''');
        },
      );

      // Insert test data
      final episodeId = await oldDb.insert('tts_episodes', {
        'file_name': '0001_プロローグ.txt',
        'sample_rate': 24000,
        'status': 'completed',
        'ref_wav_path': '/path/to/ref.wav',
        'text_hash': 'abc123',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });

      final audioData = Uint8List.fromList([1, 2, 3, 4, 5]);
      await oldDb.insert('tts_segments', {
        'episode_id': episodeId,
        'segment_index': 0,
        'text': 'テスト文。',
        'text_offset': 0,
        'text_length': 5,
        'audio_data': audioData,
        'sample_count': 100,
        'ref_wav_path': '/path/to/ref.wav',
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      await oldDb.insert('tts_segments', {
        'episode_id': episodeId,
        'segment_index': 1,
        'text': '二番目の文。',
        'text_offset': 5,
        'text_length': 6,
        'audio_data': Uint8List.fromList([6, 7, 8]),
        'sample_count': 200,
        'ref_wav_path': null,
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      await oldDb.close();

      // Open with TtsAudioDatabase which should migrate to v3
      final db = TtsAudioDatabase(tempDir.path);
      final database = await db.database;

      // Verify memo column exists
      final columns = await database.rawQuery(
        "PRAGMA table_info('tts_segments')",
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames, contains('memo'));

      // Verify audio_data is now nullable
      final audioDataCol = columns.firstWhere(
        (c) => c['name'] == 'audio_data',
      );
      expect(audioDataCol['notnull'], 0);

      // Verify sample_count is now nullable
      final sampleCountCol = columns.firstWhere(
        (c) => c['name'] == 'sample_count',
      );
      expect(sampleCountCol['notnull'], 0);

      // Verify existing data is preserved
      final episodes = await database.query('tts_episodes');
      expect(episodes, hasLength(1));
      expect(episodes.first['file_name'], '0001_プロローグ.txt');
      expect(episodes.first['text_hash'], 'abc123');

      final segments = await database.query(
        'tts_segments',
        orderBy: 'segment_index ASC',
      );
      expect(segments, hasLength(2));
      expect(segments[0]['text'], 'テスト文。');
      expect(segments[0]['audio_data'], audioData);
      expect(segments[0]['sample_count'], 100);
      expect(segments[0]['ref_wav_path'], '/path/to/ref.wav');
      expect(segments[0]['memo'], isNull);
      expect(segments[1]['text'], '二番目の文。');
      expect(segments[1]['segment_index'], 1);

      // Verify unique index still works
      expect(
        () async => await database.insert('tts_segments', {
          'episode_id': episodeId,
          'segment_index': 0,
          'text': '重複テスト。',
          'text_offset': 0,
          'text_length': 6,
          'audio_data': null,
          'sample_count': null,
          'ref_wav_path': null,
          'created_at': '2026-01-01T00:00:00.000Z',
        }),
        throwsA(isA<Exception>()),
      );

      await db.close();
    });

    test('handles corrupted database by recreating', () async {
      final dbFile = File('${tempDir.path}/tts_audio.db');
      await dbFile.writeAsString('corrupted data');

      final db = TtsAudioDatabase(tempDir.path);
      final database = await db.database;

      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='tts_episodes'",
      );
      expect(tables, hasLength(1));

      await db.close();
    });
  });
}
