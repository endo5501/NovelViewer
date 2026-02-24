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
