import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('TTS play/stop button', () {
    testWidgets('shows play button when TTS is stopped and model dir is set',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider.overrideWith((ref) async => 'テスト文章です。'),
            ttsModelDirProvider
                .overrideWith(() => _FixedStringNotifier('/models')),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows stop button when TTS is playing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider.overrideWith((ref) async => 'テスト文章です。'),
            ttsModelDirProvider
                .overrideWith(() => _FixedStringNotifier('/models')),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      // Set playback state to playing
      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      container.read(ttsPlaybackStateProvider.notifier).set(
          TtsPlaybackState.playing);
      await tester.pump();

      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('shows loading indicator when TTS is loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider.overrideWith((ref) async => 'テスト文章です。'),
            ttsModelDirProvider
                .overrideWith(() => _FixedStringNotifier('/models')),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      container.read(ttsPlaybackStateProvider.notifier).set(
          TtsPlaybackState.loading);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.stop), findsNothing);
    });

    testWidgets('play button is disabled when model dir is empty',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider.overrideWith((ref) async => 'テスト文章です。'),
            // ttsModelDirProvider defaults to empty string
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      // Play button should not be visible when model dir is not set
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('no play button when no file content', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ttsModelDirProvider
                .overrideWith(() => _FixedStringNotifier('/models')),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      // No content, so no play button
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });
  });
}

class _FixedStringNotifier extends TtsModelDirNotifier {
  _FixedStringNotifier(this._value);
  final String _value;

  @override
  String build() => _value;
}
