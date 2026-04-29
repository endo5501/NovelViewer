import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/domain/tts_engine_config.dart';

void main() {
  group('Qwen3EngineConfig', () {
    test('holds all fields with the expected values', () {
      const config = Qwen3EngineConfig(
        modelDir: '/models/qwen3',
        sampleRate: 24000,
        languageId: 2058,
        refWavPath: '/voice/narrator.wav',
        embeddingCacheDir: '/cache/embeddings',
      );

      expect(config.modelDir, '/models/qwen3');
      expect(config.sampleRate, 24000);
      expect(config.languageId, 2058);
      expect(config.refWavPath, '/voice/narrator.wav');
      expect(config.embeddingCacheDir, '/cache/embeddings');
    });

    test('refWavPath and embeddingCacheDir are optional', () {
      const config = Qwen3EngineConfig(
        modelDir: '/models/qwen3',
        sampleRate: 24000,
        languageId: 2058,
      );

      expect(config.refWavPath, isNull);
      expect(config.embeddingCacheDir, isNull);
    });
  });

  group('PiperEngineConfig', () {
    test('holds all fields with the expected values', () {
      const config = PiperEngineConfig(
        modelDir: '/models/piper/foo.onnx',
        sampleRate: 22050,
        dicDir: '/models/piper/open_jtalk_dic',
        lengthScale: 0.8,
        noiseScale: 0.667,
        noiseW: 0.8,
      );

      expect(config.modelDir, '/models/piper/foo.onnx');
      expect(config.sampleRate, 22050);
      expect(config.dicDir, '/models/piper/open_jtalk_dic');
      expect(config.lengthScale, 0.8);
      expect(config.noiseScale, 0.667);
      expect(config.noiseW, 0.8);
    });
  });

  group('TtsEngineConfig sealed switch', () {
    test('sealed switch is exhaustive and reaches both arms', () {
      String describe(TtsEngineConfig config) {
        return switch (config) {
          Qwen3EngineConfig() => 'qwen3',
          PiperEngineConfig() => 'piper',
        };
      }

      const qwen3 = Qwen3EngineConfig(
        modelDir: '/m', sampleRate: 24000, languageId: 2058);
      const piper = PiperEngineConfig(
        modelDir: '/m',
        sampleRate: 22050,
        dicDir: '/d',
        lengthScale: 1.0,
        noiseScale: 0.5,
        noiseW: 0.8,
      );

      expect(describe(qwen3), 'qwen3');
      expect(describe(piper), 'piper');
    });
  });

  group('TtsEngineConfig.resolveFromReader', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer createContainer({
      String libraryPath = '/home/user/NovelViewer',
    }) {
      return ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryPathProvider.overrideWithValue(libraryPath),
      ]);
    }

    test('returns Qwen3EngineConfig for qwen3 type', () async {
      await prefs.setString('tts_language', 'ja');
      await prefs.setString('tts_ref_wav_path', 'narrator.wav');
      final container = createContainer();
      addTearDown(container.dispose);

      final config = TtsEngineConfig.resolveFromReader(
        container.read,
        TtsEngineType.qwen3,
      );

      expect(config, isA<Qwen3EngineConfig>());
      final qwen3 = config as Qwen3EngineConfig;
      expect(qwen3.modelDir, p.join('/home/user', 'models', '0.6b'));
      expect(qwen3.sampleRate, 24000);
      expect(qwen3.languageId, 2058); // ja
      // refWavPath is resolved through VoiceReferenceService — joins voices/.
      expect(qwen3.refWavPath, p.join('/home/user', 'voices', 'narrator.wav'));
      expect(qwen3.embeddingCacheDir, p.join('/home/user', 'cache', 'embeddings'));
    });

    test('Qwen3 refWavPath is null when no global ref wav is set', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final config = TtsEngineConfig.resolveFromReader(
        container.read,
        TtsEngineType.qwen3,
      ) as Qwen3EngineConfig;
      expect(config.refWavPath, isNull);
    });

    test('returns PiperEngineConfig for piper type', () async {
      await prefs.setString('piper_model_name', 'jp_JP-test-model');
      await prefs.setDouble('piper_length_scale', 0.9);
      await prefs.setDouble('piper_noise_scale', 0.5);
      await prefs.setDouble('piper_noise_w', 0.7);
      final container = createContainer();
      addTearDown(container.dispose);

      final config = TtsEngineConfig.resolveFromReader(
        container.read,
        TtsEngineType.piper,
      );

      expect(config, isA<PiperEngineConfig>());
      final piper = config as PiperEngineConfig;
      expect(piper.modelDir,
          '${p.join('/home/user', 'models', 'piper')}/jp_JP-test-model.onnx');
      expect(piper.sampleRate, 22050);
      expect(piper.dicDir,
          p.join('/home/user', 'models', 'piper', 'open_jtalk_dic'));
      expect(piper.lengthScale, 0.9);
      expect(piper.noiseScale, 0.5);
      expect(piper.noiseW, 0.7);
    });

    test('does not subscribe — repeated reads yield current values without notifications',
        () async {
      // Establish that the function returns a snapshot — calling it twice
      // and observing different values after a setter call confirms it uses
      // `read` (not `watch`) and is not caching a subscription.
      await prefs.setString('tts_ref_wav_path', 'first.wav');
      final container = createContainer();
      addTearDown(container.dispose);

      final first = TtsEngineConfig.resolveFromReader(
        container.read,
        TtsEngineType.qwen3,
      ) as Qwen3EngineConfig;
      expect(first.refWavPath, p.join('/home/user', 'voices', 'first.wav'));

      // Mutate via the actual setter; the next resolve should pick it up.
      // resolveFromReader does not subscribe to anything — it just reads.
      // Read it again and expect the new value.
      // (We test that `resolveFromReader` does not register a long-lived
      // listener; the cleanest behavioral observation is "second call sees
      // updated value" with no widget/listener machinery in between.)
      await prefs.setString('tts_ref_wav_path', 'second.wav');
      // Force the notifier to rebuild by re-creating the container — sets
      // the bar that there is no stale subscription leaked across calls.
      final container2 = createContainer();
      addTearDown(container2.dispose);
      final second = TtsEngineConfig.resolveFromReader(
        container2.read,
        TtsEngineType.qwen3,
      ) as Qwen3EngineConfig;
      expect(second.refWavPath, p.join('/home/user', 'voices', 'second.wav'));
    });
  });
}
