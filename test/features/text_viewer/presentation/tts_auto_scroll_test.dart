import 'dart:ui';

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

  group('TextViewerPanel - TTS auto scroll (horizontal)', () {
    testWidgets('scrolls to TTS highlight position', (tester) async {
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

      // Get initial scroll offset
      final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView));
      expect(scrollView.controller!.offset, 0.0);

      // Set TTS highlight to a position deep in the text
      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);

      // Calculate offset for line ~150
      final offset = longText.indexOf('行150');
      container.read(ttsHighlightRangeProvider.notifier).set(
          TextRange(start: offset, end: offset + 10));
      await tester.pumpAndSettle();

      // Should have scrolled down
      expect(scrollView.controller!.offset, greaterThan(0.0));
    });
  });
}

class _FixedStringNotifier extends TtsModelDirNotifier {
  _FixedStringNotifier(this._value);
  final String _value;

  @override
  String build() => _value;
}
