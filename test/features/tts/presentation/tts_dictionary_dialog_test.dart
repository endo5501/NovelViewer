import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_database.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_repository.dart';
import 'package:novel_viewer/features/tts/presentation/tts_dictionary_dialog.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory stand-in for the dictionary repository.
///
/// The real one talks to sqflite, whose futures never complete inside a
/// widget test's fake-async zone — the dialog would sit on its spinner
/// forever and nothing about the list could be asserted.
class _InMemoryDictionaryRepository implements TtsDictionaryRepository {
  final entries = <TtsDictionaryEntry>[];
  var _nextId = 1;

  @override
  Future<int> addEntry(String surface, String reading) async {
    if (surface.isEmpty) throw ArgumentError('surface must not be empty');
    if (entries.any((e) => e.surface == surface)) {
      throw StateError('duplicate surface');
    }
    final id = _nextId++;
    entries.add(
        TtsDictionaryEntry(id: id, surface: surface, reading: reading));
    return id;
  }

  @override
  Future<List<TtsDictionaryEntry>> getAllEntries() async => List.of(entries);

  @override
  Future<List<TtsDictionaryEntry>> getEntriesSortedByLength() async =>
      List.of(entries)
        ..sort((a, b) => b.surface.length.compareTo(a.surface.length));

  @override
  Future<void> updateEntry(int id, String surface, String reading) async {
    if (surface.isEmpty) throw ArgumentError('surface must not be empty');
    final index = entries.indexWhere((e) => e.id == id);
    if (index >= 0) {
      entries[index] =
          TtsDictionaryEntry(id: id, surface: surface, reading: reading);
    }
  }

  @override
  Future<void> deleteEntry(int id) async {
    entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<String> applyDictionary(String text) async =>
      TtsDictionaryRepository.applyDictionaryWithEntries(
          await getEntriesSortedByLength(), text);
}

void main() {
  late Directory tempDir;
  late TtsDictionaryDatabase database;
  late TtsDictionaryRepository repository;
  late _InMemoryDictionaryRepository fakeRepository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir =
        Directory.systemTemp.createTempSync('tts_dictionary_dialog_test_');
    database = TtsDictionaryDatabase(tempDir.path);
    repository = TtsDictionaryRepository(database);
    fakeRepository = _InMemoryDictionaryRepository();
  });

  tearDown(() async {
    await database.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {
      // Ignore file lock errors on Windows
    }
  });

  Widget buildTestApp({
    String? initialSurface,
    TtsDictionaryRepository? repositoryOverride,
  }) {
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
                repository: repositoryOverride ?? repository,
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

  group('TtsDictionaryDialog no-reading entries', () {
    Finder readingField() => find.byType(TextField).at(1);

    Future<void> openFake(WidgetTester tester) async {
      await tester.pumpWidget(
          buildTestApp(repositoryOverride: fakeRepository));
      await openDialogAndWait(tester);
    }

    Future<void> enterSurface(WidgetTester tester, String surface) async {
      await tester.enterText(find.byType(TextField).first, surface);
      await tester.pump();
    }

    Future<void> tapNoReading(WidgetTester tester) async {
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
    }

    Future<void> tapAdd(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.add));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('shows a "do not read aloud" checkbox', (tester) async {
      await openFake(tester);

      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('読み上げしない'), findsOneWidget);
    });

    testWidgets('checking it disables the reading field', (tester) async {
      await openFake(tester);

      expect(tester.widget<TextField>(readingField()).enabled, isTrue);

      await tapNoReading(tester);

      expect(tester.widget<TextField>(readingField()).enabled, isFalse);
    });

    testWidgets('adds an entry with an empty reading', (tester) async {
      await openFake(tester);

      await enterSurface(tester, '――‐');
      await tapNoReading(tester);
      await tapAdd(tester);

      expect(fakeRepository.entries, hasLength(1));
      expect(fakeRepository.entries.first.surface, '――‐');
      expect(fakeRepository.entries.first.reading, '');
      expect(find.text('（読み上げなし）'), findsOneWidget);
    });

    testWidgets('a stale reading is discarded when the box is checked',
        (tester) async {
      await openFake(tester);

      await enterSurface(tester, '――‐');
      await tester.enterText(readingField(), 'だっしゅ');
      await tester.pump();
      await tapNoReading(tester);
      await tapAdd(tester);

      // What the disabled field still displays must not reach the entry.
      expect(fakeRepository.entries.first.reading, '');
    });

    testWidgets('the checkbox resets after a successful add', (tester) async {
      await openFake(tester);

      await enterSurface(tester, '――‐');
      await tapNoReading(tester);
      await tapAdd(tester);

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(tester.widget<TextField>(readingField()).enabled, isTrue);
    });

    testWidgets('still rejects an empty reading when unchecked',
        (tester) async {
      await openFake(tester);

      await enterSurface(tester, '――‐');
      await tapAdd(tester);

      expect(fakeRepository.entries, isEmpty);
      expect(find.text('表記と読みの両方を入力してください'),
          findsOneWidget);
    });

    testWidgets('rejects an empty surface even when checked', (tester) async {
      await openFake(tester);

      await tapNoReading(tester);
      await tapAdd(tester);

      // The generic "both fields" message would be a lie here: with the box
      // ticked, only the surface is required.
      expect(fakeRepository.entries, isEmpty);
      expect(find.text('表記を入力してください'), findsOneWidget);
    });

    testWidgets('shows a label for a no-reading entry and the reading for '
        'a normal one', (tester) async {
      await fakeRepository.addEntry('――‐', '');
      // Not "やまだたろう": that is the reading field's hint text, so it
      // would also match outside the list.
      await fakeRepository.addEntry('エルリック', 'えるりっく');

      await openFake(tester);

      // A blank subtitle would be indistinguishable from a broken entry.
      expect(find.text('（読み上げなし）'), findsOneWidget);
      expect(find.text('えるりっく'), findsOneWidget);
    });
  });
}
