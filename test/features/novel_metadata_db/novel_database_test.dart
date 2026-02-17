import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('NovelDatabase path resolution', () {
    test('opens database in specified dbDirPath', () async {
      final tempDir = Directory.systemTemp.createTempSync('novel_db_test_');
      try {
        final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
        await novelDatabase.database;

        final dbFile = File(p.join(tempDir.path, 'novel_metadata.db'));
        expect(dbFile.existsSync(), isTrue);

        await novelDatabase.close();
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'opens database in exe directory on Windows when no dbDirPath',
      () async {
        final exeDir = p.dirname(Platform.resolvedExecutable);
        final dbFile = File(p.join(exeDir, 'novel_metadata.db'));

        final novelDatabase = NovelDatabase();
        try {
          await novelDatabase.database;

          expect(dbFile.existsSync(), isTrue);
        } finally {
          await novelDatabase.close();
          if (dbFile.existsSync()) dbFile.deleteSync();
        }
      },
      skip: !Platform.isWindows ? 'Windows-only test' : null,
    );
  });
}
