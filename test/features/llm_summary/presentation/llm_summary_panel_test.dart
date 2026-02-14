import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_panel.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LlmSummaryPanel', () {
    testWidgets('displays two tabs', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: Scaffold(body: LlmSummaryPanel())),
        ),
      );

      expect(find.text('ネタバレなし'), findsOneWidget);
      expect(find.text('ネタバレあり'), findsOneWidget);
    });

    testWidgets('shows "select word" message when no word selected',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: Scaffold(body: LlmSummaryPanel())),
        ),
      );

      expect(find.text('単語を選択してください'), findsOneWidget);
    });

    testWidgets('shows "configure LLM" message when LLM not configured',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            selectedTextProvider.overrideWith(
              () => _MockSelectedTextNotifier('アリス'),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: LlmSummaryPanel())),
        ),
      );

      expect(find.text('設定画面でLLMを設定してください'), findsOneWidget);
    });

    testWidgets('shows analyze button when word selected and LLM configured',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'llm_provider': 'ollama',
        'llm_base_url': 'http://localhost:11434',
        'llm_api_key': '',
        'llm_model': 'llama3',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            selectedTextProvider.overrideWith(
              () => _MockSelectedTextNotifier('アリス'),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: LlmSummaryPanel())),
        ),
      );

      expect(find.text('解析開始'), findsOneWidget);
    });

    testWidgets('shows cached summary when available', (tester) async {
      SharedPreferences.setMockInitialValues({
        'llm_provider': 'ollama',
        'llm_base_url': 'http://localhost:11434',
        'llm_api_key': '',
        'llm_model': 'llama3',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            selectedTextProvider.overrideWith(
              () => _MockSelectedTextNotifier('アリス'),
            ),
            llmNoSpoilerSummaryProvider.overrideWith(
              () => _MockLlmSummaryNotifier(
                const LlmSummaryState(currentSummary: 'アリスは主人公の少女。'),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: LlmSummaryPanel())),
        ),
      );

      expect(find.text('アリスは主人公の少女。'), findsOneWidget);
    });

    testWidgets('tab switching works', (tester) async {
      SharedPreferences.setMockInitialValues({
        'llm_provider': 'ollama',
        'llm_base_url': 'http://localhost:11434',
        'llm_api_key': '',
        'llm_model': 'llama3',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            selectedTextProvider.overrideWith(
              () => _MockSelectedTextNotifier('アリス'),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: LlmSummaryPanel())),
        ),
      );

      // Tap on the "ネタバレあり" tab
      await tester.tap(find.text('ネタバレあり'));
      await tester.pumpAndSettle();

      // Both tabs should still be visible
      expect(find.text('ネタバレなし'), findsOneWidget);
      expect(find.text('ネタバレあり'), findsOneWidget);
    });
  });
}

class _MockSelectedTextNotifier extends SelectedTextNotifier {
  final String? _value;
  _MockSelectedTextNotifier(this._value);

  @override
  String? build() => _value;
}

class _MockLlmSummaryNotifier extends LlmSummaryNotifier {
  final LlmSummaryState _state;
  _MockLlmSummaryNotifier(this._state);

  @override
  LlmSummaryState build() => _state;
}
