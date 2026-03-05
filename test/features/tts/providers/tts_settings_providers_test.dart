import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_language.dart';
import 'package:novel_viewer/features/tts/data/tts_model_size.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  group('ttsModelSizeProvider', () {
    test('returns small by default', () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsModelSizeProvider), TtsModelSize.small);
    });

    test('returns persisted value', () async {
      await prefs.setString('tts_model_size', 'large');
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsModelSizeProvider), TtsModelSize.large);
    });

    test('setTtsModelSize persists and updates state', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container
          .read(ttsModelSizeProvider.notifier)
          .setTtsModelSize(TtsModelSize.large);

      expect(container.read(ttsModelSizeProvider), TtsModelSize.large);
      expect(prefs.getString('tts_model_size'), 'large');
    });
  });

  group('ttsModelDirProvider', () {
    test('resolves to models/0.6b for small model', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/home/user/NovelViewer'),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(ttsModelDirProvider),
        p.join('/home/user', 'models', '0.6b'),
      );
    });

    test('resolves to models/1.7b for large model', () async {
      await prefs.setString('tts_model_size', 'large');
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/home/user/NovelViewer'),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(ttsModelDirProvider),
        p.join('/home/user', 'models', '1.7b'),
      );
    });

    test('returns empty string when library path is null', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(ttsModelDirProvider), '');
    });
  });

  group('ttsLanguageProvider', () {
    test('returns ja by default', () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsLanguageProvider), TtsLanguage.ja);
    });

    test('returns persisted value', () async {
      await prefs.setString('tts_language', 'en');
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsLanguageProvider), TtsLanguage.en);
    });

    test('setLanguage persists and updates state', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container
          .read(ttsLanguageProvider.notifier)
          .setLanguage(TtsLanguage.fr);

      expect(container.read(ttsLanguageProvider), TtsLanguage.fr);
      expect(prefs.getString('tts_language'), 'fr');
    });
  });

  group('ttsRefWavPathProvider', () {
    test('initial value is empty string', () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsRefWavPathProvider), '');
    });

    test('initial value loads file name from SharedPreferences', () async {
      await prefs.setString('tts_ref_wav_path', 'narrator.mp3');
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsRefWavPathProvider), 'narrator.mp3');
    });

    test('setTtsRefWavPath stores file name and persists', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container
          .read(ttsRefWavPathProvider.notifier)
          .setTtsRefWavPath('voice_sample.wav');
      expect(container.read(ttsRefWavPathProvider), 'voice_sample.wav');
      expect(prefs.getString('tts_ref_wav_path'), 'voice_sample.wav');
    });
  });
}
