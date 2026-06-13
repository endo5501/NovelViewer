import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../../../shared/database/database_opener.dart';
import '../../../shared/database/db_connection_gate.dart';

class TtsDictionaryDatabase {
  static const _databaseName = 'tts_dictionary.db';
  static const _databaseVersion = 1;
  static final _log = Logger('tts.dictionary_db');

  final String _folderPath;
  late final DbConnectionGate<Database> _gate = DbConnectionGate<Database>(
    opener: _open,
    closer: (db) => db.close(),
  );

  TtsDictionaryDatabase(this._folderPath);

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
      CREATE TABLE tts_dictionary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surface TEXT NOT NULL UNIQUE,
        reading TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() => _gate.close();
}
