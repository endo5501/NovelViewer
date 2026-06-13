import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../../../shared/database/database_opener.dart';
import '../../../shared/database/db_connection_gate.dart';

class EpisodeCacheDatabase {
  static const _databaseName = 'episode_cache.db';
  static const _databaseVersion = 1;
  static final _log = Logger('episode_cache_db');

  final String _folderPath;
  late final DbConnectionGate<Database> _gate = DbConnectionGate<Database>(
    opener: _open,
    closer: (db) => db.close(),
  );

  EpisodeCacheDatabase(this._folderPath);

  Future<Database> get database => _gate.resource;

  Future<Database> _open() async {
    final path = p.join(_folderPath, _databaseName);
    return openOrResetDatabase(
      path: path,
      version: _databaseVersion,
      onCreate: _onCreate,
      deleteOnFailure: true,
      logger: _log,
    );
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

  Future<void> close() => _gate.close();
}
