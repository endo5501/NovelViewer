import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
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
      http.Client? httpClient,
    }) async {
      SharedPreferences.setMockInitialValues(prefsValues);
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            if (httpClient != null)
              httpClientProvider.overrideWithValue(httpClient),
          ],
          child: const MaterialApp(home: Scaffold(body: SettingsDialog())),
        ),
      );
    }

    // Helper to pump dialog and wait for async fetch to complete
    Future<void> pumpSettingsDialogWithOllama(
      WidgetTester tester, {
      required Map<String, Object> prefsValues,
      required http.Client httpClient,
    }) async {
      SharedPreferences.setMockInitialValues(prefsValues);
      final prefs = await SharedPreferences.getInstance();

      final scope = ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
          httpClientProvider.overrideWithValue(httpClient),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsDialog())),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(scope);
        // Allow the async fetch to complete
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
    }

    MockClient createMockOllamaClient({
      List<String> modelNames = const ['gemma3', 'qwen3:8b'],
    }) {
      return MockClient((request) async {
        if (request.url.path == '/api/tags') {
          return http.Response(
            jsonEncode({
              'models': modelNames
                  .map((name) => {'name': name, 'size': 1000000})
                  .toList(),
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });
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

    testWidgets('shows Ollama model dropdown when Ollama provider selected',
        (tester) async {
      final mockClient = createMockOllamaClient();
      await pumpSettingsDialogWithOllama(
        tester,
        prefsValues: {
          'llm_provider': 'ollama',
          'llm_base_url': 'http://localhost:11434',
          'llm_api_key': '',
          'llm_model': '',
        },
        httpClient: mockClient,
      );

      expect(find.text(labelEndpointUrl), findsOneWidget);
      // Should show a String dropdown (model selector), not a text field for model name
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      // Ollama doesn't show API key field
      expect(find.text(labelApiKey), findsNothing);

      // Open the model dropdown and verify fetched models are listed
      await tester.ensureVisible(find.byType(DropdownButton<String>));
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('gemma3'), findsOneWidget);
      expect(find.text('qwen3:8b'), findsOneWidget);
    });

    testWidgets('auto-fetches models when Ollama is selected',
        (tester) async {
      final mockClient = createMockOllamaClient();
      await pumpSettingsDialog(tester, httpClient: mockClient);

      // Initially "未設定" - no fields shown
      expect(find.text(labelEndpointUrl), findsNothing);

      // Open dropdown and select Ollama
      await tester.ensureVisible(find.text(labelUnset));
      await tester.tap(find.text(labelUnset));
      await tester.pumpAndSettle();
      await tester.tap(find.text(providerOllama).last);

      // Allow the async fetch triggered by selection to complete
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      // Now Ollama fields should be shown with model dropdown
      expect(find.text(labelEndpointUrl), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);

      // Open the model dropdown and verify fetched models
      await tester.ensureVisible(find.byType(DropdownButton<String>));
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('gemma3'), findsOneWidget);
    });

    testWidgets('shows error when model fetch fails', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });
      await pumpSettingsDialogWithOllama(
        tester,
        prefsValues: {
          'llm_provider': 'ollama',
          'llm_base_url': 'http://localhost:11434',
          'llm_api_key': '',
          'llm_model': '',
        },
        httpClient: mockClient,
      );

      // Should show error message
      expect(find.textContaining('エラー'), findsOneWidget);
    });

    testWidgets('refresh button re-fetches model list', (tester) async {
      final mockClient = createMockOllamaClient();
      await pumpSettingsDialogWithOllama(
        tester,
        prefsValues: {
          'llm_provider': 'ollama',
          'llm_base_url': 'http://localhost:11434',
          'llm_api_key': '',
          'llm_model': '',
        },
        httpClient: mockClient,
      );

      // Should have a refresh button and a model dropdown
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);

      // Tap the refresh button
      await tester.ensureVisible(find.byIcon(Icons.refresh));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      // Model dropdown should still be present after refresh
      expect(find.byType(DropdownButton<String>), findsOneWidget);

      // Open the dropdown and verify models are still there
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('gemma3'), findsOneWidget);
    });

    testWidgets('restores saved model selection', (tester) async {
      final mockClient = createMockOllamaClient();
      await pumpSettingsDialogWithOllama(
        tester,
        prefsValues: {
          'llm_provider': 'ollama',
          'llm_base_url': 'http://localhost:11434',
          'llm_api_key': '',
          'llm_model': 'qwen3:8b',
        },
        httpClient: mockClient,
      );

      // Saved model should be selected in dropdown (visible without opening)
      expect(find.text('qwen3:8b'), findsOneWidget);
    });

    testWidgets('clears selection when saved model is not in list',
        (tester) async {
      final mockClient = createMockOllamaClient();
      await pumpSettingsDialogWithOllama(
        tester,
        prefsValues: {
          'llm_provider': 'ollama',
          'llm_base_url': 'http://localhost:11434',
          'llm_api_key': '',
          'llm_model': 'nonexistent-model',
        },
        httpClient: mockClient,
      );

      // Nonexistent model should not be shown
      expect(find.text('nonexistent-model'), findsNothing);
      // Should show hint instead
      expect(find.text('モデルを選択'), findsOneWidget);
    });
  });
}
