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
import 'package:novel_viewer/l10n/app_localizations.dart';

import '../../../test_utils/flutter_secure_storage_mock.dart';

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;
  late FlutterSecureStorageMock secureStorageMock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('tts_ui_test_');
    secureStorageMock = FlutterSecureStorageMock();
    secureStorageMock.install();
  });

  tearDown(() {
    secureStorageMock.uninstall();
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
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
      // Models now go in size-specific subdirectory
      final modelsDir =
          Directory(p.join(tempDir.path, 'models', '0.6b'))
            ..createSync(recursive: true);
      File(p.join(modelsDir.path, 'qwen3-tts-0.6b-f16.gguf'))
          .writeAsStringSync('model');
      File(p.join(modelsDir.path, 'qwen3-tts-tokenizer-f16.gguf'))
          .writeAsStringSync('tokenizer');
      File(p.join(modelsDir.path, '.tts_models_complete'))
          .writeAsStringSync('done');

      await tester.pumpWidget(buildTestWidget());
      await navigateToTtsTab(tester);

      expect(find.text('モデルダウンロード済み'), findsOneWidget);
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

    testWidgets('displays model size selector', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await navigateToTtsTab(tester);

      expect(find.text('高速 (0.6B)'), findsOneWidget);
      expect(find.text('高精度 (1.7B)'), findsOneWidget);
    });
  });
}
