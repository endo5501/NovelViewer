import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_models_llm/foundation_models_llm.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/llm_summary/providers/on_device_llm_providers.dart';
import 'package:novel_viewer/features/settings/presentation/sections/llm_settings_section.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../test_utils/flutter_secure_storage_mock.dart';

/// Never answers, so the section can be caught mid-query.
class _SilentPlugin implements FoundationModelsLlm {
  @override
  Future<OnDeviceModelAvailability> availability() =>
      Completer<OnDeviceModelAvailability>().future;

  @override
  Future<String> generate({
    required String prompt,
    String? schemaFieldName,
    int? maxResponseTokens,
    OnDeviceSampling? sampling,
  }) async => throw UnimplementedError();
}

class _Plugin implements FoundationModelsLlm {
  _Plugin(this.answer);

  final OnDeviceModelAvailability answer;
  int asked = 0;

  @override
  Future<OnDeviceModelAvailability> availability() async {
    asked++;
    return answer;
  }

  @override
  Future<String> generate({
    required String prompt,
    String? schemaFieldName,
    int? maxResponseTokens,
    OnDeviceSampling? sampling,
  }) async => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterSecureStorageMock secureStorageMock;

  setUp(() {
    secureStorageMock = FlutterSecureStorageMock();
    secureStorageMock.install();
  });

  tearDown(() => secureStorageMock.uninstall());

  /// The Japanese strings, looked up rather than transcribed, so rewording a
  /// message does not break these tests.
  late AppLocalizations ja;

  setUpAll(() async {
    ja = await AppLocalizations.delegate.load(const Locale('ja'));
  });

