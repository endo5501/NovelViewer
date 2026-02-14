import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsDialog LLM settings', () {
    testWidgets('displays LLM provider dropdown', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: Scaffold(body: SettingsDialog())),
        ),
      );

      expect(find.text('LLMプロバイダ'), findsOneWidget);
      expect(find.text('未設定'), findsOneWidget);
    });

    testWidgets('shows OpenAI fields when OpenAI provider selected',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'llm_provider': 'openai',
        'llm_base_url': 'https://api.openai.com/v1',
        'llm_api_key': 'sk-test',
        'llm_model': 'gpt-4o-mini',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: Scaffold(body: SettingsDialog())),
        ),
      );

      expect(find.text('エンドポイントURL'), findsOneWidget);
      expect(find.text('APIキー'), findsOneWidget);
      expect(find.text('モデル名'), findsOneWidget);
    });

    testWidgets('shows Ollama fields when Ollama provider selected',
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
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: Scaffold(body: SettingsDialog())),
        ),
      );

      expect(find.text('エンドポイントURL'), findsOneWidget);
      expect(find.text('モデル名'), findsOneWidget);
      // Ollama doesn't show API key field
      expect(find.text('APIキー'), findsNothing);
    });

    testWidgets('changing provider updates displayed fields', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: Scaffold(body: SettingsDialog())),
        ),
      );

      // Initially "未設定" - no fields shown
      expect(find.text('エンドポイントURL'), findsNothing);

      // Open dropdown and select Ollama
      await tester.tap(find.text('未設定'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ollama').last);
      await tester.pumpAndSettle();

      // Now Ollama fields should be shown
      expect(find.text('エンドポイントURL'), findsOneWidget);
      expect(find.text('モデル名'), findsOneWidget);
    });
  });
}
