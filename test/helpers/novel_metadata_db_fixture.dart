import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh in-memory `novel_metadata.db` whose schema is created through
/// the production [NovelDatabase.createCurrentSchema] definition.
///
/// Tests that need the current `novel_metadata.db` schema MUST build their
/// database with this helper (or [seedNovelDatabaseFixture]) instead of
/// hand-writing `CREATE TABLE` DDL, so that a production schema change cannot
/// drift away from tests (F130). The caller owns the returned [Database] and
/// MUST close it.
///
/// Callers must have initialised FFI (`sqfliteFfiInit()` /
/// `databaseFactory = databaseFactoryFfi`) before invoking this helper.
Future<Database> openInMemoryNovelMetadataDb() {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: NovelDatabase.currentSchemaVersion,
      onCreate: (db, _) => NovelDatabase.createCurrentSchema(db),
    ),
  );
}

/// Builds a [NovelDatabase] backed by a fresh in-memory database created through
/// the production schema, ready to be passed to a repository under test.
///
/// Returns the [NovelDatabase] (close it via `close()` in tearDown). The schema
/// always matches production because [openInMemoryNovelMetadataDb] delegates to
/// [NovelDatabase.createCurrentSchema].
Future<NovelDatabase> seedNovelDatabaseFixture() async {
  final novelDatabase = NovelDatabase();
  final db = await openInMemoryNovelMetadataDb();
  novelDatabase.setDatabase(db);
  return novelDatabase;
}
