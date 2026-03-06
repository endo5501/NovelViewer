import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_database.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_repository.dart';
import 'package:novel_viewer/features/tts/presentation/tts_dictionary_dialog.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late TtsDictionaryDatabase database;
  late TtsDictionaryRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir =
        Directory.systemTemp.createTempSync('tts_dictionary_dialog_test_');
    database = TtsDictionaryDatabase(tempDir.path);
    repository = TtsDictionaryRepository(database);
  });

  tearDown(() async {
    await database.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {
      // Ignore file lock errors on Windows
    }
  });

  Widget buildTestApp({String? initialSurface}) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => TtsDictionaryDialog.show(
                context,
                repository: repository,
                initialSurface: initialSurface,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialogAndWait(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    // Pump enough frames for the dialog and async _loadEntries to complete,
    // but don't use pumpAndSettle (CircularProgressIndicator animates forever).
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('TtsDictionaryDialog initialSurface', () {
    testWidgets('surface field is empty when initialSurface is not provided',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await openDialogAndWait(tester);

      final surfaceField = find.byType(TextField).first;
      final controller =
          (tester.widget<TextField>(surfaceField)).controller!;
      expect(controller.text, isEmpty);
    });

    testWidgets('surface field is pre-filled when initialSurface is provided',
        (tester) async {
      await tester.pumpWidget(buildTestApp(initialSurface: '山田太郎'));
      await openDialogAndWait(tester);

      final surfaceField = find.byType(TextField).first;
      final controller =
          (tester.widget<TextField>(surfaceField)).controller!;
      expect(controller.text, '山田太郎');
    });

    testWidgets('reading field is empty even when initialSurface is provided',
        (tester) async {
      await tester.pumpWidget(buildTestApp(initialSurface: '山田太郎'));
      await openDialogAndWait(tester);

      final readingField = find.byType(TextField).at(1);
      final controller =
          (tester.widget<TextField>(readingField)).controller!;
      expect(controller.text, isEmpty);
    });
  });
}
