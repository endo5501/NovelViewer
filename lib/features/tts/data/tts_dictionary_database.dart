import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../../../shared/database/database_opener.dart';

class TtsDictionaryDatabase {
  static const _databaseName = 'tts_dictionary.db';
  static const _databaseVersion = 1;
  static final _log = Logger('tts.dictionary_db');

  final String _folderPath;
  Database? _database;

  TtsDictionaryDatabase(this._folderPath);

  Future<Database> get database async {
    final db = _database;
    if (db != null) return db;
    return _database = await _open();
  }

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
      CREATE TABLE tts_dictionary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surface TEXT NOT NULL UNIQUE,
        reading TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
