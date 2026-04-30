import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/tts_controls_bar.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_state_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_export_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart'
    show ttsModelDirProvider;
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = await Directory.systemTemp.createTemp('tts_controls_bar_test_');
  });

  tearDown(() async {
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

  Future<ProviderContainer> pumpBar(
    WidgetTester tester, {
    required TtsAudioState audioState,
    required TtsPlaybackState playbackState,
    String modelDir = '/tmp/tts_model',
    String content = 'テスト内容',
    bool fileSelected = true,
  }) async {
    final filePath =
        fileSelected ? '${tempDir.path}/test.txt' : null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
          ttsAudioStateProvider.overrideWith((ref, _) async => audioState),
          ttsModelDirProvider.overrideWith((ref) => modelDir),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TtsControlsBar(content: content),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(TtsControlsBar));
    final container = ProviderScope.containerOf(element);

    if (fileSelected) {
      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory(tempDir.path);
      container.read(selectedFileProvider.notifier).selectFile(
            FileEntry(name: 'test.txt', path: filePath!),
          );
    }
    container.read(ttsPlaybackStateProvider.notifier).set(playbackState);
    // Use pump() rather than pumpAndSettle: the waiting/generating states
    // include a CircularProgressIndicator that never settles.
    await tester.pump();
    await tester.pump();

    return container;
  }

  group('TtsControlsBar visibility gating', () {
    testWidgets('hides everything when ttsModelDir is empty',
        (tester) async {
      await pumpBar(tester,
          audioState: TtsAudioState.ready,
          playbackState: TtsPlaybackState.stopped,
          modelDir: '');
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('TtsControlsBar state machine', () {
    testWidgets('(none, stopped): shows edit + play (record_voice_over)',
        (tester) async {
      await pumpBar(tester,
          audioState: TtsAudioState.none,
          playbackState: TtsPlaybackState.stopped);
      expect(find.byIcon(Icons.edit_note), findsOneWidget);
      expect(find.byIcon(Icons.record_voice_over), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsNothing);
    });

    testWidgets('(ready, stopped): shows edit + play + export + delete',
        (tester) async {
      await pumpBar(tester,
          audioState: TtsAudioState.ready,
          playbackState: TtsPlaybackState.stopped);
      expect(find.byIcon(Icons.edit_note), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('(ready, playing): shows pause + stop only', (tester) async {
      await pumpBar(tester,
          audioState: TtsAudioState.ready,
          playbackState: TtsPlaybackState.playing);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.download), findsNothing);
    });

    testWidgets('(ready, paused): shows resume + stop only', (tester) async {
      await pumpBar(tester,
          audioState: TtsAudioState.ready,
          playbackState: TtsPlaybackState.paused);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('(ready, waiting): shows pause + stop with spinner',
        (tester) async {
      await pumpBar(tester,
          audioState: TtsAudioState.ready,
          playbackState: TtsPlaybackState.waiting);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    });

    testWidgets('(generating, stopped): shows progress + cancel only',
        (tester) async {
      await pumpBar(tester,
          audioState: TtsAudioState.generating,
          playbackState: TtsPlaybackState.stopped);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('(generating, playing): shows progress + pause + stop',
        (tester) async {
      await pumpBar(tester,
          audioState: TtsAudioState.generating,
          playbackState: TtsPlaybackState.playing);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('(generating, paused): shows progress + resume + stop',
        (tester) async {
      await pumpBar(tester,
          audioState: TtsAudioState.generating,
          playbackState: TtsPlaybackState.paused);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('(generating, waiting): shows progress + spinner + pause + stop',
        (tester) async {
      await pumpBar(tester,
          audioState: TtsAudioState.generating,
          playbackState: TtsPlaybackState.waiting);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    });
  });

  group('TtsControlsBar export progress indicator', () {
    testWidgets('replaces export icon with circular progress while exporting',
        (tester) async {
      final container = await pumpBar(tester,
          audioState: TtsAudioState.ready,
          playbackState: TtsPlaybackState.stopped);
      container
          .read(ttsExportStateProvider.notifier)
          .set(TtsExportState.exporting);
      await tester.pump();

      expect(find.byIcon(Icons.download), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
