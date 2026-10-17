import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/presentation/sections/piper_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/voice_reference_section.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The engine selector offers only the engines the platform runs, and is not
/// shown at all where there is just one: on iOS the TTS tab opens straight on
/// the Piper settings, with no voice-reference section (spec
/// tts-engine-selection, tts-settings).
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> openTtsTab(
    WidgetTester tester,
    PlatformCapabilities capabilities,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
          platformCapabilitiesProvider.overrideWithValue(capabilities),
          packageInfoProvider.overrideWithValue(
            PackageInfo(
              appName: 'NovelViewer',
              packageName: 'com.endo5501.novelViewer',
              version: '1.8.4',
              buildNumber: '19',
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SettingsDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('読み上げ'));
    await tester.pumpAndSettle();
  }

  List<TtsEngineType> offeredEngines(WidgetTester tester) => tester
      .widget<SegmentedButton<TtsEngineType>>(
        find.byType(SegmentedButton<TtsEngineType>),
      )
      .segments
      .map((s) => s.value)
      .toList();

  testWidgets('iOS shows the Piper settings without an engine selector', (
    tester,
  ) async {
    await openTtsTab(
      tester,
      const PlatformCapabilities.forPlatform(isIOS: true, isMacOS: false),
    );

    expect(find.byType(SegmentedButton<TtsEngineType>), findsNothing);
    expect(find.byType(PiperSettingsSection), findsOneWidget);
    expect(find.byType(VoiceReferenceSection), findsNothing);
  });

  testWidgets('a desktop platform offers all three engines', (tester) async {
    await openTtsTab(
      tester,
      const PlatformCapabilities.forPlatform(isIOS: false, isMacOS: false),
    );

    expect(offeredEngines(tester), [
      TtsEngineType.qwen3,
      TtsEngineType.piper,
      TtsEngineType.irodori,
    ]);
  });

  testWidgets('only the supported engines are offered', (tester) async {
    await openTtsTab(
      tester,
      const PlatformCapabilities(
        piperTts: true,
        qwen3Tts: false,
        irodoriTts: true,
        ttsAudioExport: true,
        appUpdate: true,
        llmSummary: true,
        onDeviceLlm: false,
      ),
    );

    expect(offeredEngines(tester), [
      TtsEngineType.piper,
      TtsEngineType.irodori,
    ]);
  });
}
