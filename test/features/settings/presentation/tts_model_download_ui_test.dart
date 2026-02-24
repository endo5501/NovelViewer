import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('tts_ui_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget buildTestWidget({http.Client? httpClient}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryPathProvider
            .overrideWithValue('${tempDir.path}/NovelViewer'),
        if (httpClient != null)
          httpClientProvider.overrideWithValue(httpClient),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SettingsDialog()),
      ),
    );
  }

  Future<void> navigateToTtsTab(WidgetTester tester) async {
    await tester.tap(find.text('読み上げ'));
    await tester.pumpAndSettle();
  }

  group('TTS model download section', () {
    testWidgets('shows download button when models not downloaded',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await navigateToTtsTab(tester);

      expect(find.text('モデルデータダウンロード'), findsOneWidget);
    });

    testWidgets('shows completed status when models already exist',
        (tester) async {
      final modelsDir = Directory('${tempDir.path}/models')..createSync();
      File('${modelsDir.path}/qwen3-tts-0.6b-f16.gguf')
          .writeAsStringSync('model');
      File('${modelsDir.path}/qwen3-tts-tokenizer-f16.gguf')
          .writeAsStringSync('tokenizer');
      File('${modelsDir.path}/.tts_models_complete')
          .writeAsStringSync('done');

      await tester.pumpWidget(buildTestWidget());
      await navigateToTtsTab(tester);

      expect(find.text('モデルダウンロード済み'), findsOneWidget);
      expect(find.text(p.join(tempDir.path, 'models')), findsOneWidget);
    });

    testWidgets('starts download when button is pressed', (tester) async {
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      await tester.pumpWidget(buildTestWidget(httpClient: mockClient));
      await navigateToTtsTab(tester);

      await tester.runAsync(() async {
        await tester.tap(find.text('モデルデータダウンロード'));
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // After download completes, should show completed status
      expect(find.text('モデルダウンロード済み'), findsOneWidget);
    });

    testWidgets('shows error with retry on download failure', (tester) async {
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(Stream.value([]), 404);
      });

      await tester.pumpWidget(buildTestWidget(httpClient: mockClient));
      await navigateToTtsTab(tester);

      await tester.runAsync(() async {
        await tester.tap(find.text('モデルデータダウンロード'));
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('エラー'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    });

    testWidgets('auto-fills model directory after download', (tester) async {
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      await tester.pumpWidget(buildTestWidget(httpClient: mockClient));
      await navigateToTtsTab(tester);

      await tester.runAsync(() async {
        await tester.tap(find.text('モデルデータダウンロード'));
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Model directory text field should be auto-filled
      final expectedPath = p.join(tempDir.path, 'models');
      final textField = tester.widget<TextField>(
        find.widgetWithText(TextField, expectedPath),
      );
      expect(textField.controller?.text, expectedPath);
    });
  });
}
