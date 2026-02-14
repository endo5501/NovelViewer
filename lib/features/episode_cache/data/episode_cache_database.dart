import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class EpisodeCacheDatabase {
  static const _databaseName = 'episode_cache.db';
  static const _databaseVersion = 1;

  final String _folderPath;
  Database? _database;

  EpisodeCacheDatabase(this._folderPath);

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
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE episode_cache (
        url TEXT PRIMARY KEY,
        episode_index INTEGER NOT NULL,
        title TEXT NOT NULL,
        last_modified TEXT,
        downloaded_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