  Future<void> pumpSection(
    WidgetTester tester, {
    required bool platformCanHost,
    required OnDeviceModelAvailability availability,
    Map<String, Object> stored = const {},
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          platformCapabilitiesProvider.overrideWithValue(
            PlatformCapabilities(
              textToSpeech: true,
              appUpdate: true,
              llmSummary: true,
              onDeviceLlm: platformCanHost,
            ),
          ),
          foundationModelsLlmProvider.overrideWithValue(_Plugin(availability)),
        ],
        child: const MaterialApp(
          // Pinned so the assertions below can name the strings they expect.
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: LlmSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The dropdown item for the on-device provider, or null when absent.
  DropdownMenuItem<LlmProvider>? onDeviceItem(WidgetTester tester) {
    final dropdown = tester.widget<DropdownButton<LlmProvider>>(
      find.byType(DropdownButton<LlmProvider>),
    );
    for (final item
        in dropdown.items ?? const <DropdownMenuItem<LlmProvider>>[]) {
      if (item.value == LlmProvider.appleOnDevice) return item;
    }
    return null;
  }

  group('where the platform can host the model', () {
    testWidgets('an available model is selectable and needs no explanation', (
      tester,
    ) async {
      await pumpSection(
        tester,
        platformCanHost: true,
        availability: OnDeviceModelAvailability.available,
      );

      expect(onDeviceItem(tester), isNotNull);
      expect(onDeviceItem(tester)!.enabled, isTrue);
      expect(
        find.text(ja.settings_llmOnDeviceUnavailableIntelligenceOff),
        findsNothing,
      );
    });

    testWidgets('a disabled intelligence feature is shown and explained', (
      tester,
    ) async {
      await pumpSection(
        tester,
        platformCanHost: true,
        availability: OnDeviceModelAvailability.intelligenceNotEnabled,
      );

      expect(onDeviceItem(tester), isNotNull);
      expect(onDeviceItem(tester)!.enabled, isFalse);
      // Readable without opening the list.
      expect(
        find.text(ja.settings_llmOnDeviceUnavailableIntelligenceOff),
        findsOneWidget,
      );
    });

    testWidgets('a model still being prepared says so', (tester) async {
      await pumpSection(
        tester,
        platformCanHost: true,
        availability: OnDeviceModelAvailability.modelNotReady,
      );

      expect(onDeviceItem(tester)!.enabled, isFalse);
      expect(
        find.text(ja.settings_llmOnDeviceUnavailableModelNotReady),
        findsOneWidget,
      );
    });

    testWidgets('an ineligible device is left out, like an unfit platform', (
      tester,
    ) async {
      // Permanent, so there is nothing to tell the reader and nothing they
      // could do about it. A dead entry in the list is only clutter.
      await pumpSection(
        tester,
        platformCanHost: true,
        availability: OnDeviceModelAvailability.deviceNotEligible,
      );

      expect(onDeviceItem(tester), isNull);
      expect(
        find.text(ja.settings_llmOnDeviceUnavailableDeviceNotEligible),
        findsNothing,
      );
    });

    testWidgets('an OS too old to have the model is left out too', (
      tester,
    ) async {
      // The capability model only knows the platform is Apple's; whether the
      // OS carries the framework comes back from the native side.
      await pumpSection(
        tester,
        platformCanHost: true,
        availability: OnDeviceModelAvailability.unsupportedPlatform,
      );

      expect(onDeviceItem(tester), isNull);
      expect(
        find.text(ja.settings_llmOnDeviceUnavailableUnknown),
        findsNothing,
      );
    });

    testWidgets('a reader on a server provider is told nothing about it', (
      tester,
    ) async {
      // The reason belongs to a visible, unusable option. With the option
      // gone there is nothing for it to explain, and a paragraph about Apple
      // Intelligence pinned in an Ollama user's settings is noise.
      await pumpSection(
        tester,
        platformCanHost: true,
        availability: OnDeviceModelAvailability.unsupportedPlatform,
        stored: {'llm_provider': 'ollama'},
      );

      expect(find.byType(Text), findsWidgets);
      expect(
        find.text(ja.settings_llmOnDeviceUnavailableDeviceNotEligible),
        findsNothing,
      );
    });

    testWidgets('a stored on-device selection always keeps its entry', (
      tester,
    ) async {
      // The dropdown asserts that its value matches an item. Dropping the
      // entry for a selection carried over from another machine would take
      // the settings dialog down with it.
      await pumpSection(
        tester,
        platformCanHost: true,
        availability: OnDeviceModelAvailability.deviceNotEligible,
        stored: {'llm_provider': 'appleOnDevice'},
      );

      expect(onDeviceItem(tester), isNotNull);
      expect(onDeviceItem(tester)!.enabled, isFalse);
      expect(
        find.text(ja.settings_llmOnDeviceUnavailableDeviceNotEligible),
        findsOneWidget,
      );
    });

    testWidgets('an unrecognised answer still says the model is unusable', (
      tester,
    ) async {
      await pumpSection(
        tester,
        platformCanHost: true,
        availability: OnDeviceModelAvailability.unknown,
      );

      expect(onDeviceItem(tester)!.enabled, isFalse);
      expect(
        find.text(ja.settings_llmOnDeviceUnavailableUnknown),
        findsOneWidget,
      );
    });
  });

  group('while the availability query is still out', () {
    testWidgets('the option cannot be picked yet', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            platformCapabilitiesProvider.overrideWithValue(
              const PlatformCapabilities(
                textToSpeech: true,
                appUpdate: true,
                llmSummary: true,
                onDeviceLlm: true,
              ),
            ),
            foundationModelsLlmProvider.overrideWithValue(_SilentPlugin()),
          ],
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: LlmSettingsSection()),
            ),
          ),
        ),
      );
      await tester.pump();

      // Not listed at all until the answer arrives. Listing it and then
      // taking it away is worse than listing it a beat late, and on an OS
      // without the model taking it away is what would happen.
      expect(onDeviceItem(tester), isNull);
    });

    testWidgets('and nothing is blamed on the reader meanwhile', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ja = await AppLocalizations.delegate.load(const Locale('ja'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            platformCapabilitiesProvider.overrideWithValue(
              const PlatformCapabilities(
                textToSpeech: true,
                appUpdate: true,
                llmSummary: true,
                onDeviceLlm: true,
              ),
            ),
            foundationModelsLlmProvider.overrideWithValue(_SilentPlugin()),
          ],
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: LlmSettingsSection()),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(ja.settings_llmOnDeviceUnavailableUnknown),
        findsNothing,
      );
    });
  });

  group('where the platform cannot host the model', () {
    testWidgets('the option is absent rather than disabled', (tester) async {
      await pumpSection(
        tester,
        platformCanHost: false,
        availability: OnDeviceModelAvailability.unsupportedPlatform,
      );

      expect(onDeviceItem(tester), isNull);
    });

    testWidgets('and nothing is explained, since nothing can change', (
      tester,
    ) async {
      await pumpSection(
        tester,
        platformCanHost: false,
        availability: OnDeviceModelAvailability.unsupportedPlatform,
      );

      expect(
        find.text(ja.settings_llmOnDeviceUnavailableIntelligenceOff),
        findsNothing,
      );
      expect(
        find.text(ja.settings_llmOnDeviceUnavailableDeviceNotEligible),
        findsNothing,
      );
      expect(
        find.text(ja.settings_llmOnDeviceUnavailableUnknown),
        findsNothing,
      );
    });

    testWidgets('the two server options are still offered', (tester) async {
      await pumpSection(
        tester,
        platformCanHost: false,
        availability: OnDeviceModelAvailability.unsupportedPlatform,
      );

      final dropdown = tester.widget<DropdownButton<LlmProvider>>(
        find.byType(DropdownButton<LlmProvider>),
      );
      final values = dropdown.items!.map((i) => i.value).toSet();

      expect(values, containsAll([LlmProvider.ollama, LlmProvider.openai]));
    });
  });

  group('opening the section re-asks', () {
    testWidgets('a model that became ready while the app stayed open is seen', (
      tester,
    ) async {
      // A resume never happens when the reader never leaves, so mounting the
      // section is the other moment a stale answer can be refreshed.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final plugin = _Plugin(OnDeviceModelAvailability.available);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              textToSpeech: true,
              appUpdate: true,
              llmSummary: true,
              onDeviceLlm: true,
            ),
          ),
          foundationModelsLlmProvider.overrideWithValue(plugin),
        ],
      );
      addTearDown(container.dispose);

      // Something already asked, and the answer is now cached.
      await container.read(onDeviceModelAvailabilityProvider.future);
      expect(plugin.asked, 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: LlmSettingsSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(plugin.asked, greaterThan(1));
    });
  });

  group('the on-device provider carries no configuration', () {
    testWidgets('no endpoint, key or model field is shown for it', (
      tester,
    ) async {
      await pumpSection(
        tester,
        platformCanHost: true,
        availability: OnDeviceModelAvailability.available,
        stored: {'llm_provider': 'appleOnDevice'},
      );

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a server provider still shows its endpoint field', (
      tester,
    ) async {
      await pumpSection(
        tester,
        platformCanHost: true,
        availability: OnDeviceModelAvailability.available,
        stored: {
          'llm_provider': 'ollama',
          'llm_base_url': 'http://localhost:11434',
        },
      );

      expect(find.byType(TextField), findsWidgets);
    });
  });
}
