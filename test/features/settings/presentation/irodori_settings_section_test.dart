import 'dart:async';
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
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/providers/irodori_model_download_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

import '../../../test_utils/flutter_secure_storage_mock.dart';

/// Widget tests for `IrodoriSettingsSection` (tasks 7.1/7.2 of
/// add-irodori-tts-engine): the 3-value engine selector, section visibility
/// switching, model download states and parameter sliders.
void main() {
  late SharedPreferences prefs;
  late Directory tempDir;
  late FlutterSecureStorageMock secureStorageMock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('irodori_section_test_');
    Directory(p.join(tempDir.path, 'NovelViewer')).createSync();
    secureStorageMock = FlutterSecureStorageMock();
    secureStorageMock.install();
  });

  tearDown(() {
    secureStorageMock.uninstall();
    tempDir.deleteSync(recursive: true);
  });

  Widget buildTestWidget({
    http.Client? httpClient,
    Map<String, int>? expectedFileSizes,
  }) {
    final libraryPath = p.join(tempDir.path, 'NovelViewer');
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryPathProvider.overrideWithValue(libraryPath),
        if (httpClient != null)
          httpClientProvider.overrideWithValue(httpClient),
        // Real manifest entries are multi-hundred-megabyte-to-gigabyte
        // constants; tests that exercise a real download/completion state
        // override this with small sizes matching their fixture bytes.
        if (expectedFileSizes != null)
          irodoriExpectedFileSizesProvider.overrideWithValue(
            expectedFileSizes,
          ),
      ],
      child: const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(width: 800, height: 600, child: SettingsDialog()),
        ),
      ),
    );
  }

  Future<AppLocalizations> openTtsTab(
    WidgetTester tester, {
    http.Client? httpClient,
    Map<String, int>? expectedFileSizes,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestWidget(
        httpClient: httpClient,
        expectedFileSizes: expectedFileSizes,
      ));
    });
    await tester.pumpAndSettle();
    final l10n =
        AppLocalizations.of(tester.element(find.byType(SettingsDialog)))!;
    await tester.tap(find.text(l10n.settings_ttsTabLabel));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  Future<AppLocalizations> selectIrodoriEngine(
    WidgetTester tester, {
    http.Client? httpClient,
    Map<String, int>? expectedFileSizes,
  }) async {
    final l10n = await openTtsTab(
      tester,
      httpClient: httpClient,
      expectedFileSizes: expectedFileSizes,
    );
    await tester.tap(find.text('Irodori-TTS'));
    await tester.pumpAndSettle();
    return l10n;
  }

  group('Engine selector', () {
    testWidgets('shows three segments: Qwen3-TTS, Piper, Irodori-TTS',
        (tester) async {
      await openTtsTab(tester);

      expect(find.byType(SegmentedButton<TtsEngineType>), findsOneWidget);
      expect(find.text('Qwen3-TTS'), findsOneWidget);
      expect(find.text('Piper'), findsOneWidget);
      expect(find.text('Irodori-TTS'), findsOneWidget);
    });

    testWidgets('selecting Irodori-TTS updates the provider', (tester) async {
      await openTtsTab(tester);

      await tester.tap(find.text('Irodori-TTS'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsDialog)),
      );
      expect(container.read(ttsEngineTypeProvider), TtsEngineType.irodori);
    });
  });

  group('Section visibility', () {
    testWidgets(
        'selecting Irodori shows IrodoriSettingsSection and voice reference, '
        'hides qwen3/piper settings', (tester) async {
      final l10n = await selectIrodoriEngine(tester);

      // Irodori-specific controls are visible.
      expect(find.text(l10n.settings_modelDataDownload), findsOneWidget);
      expect(
          find.textContaining(l10n.settings_irodoriSpeakerGuidanceScale),
          findsOneWidget);
      expect(
          find.textContaining(l10n.settings_irodoriCaptionGuidanceScale),
          findsOneWidget);
      expect(
          find.textContaining(l10n.settings_irodoriNumInferenceSteps),
          findsOneWidget);
      // Shared voice reference selector is shown (same as qwen3).
      expect(find.text(l10n.settings_referenceAudioLabel), findsOneWidget);

      // qwen3-specific settings are hidden.
      expect(find.text(l10n.settings_ttsLanguageLabel), findsNothing);
      expect(find.text(l10n.settings_voiceModelTitle), findsNothing);

      // piper-specific settings are hidden.
      expect(find.textContaining(l10n.settings_piperLengthScale), findsNothing);
      expect(find.textContaining(l10n.settings_piperNoiseScale), findsNothing);
      expect(find.textContaining(l10n.settings_piperNoiseW), findsNothing);
    });

    testWidgets('selecting qwen3 hides Irodori settings', (tester) async {
      final l10n = await selectIrodoriEngine(tester);
      await tester.tap(find.text('Qwen3-TTS'));
      await tester.pumpAndSettle();

      expect(
          find.textContaining(l10n.settings_irodoriSpeakerGuidanceScale),
          findsNothing);
      expect(
          find.textContaining(l10n.settings_irodoriCaptionGuidanceScale),
          findsNothing);
      expect(
          find.textContaining(l10n.settings_irodoriNumInferenceSteps),
          findsNothing);
    });
  });

  group('Model download section', () {
    testWidgets('shows download button in idle state', (tester) async {
      final l10n = await selectIrodoriEngine(tester);

      expect(find.text(l10n.settings_modelDataDownload), findsOneWidget);
    });

    testWidgets('shows completed status when models already exist',
        (tester) async {
      final modelsDir = p.join(tempDir.path, 'models');
      Directory(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign'))
          .createSync(recursive: true);
      Directory(p.join(modelsDir, 'llm-jp-3-150m')).createSync();
      Directory(p.join(modelsDir, 'Semantic-DACVAE-Japanese-32dim'))
          .createSync();
      File(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign',
              'model.safetensors'))
          .writeAsStringSync('model');
      File(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign',
              'model_config.json'))
          .writeAsStringSync('config');
      File(p.join(modelsDir, 'llm-jp-3-150m', 'tokenizer.json'))
          .writeAsStringSync('tokenizer');
      File(p.join(
              modelsDir, 'Semantic-DACVAE-Japanese-32dim', 'weights.safetensors'))
          .writeAsStringSync('weights');

      final l10n = await selectIrodoriEngine(
        tester,
        expectedFileSizes: const {
          'Irodori-TTS-600M-v3-VoiceDesign/model.safetensors': 5, // 'model'
          'Irodori-TTS-600M-v3-VoiceDesign/model_config.json': 6, // 'config'
          'llm-jp-3-150m/tokenizer.json': 9, // 'tokenizer'
          'Semantic-DACVAE-Japanese-32dim/weights.safetensors': 7, // 'weights'
        },
      );

      expect(
          find.textContaining(l10n.settings_irodoriDownloaded), findsOneWidget);
    });

    testWidgets('starts download when button is pressed', (tester) async {
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      final l10n = await selectIrodoriEngine(
        tester,
        httpClient: mockClient,
        expectedFileSizes: const {
          'Irodori-TTS-600M-v3-VoiceDesign/model.safetensors': 3,
          'Irodori-TTS-600M-v3-VoiceDesign/model_config.json': 3,
          'llm-jp-3-150m/tokenizer.json': 3,
          'Semantic-DACVAE-Japanese-32dim/weights.safetensors': 3,
        },
      );

      await tester.runAsync(() async {
        await tester.tap(find.text(l10n.settings_modelDataDownload));
        // Give the (fast, in-memory) download time to reach a terminal
        // state before pumping settle.
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(
          find.textContaining(l10n.settings_irodoriDownloaded), findsOneWidget);
    });

    testWidgets(
        'shows a cancel button while downloading, and tapping it returns '
        'to the idle (download) state', (tester) async {
      final chunkController = StreamController<List<int>>();
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          chunkController.stream,
          200,
          contentLength: 100,
        );
      });

      final l10n =
          await selectIrodoriEngine(tester, httpClient: mockClient);

      await tester.runAsync(() async {
        await tester.tap(find.text(l10n.settings_modelDataDownload));
        // Give the download time to reach the Downloading state and start
        // awaiting the (empty, still-open) response stream.
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(find.text(l10n.common_cancelButton), findsOneWidget);

      // Cancellation is only observed once the download's stream loop wakes
      // up on a chunk (or close), same as the service-level cancel test —
      // so the tap, the wake-up chunk, and the close all happen inside a
      // single runAsync call (a second, separate runAsync call while one is
      // still pending is rejected by the test framework).
      await tester.runAsync(() async {
        await tester.tap(find.text(l10n.common_cancelButton));
        chunkController.add(List.filled(10, 0));
        await Future.delayed(const Duration(milliseconds: 300));
        await chunkController.close();
      });
      await tester.pumpAndSettle();

      expect(find.text(l10n.settings_modelDataDownload), findsOneWidget);
      expect(find.text(l10n.common_cancelButton), findsNothing);
    });

    testWidgets('shows error with retry on download failure', (tester) async {
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(Stream.value([]), 404);
      });

      final l10n =
          await selectIrodoriEngine(tester, httpClient: mockClient);

      await tester.runAsync(() async {
        await tester.tap(find.text(l10n.settings_modelDataDownload));
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(find.text(l10n.settings_retryButton), findsOneWidget);
    });
  });

  group('Synthesis parameter sliders', () {
    testWidgets('shows three sliders with default values', (tester) async {
      await selectIrodoriEngine(tester);

      expect(find.byType(Slider), findsNWidgets(3));
      // Defaults per design D9 / tts_settings_providers.
      expect(find.textContaining('5.0'), findsOneWidget);
      expect(find.textContaining('3.0'), findsOneWidget);
      expect(find.textContaining('40'), findsOneWidget);
    });

    testWidgets('changing speaker_guidance_scale slider persists via provider',
        (tester) async {
      await selectIrodoriEngine(tester);

      final slider = find.byType(Slider).first;
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      await tester.drag(slider, const Offset(80, 0));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsDialog)),
      );
      expect(
        container.read(irodoriSpeakerGuidanceScaleProvider),
        isNot(5.0),
      );
    });

    testWidgets(
        'changing num_inference_steps slider persists via provider',
        (tester) async {
      await selectIrodoriEngine(tester);

      final slider = find.byType(Slider).at(2);
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      await tester.drag(slider, const Offset(-80, 0));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsDialog)),
      );
      expect(
        container.read(irodoriNumInferenceStepsProvider),
        isNot(40),
      );
    });
  });
}
