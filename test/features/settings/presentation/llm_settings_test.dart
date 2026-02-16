import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsDialog LLM settings', () {
    // Common test labels
    const labelEndpointUrl = 'エンドポイントURL';
    const labelApiKey = 'APIキー';
    const labelModel = 'モデル名';
    const labelProvider = 'LLMプロバイダ';
    const labelUnset = '未設定';
    const providerOllama = 'Ollama';

    // Helper function to reduce boilerplate setup
    Future<void> pumpSettingsDialog(
      WidgetTester tester, {
      Map<String, Object> prefsValues = const {},
    }) async {
      SharedPreferences.setMockInitialValues(prefsValues);
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: Scaffold(body: SettingsDialog())),
        ),
      );
    }

    testWidgets('displays LLM provider dropdown', (tester) async {
      await pumpSettingsDialog(tester);

      expect(find.text(labelProvider), findsOneWidget);
      expect(find.text(labelUnset), findsOneWidget);
    });

    testWidgets('shows OpenAI fields when OpenAI provider selected',
        (tester) async {
      await pumpSettingsDialog(
        tester,
        prefsValues: {
          'llm_provider': 'openai',
          'llm_base_url': 'https://api.openai.com/v1',
          'llm_api_key': 'sk-test',
          'llm_model': 'gpt-4o-mini',
        },
      );

      expect(find.text(labelEndpointUrl), findsOneWidget);
      expect(find.text(labelApiKey), findsOneWidget);
      expect(find.text(labelModel), findsOneWidget);
    });

    testWidgets('shows Ollama fields when Ollama provider selected',
        (tester) async {
      await pumpSettingsDialog(
        tester,
        prefsValues: {
          'llm_provider': 'ollama',
          'llm_base_url': 'http://localhost:11434',
          'llm_api_key': '',
          'llm_model': 'llama3',
        },
      );

      expect(find.text(labelEndpointUrl), findsOneWidget);
      expect(find.text(labelModel), findsOneWidget);
      // Ollama doesn't show API key field
      expect(find.text(labelApiKey), findsNothing);
    });

    testWidgets('changing provider updates displayed fields', (tester) async {
      await pumpSettingsDialog(tester);

      // Initially "未設定" - no fields shown
      expect(find.text(labelEndpointUrl), findsNothing);

      // Open dropdown and select Ollama
      await tester.ensureVisible(find.text(labelUnset));
      await tester.tap(find.text(labelUnset));
      await tester.pumpAndSettle();
      await tester.tap(find.text(providerOllama).last);
      await tester.pumpAndSettle();

      // Now Ollama fields should be shown
      expect(find.text(labelEndpointUrl), findsOneWidget);
      expect(find.text(labelModel), findsOneWidget);
    });
  });
}
