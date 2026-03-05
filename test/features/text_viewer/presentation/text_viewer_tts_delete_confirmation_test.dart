import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('tts_delete_confirm_test_');
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // DB file may still be locked by sqflite; ignore cleanup failure
    }
  });

  /// Build the widget tree with overrides that let _checkAudioState complete.
  Widget buildTestWidget({
    required SharedPreferences prefs,
    required String tempDirPath,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
        fileContentProvider.overrideWith((ref) async => 'テスト小説の内容です。'),
        ttsModelDirProvider.overrideWithValue('/tmp/test/models/tts'),
        currentDirectoryProvider.overrideWith(() {
          return CurrentDirectoryNotifier(tempDirPath);
        }),
        selectedFileProvider.overrideWith(() {
          final notifier = SelectedFileNotifier();
          return notifier;
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
    );
  }

  /// Pump the widget, select a file, let _checkAudioState run (sets none),
  /// then set state to ready. After that, _checkAudioState will short-circuit
  /// because _lastCheckedFileKey matches.
  Future<ProviderContainer> pumpWithReadyAudioState(
    WidgetTester tester, {
    required SharedPreferences prefs,
    required String tempDirPath,
  }) async {
    await tester.pumpWidget(buildTestWidget(
      prefs: prefs,
      tempDirPath: tempDirPath,
    ));
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(TextViewerPanel));
    final container = ProviderScope.containerOf(element);

    // Select a file so _checkAudioState will set _lastCheckedFileKey
    container.read(selectedFileProvider.notifier).selectFile(
          const FileEntry(name: 'test.txt', path: '/tmp/test.txt'),
        );
    await tester.pumpAndSettle();

    // _checkAudioState ran, found no episode, set state to none.
    // _lastCheckedFileKey is now '/tmp/test.txt'.
    // Set state to ready - next rebuild won't re-run _checkAudioState.
    container.read(ttsAudioStateProvider.notifier).set(TtsAudioState.ready);
    await tester.pumpAndSettle();

    return container;
  }

  group('TTS delete confirmation dialog', () {
    testWidgets('shows confirmation dialog when delete button is tapped',
        (WidgetTester tester) async {
      await pumpWithReadyAudioState(tester,
          prefs: prefs, tempDirPath: tempDir.path);

      // Find and tap the delete button
      final deleteButton = find.byIcon(Icons.delete_outline);
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('音声データの削除'), findsOneWidget);
      expect(find.text('音声データを削除しますか？'), findsOneWidget);
    });

    testWidgets('does not delete when cancel is tapped',
        (WidgetTester tester) async {
      final container = await pumpWithReadyAudioState(tester,
          prefs: prefs, tempDirPath: tempDir.path);

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.byType(AlertDialog), findsNothing);

      // Audio state should remain ready (not deleted)
      expect(container.read(ttsAudioStateProvider), TtsAudioState.ready);
    });

    testWidgets('proceeds with deletion when confirm is tapped',
        (WidgetTester tester) async {
      await pumpWithReadyAudioState(tester,
          prefs: prefs, tempDirPath: tempDir.path);

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Tap delete confirmation
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
