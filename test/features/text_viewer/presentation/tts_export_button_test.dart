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
import 'package:novel_viewer/features/tts/providers/tts_export_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'tts_model_dir': '/mock/model/dir',
    });
    prefs = await SharedPreferences.getInstance();
    tempDir = await Directory.systemTemp.createTemp('tts_export_test_');
  });

  tearDown(() async {
    // Allow pending async DB operations from _checkAudioState to complete
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      try {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
        break;
      } on FileSystemException {
        // DB may still be closing, retry
      }
    }
  });

  Future<void> setupReadyState(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          fileContentProvider.overrideWith((ref) async => 'テスト内容'),
          selectedFileProvider.overrideWith(() {
            final notifier = SelectedFileNotifier();
            return notifier;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(TextViewerPanel));
    final container = ProviderScope.containerOf(element);

    // Set directory and file so _checkAudioState can run and set _lastCheckedFileKey
    container
        .read(currentDirectoryProvider.notifier)
        .setDirectory(tempDir.path);
    container.read(selectedFileProvider.notifier).selectFile(
          FileEntry(name: 'test.txt', path: '${tempDir.path}/test.txt'),
        );
    // Let _checkAudioState run (creates empty DB, finds no episode, sets state to none)
    await tester.pumpAndSettle();

    // Now _lastCheckedFileKey is set, subsequent calls return early
    // Set the desired state
    container.read(ttsAudioStateProvider.notifier).set(TtsAudioState.ready);
    container
        .read(ttsPlaybackStateProvider.notifier)
        .set(TtsPlaybackState.stopped);
  }

  group('TTS Export Button', () {
    testWidgets('shows download button when audioState is ready and stopped',
        (WidgetTester tester) async {
      await setupReadyState(tester);
      await tester.pump();

      expect(find.byIcon(Icons.download), findsOneWidget);
      expect(find.byTooltip('MP3エクスポート'), findsOneWidget);
    });

    testWidgets('does not show download button when audioState is none',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider.overrideWith((ref) async => 'テスト内容'),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.download), findsNothing);
    });

    testWidgets('does not show download button when audioState is generating',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider.overrideWith((ref) async => 'テスト内容'),
            selectedFileProvider.overrideWith(() {
              final notifier = SelectedFileNotifier();
              return notifier;
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory(tempDir.path);
      container.read(selectedFileProvider.notifier).selectFile(
            FileEntry(name: 'test.txt', path: '${tempDir.path}/test.txt'),
          );
      await tester.pumpAndSettle();

      container
          .read(ttsAudioStateProvider.notifier)
          .set(TtsAudioState.generating);
      await tester.pump();

      expect(find.byIcon(Icons.download), findsNothing);
    });

    testWidgets(
        'shows progress indicator instead of download button during export',
        (WidgetTester tester) async {
      await setupReadyState(tester);

      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      container
          .read(ttsExportStateProvider.notifier)
          .set(TtsExportState.exporting);
      await tester.pump();

      expect(find.byIcon(Icons.download), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
        'shows determinate progress when export progress is available',
        (WidgetTester tester) async {
      await setupReadyState(tester);

      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      container
          .read(ttsExportStateProvider.notifier)
          .set(TtsExportState.exporting);
      container
          .read(ttsExportProgressProvider.notifier)
          .set(const TtsGenerationProgress(current: 3, total: 10));
      await tester.pump();

      final progressFinder = find.byType(CircularProgressIndicator);
      expect(progressFinder, findsOneWidget);

      final progressWidget =
          tester.widget<CircularProgressIndicator>(progressFinder);
      expect(progressWidget.value, closeTo(0.3, 0.01));
    });
  });
}
