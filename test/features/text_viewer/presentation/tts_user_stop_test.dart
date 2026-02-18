import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';

void main() {
  group('VerticalTextViewer - onUserPageChange callback', () {
    testWidgets('arrow key triggers onUserPageChange', (tester) async {
      // Create enough text to span multiple pages
      final longText = List.generate(200, (i) => 'あ').join();
      var callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 400,
              child: VerticalTextViewer(
                segments: [PlainTextSegment(longText)],
                baseStyle: const TextStyle(fontSize: 14),
                onUserPageChange: () {
                  callbackCalled = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify multiple pages exist
      expect(find.textContaining('/'), findsOneWidget);

      // Press left arrow (next page in vertical mode)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(callbackCalled, isTrue);
    });

    testWidgets('mouse wheel triggers onUserPageChange', (tester) async {
      final longText = List.generate(200, (i) => 'あ').join();
      var callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 400,
              child: VerticalTextViewer(
                segments: [PlainTextSegment(longText)],
                baseStyle: const TextStyle(fontSize: 14),
                onUserPageChange: () {
                  callbackCalled = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate mouse wheel scroll
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
          pointer.hover(center));
      await tester.sendEventToBinding(
          pointer.scroll(const Offset(0, 50)));
      await tester.pumpAndSettle();

      expect(callbackCalled, isTrue);
    });

    testWidgets('TTS auto page does NOT trigger onUserPageChange',
        (tester) async {
      final longText = List.generate(200, (i) => 'あ').join();
      var callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 400,
              child: VerticalTextViewer(
                segments: [PlainTextSegment(longText)],
                baseStyle: const TextStyle(fontSize: 14),
                onUserPageChange: () {
                  callbackCalled = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Update with TTS highlight to trigger auto page navigation
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 400,
              child: VerticalTextViewer(
                segments: [PlainTextSegment(longText)],
                baseStyle: const TextStyle(fontSize: 14),
                ttsHighlightStart: 190,
                ttsHighlightEnd: 200,
                onUserPageChange: () {
                  callbackCalled = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // TTS auto page should NOT trigger onUserPageChange
      expect(callbackCalled, isFalse);
    });
  });

  group('TextViewerPanel - user interaction stops TTS', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('arrow key in vertical mode stops TTS', (tester) async {
      final longText =
          List.generate(100, (i) => '行${i + 1}: テストテキスト内容').join('\n');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider.overrideWith((ref) async => longText),
            ttsModelDirProvider
                .overrideWith(() => _FixedStringNotifier('/models')),
            displayModeProvider.overrideWith(() {
              return DisplayModeNotifier();
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                  width: 300, height: 400, child: TextViewerPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to vertical mode
      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      await container
          .read(displayModeProvider.notifier)
          .setMode(TextDisplayMode.vertical);
      await tester.pumpAndSettle();

      // Set TTS to playing
      container
          .read(ttsPlaybackStateProvider.notifier)
          .set(TtsPlaybackState.playing);
      container
          .read(ttsHighlightRangeProvider.notifier)
          .set(const TextRange(start: 0, end: 10));
      await tester.pump();

      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.playing);

      // Press left arrow to change page
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      // TTS should be stopped
      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.stopped);
      expect(container.read(ttsHighlightRangeProvider), isNull);
    });

    testWidgets('user drag in horizontal mode stops TTS', (tester) async {
      final longText =
          List.generate(200, (i) => '行${i + 1}: テストテキスト内容').join('\n');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider.overrideWith((ref) async => longText),
            ttsModelDirProvider
                .overrideWith(() => _FixedStringNotifier('/models')),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(height: 400, child: TextViewerPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set TTS to playing
      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      container
          .read(ttsPlaybackStateProvider.notifier)
          .set(TtsPlaybackState.playing);
      container
          .read(ttsHighlightRangeProvider.notifier)
          .set(const TextRange(start: 0, end: 10));
      await tester.pump();

      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.playing);

      // Drag to scroll (user-initiated scroll)
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -100));
      await tester.pumpAndSettle();

      // TTS should be stopped
      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.stopped);
      expect(container.read(ttsHighlightRangeProvider), isNull);
    });
  });
}

class _FixedStringNotifier extends TtsModelDirNotifier {
  _FixedStringNotifier(this._value);
  final String _value;

  @override
  String build() => _value;
}
