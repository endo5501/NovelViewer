import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:flutter/material.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/library'),
        ],
        child: const NovelViewerApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(NovelViewerApp)),
    );
  }

  Future<void> pressCtrlT(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
  }

  testWidgets('Ctrl+T issues a TTS toggle request', (WidgetTester tester) async {
    final container = await pumpApp(tester);

    expect(container.read(ttsToggleRequestProvider), 0);
    await pressCtrlT(tester);
    expect(container.read(ttsToggleRequestProvider), 1);
    await pressCtrlT(tester);
    expect(container.read(ttsToggleRequestProvider), 2);
  });

  testWidgets('Escape stops TTS when playing and search field not focused',
      (WidgetTester tester) async {
    final container = await pumpApp(tester);

    container.read(ttsPlaybackStateProvider.notifier).set(
          TtsPlaybackState.playing,
        );
    await tester.pump();

    final before = container.read(ttsStopRequestProvider);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(container.read(ttsStopRequestProvider), before + 1,
        reason: 'Escape requests a TTS stop when playing');
  });

  testWidgets('Escape stops TTS while focus is on the novel body text',
      (WidgetTester tester) async {
    // Regression: SelectableText is a read-only EditableText. Focus landing on
    // the novel body (e.g. right after the window regains focus) must NOT block
    // Escape from stopping TTS.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/library'),
          fileContentProvider.overrideWith((ref) async => '小説の本文です。' * 50),
        ],
        child: const NovelViewerApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NovelViewerApp)),
    );

    // Focus the novel body text (read-only SelectableText / EditableText).
    await tester.tap(find.byType(SelectableText).first);
    await tester.pump();
    expect(find.byType(EditableText), findsWidgets);

    container.read(ttsPlaybackStateProvider.notifier).set(
          TtsPlaybackState.playing,
        );
    await tester.pump();
    final before = container.read(ttsStopRequestProvider);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(container.read(ttsStopRequestProvider), before + 1,
        reason: 'Escape stops TTS even when SelectableText holds focus');
  });

  testWidgets('Escape does nothing to TTS when stopped',
      (WidgetTester tester) async {
    final container = await pumpApp(tester);

    expect(container.read(ttsPlaybackStateProvider), TtsPlaybackState.stopped);
    final before = container.read(ttsStopRequestProvider);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(container.read(ttsStopRequestProvider), before,
        reason: 'No stop request when nothing is playing');
  });
}
