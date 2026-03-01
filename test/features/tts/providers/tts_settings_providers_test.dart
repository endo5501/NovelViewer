import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
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

  group('ttsModelDirProvider', () {
    test('initial value is empty string', () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsModelDirProvider), '');
    });

    test('initial value loads from SharedPreferences', () async {
      await prefs.setString('tts_model_dir', '/path/to/models');
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsModelDirProvider), '/path/to/models');
    });

    test('setTtsModelDir updates state and persists', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container
          .read(ttsModelDirProvider.notifier)
          .setTtsModelDir('/new/path');
      expect(container.read(ttsModelDirProvider), '/new/path');
      expect(prefs.getString('tts_model_dir'), '/new/path');
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

  group('ttsInstructProvider', () {
    test('initial value is empty string', () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsInstructProvider), '');
    });

    test('initial value loads from SharedPreferences', () async {
      await prefs.setString('tts_instruct', '優しく穏やかに話してください');
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsInstructProvider), '優しく穏やかに話してください');
    });

    test('setTtsInstruct updates state and persists', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container
          .read(ttsInstructProvider.notifier)
          .setTtsInstruct('怒りの口調で');
      expect(container.read(ttsInstructProvider), '怒りの口調で');
      expect(prefs.getString('tts_instruct'), '怒りの口調で');
    });
  });
}
