import 'package:novel_viewer/shared/database/novel_data_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh in-memory `novel_data.db` whose schema is created through the
/// production [NovelDataDatabase.createCurrentSchema] definition.
///
/// Repository tests that exercise the per-folder `word_summaries` /
/// `fact_cache` / `bookmarks` tables MUST build their database with this helper
/// instead of hand-writing DDL, so a production schema change cannot drift away
/// from tests. The caller owns the returned [Database] and MUST close it.
///
/// Callers must have initialised FFI (`sqfliteFfiInit()`) before invoking this.
Future<Database> openInMemoryNovelDataDb() {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      // singleInstance:false so this in-memory DB is a DISTINCT connection from
      // any other `:memory:` database opened in the same test (e.g. the
      // novel_metadata fixture). With the default (true), sqflite dedups by the
      // ':memory:' path and both fixtures would share one connection/schema.
      singleInstance: false,
      onCreate: (db, _) => NovelDataDatabase.createCurrentSchema(db),
    ),
  );
}
