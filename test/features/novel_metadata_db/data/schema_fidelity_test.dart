import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

/// Returns `{objectName: normalized CREATE statement}` for every user-defined
/// table AND index, so two databases can be compared for full schema equality.
///
/// Indexes are included (not just tables) because the production schema defines
/// unique indexes (e.g. `idx_novels_site_novel`) that are part of the contract;
/// a drift guard that ignored them would miss an index added or dropped in only
/// one place. `sqlite_%` objects (auto-indexes, internal tables) and the
/// platform `android_metadata` table are excluded, and auto-indexes have a NULL
/// `sql`, so rows without a CREATE statement are skipped.
Future<Map<String, String>> _schemaObjects(Database db) async {
  final rows = await db.rawQuery(
    'SELECT name, sql FROM sqlite_master '
    "WHERE type IN ('table', 'index') AND name NOT LIKE 'sqlite_%' "
    "AND name NOT LIKE 'android_metadata' ORDER BY name",
  );
  return {
    for (final row in rows)
      if (row['sql'] != null)
        row['name'] as String:
            (row['sql'] as String).replaceAll(RegExp(r'\s+'), ' ').trim(),
  };
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
      'shared in-memory test fixture has the same schema as production NovelDatabase',
      () async {
    final tempDir = Directory.systemTemp.createTempSync('schema_fidelity_');
    try {
      // Production schema: a fresh NovelDatabase runs the real _onCreate.
      final production = NovelDatabase(dbDirPath: tempDir.path);
      late final Map<String, String> productionSchema;
      try {
        productionSchema = await _schemaObjects(await production.database);
      } finally {
        await production.close();
      }

      // Test fixture schema: built via the shared helper that delegates to the
      // production schema definition — no hand-written DDL.
      final fixtureDb = await openInMemoryNovelMetadataDb();
      late final Map<String, String> fixtureSchema;
      try {
        fixtureSchema = await _schemaObjects(fixtureDb);
      } finally {
        await fixtureDb.close();
      }

      expect(fixtureSchema, productionSchema,
          reason: 'test fixtures MUST inherit the production schema so that a '
              'production schema change cannot drift away from tests');
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}
