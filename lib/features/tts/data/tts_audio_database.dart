import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class TtsAudioDatabase {
  static const _databaseName = 'tts_audio.db';
  static const _databaseVersion = 1;

  final String _folderPath;
  Database? _database;

  TtsAudioDatabase(this._folderPath);

  Future<Database> get database async {
    final db = _database;
    if (db != null) return db;
    return _database = await _open();
  }

  Future<Database> _open() async {
    final path = p.join(_folderPath, _databaseName);
    try {
      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onConfigure: _onConfigure,
      );
    } catch (_) {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onConfigure: _onConfigure,
      );
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
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
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
