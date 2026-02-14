import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class NovelDatabase {
  static const _databaseName = 'novel_metadata.db';
  static const _databaseVersion = 2;

  Database? _database;

  Future<Database> get database async {
    final db = _database;
    if (db != null) return db;
    return _database = await _open();
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE novels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_type TEXT NOT NULL,
        novel_id TEXT NOT NULL,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        folder_name TEXT NOT NULL UNIQUE,
        episode_count INTEGER NOT NULL DEFAULT 0,
        downloaded_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_novels_site_novel
      ON novels(site_type, novel_id)
    ''');
    await _createWordSummariesTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createWordSummariesTable(db);
    }
  }

  static Future<void> _createWordSummariesTable(Database db) async {
    await db.execute('''
      CREATE TABLE word_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_name TEXT NOT NULL,
        word TEXT NOT NULL,
        summary_type TEXT NOT NULL,
        summary TEXT NOT NULL,
        source_file TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_word_summaries_unique
      ON word_summaries(folder_name, word, summary_type)
    ''');
  }

  /// For testing: initialize with a provided database instance.
  void setDatabase(Database db) {
    _database = db;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
