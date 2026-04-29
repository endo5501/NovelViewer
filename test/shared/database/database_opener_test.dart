import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/shared/database/database_opener.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('database_opener_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
  }

  group('openOrResetDatabase', () {
    test('opens a fresh database normally', () async {
      final path = p.join(tempDir.path, 'fresh.db');
      final db = await openOrResetDatabase(
        path: path,
        version: 1,
        onCreate: onCreate,
      );
      try {
        await db.insert('items', {'name': 'hello'});
        final rows = await db.query('items');
        expect(rows, hasLength(1));
        expect(rows.first['name'], 'hello');
      } finally {
        await db.close();
      }
    });

    test('with deleteOnFailure=true, deletes corrupt file and recreates',
        () async {
      final path = p.join(tempDir.path, 'corrupt.db');
      // Write a file that is not a valid sqlite database
      File(path).writeAsBytesSync([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);

      final db = await openOrResetDatabase(
        path: path,
        version: 1,
        onCreate: onCreate,
        deleteOnFailure: true,
      );
      try {
        // Schema should have been created fresh
        final rows = await db.query('items');
        expect(rows, isEmpty);
      } finally {
        await db.close();
      }
    });

    test('with deleteOnFailure=false, rethrows and preserves the file',
        () async {
      final path = p.join(tempDir.path, 'preserved.db');
      final corrupt = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
      File(path).writeAsBytesSync(corrupt);

      Object? error;
      try {
        await openOrResetDatabase(
          path: path,
          version: 1,
          onCreate: onCreate,
          deleteOnFailure: false,
        );
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull);

      // File preserved with original content
      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsBytesSync(), corrupt);
    });

    test('logs a WARNING via supplied Logger when open fails', () async {
      final path = p.join(tempDir.path, 'corrupt2.db');
      File(path).writeAsBytesSync([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);

      final logger = Logger('database_opener_test');
      final records = <LogRecord>[];
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(records.add);

      try {
        final db = await openOrResetDatabase(
          path: path,
          version: 1,
          onCreate: onCreate,
          deleteOnFailure: true,
          logger: logger,
        );
        await db.close();
      } finally {
        await sub.cancel();
      }

      final warnings = records
          .where((r) =>
              r.level == Level.WARNING &&
              r.loggerName == 'database_opener_test')
          .toList();
      expect(warnings, isNotEmpty);
      expect(warnings.first.message, contains(path));
    });
  });
}
