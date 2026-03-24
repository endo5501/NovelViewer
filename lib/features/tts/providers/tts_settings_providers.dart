import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/data/tts_language.dart';
import 'package:novel_viewer/features/tts/data/tts_model_size.dart';
import 'package:novel_viewer/features/tts/data/voice_reference_service.dart';
import 'package:novel_viewer/features/tts/providers/tts_model_download_providers.dart';

final voiceReferenceServiceProvider = Provider<VoiceReferenceService?>((ref) {
  final libraryPath = ref.watch(libraryPathProvider);
  if (libraryPath == null) return null;
  return VoiceReferenceService(libraryPath: libraryPath);
});

final voiceFilesProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(voiceReferenceServiceProvider);
  if (service == null) return [];
  return service.listVoiceFiles();
});

/// Generic base notifier that loads a [String] setting from [SettingsRepository]
/// on build and persists updates through a provided getter/setter pair.
abstract class _SettingStringNotifier extends Notifier<String> {
  String Function(SettingsRepository) get _getter;
  Future<void> Function(SettingsRepository, String) get _setter;

  @override
  String build() => _getter(ref.watch(settingsRepositoryProvider));

  Future<void> _update(String value) async {
    await _setter(ref.read(settingsRepositoryProvider), value);
    state = value;
  }
}

final ttsModelSizeProvider =
    NotifierProvider<TtsModelSizeNotifier, TtsModelSize>(
  TtsModelSizeNotifier.new,
);

class TtsModelSizeNotifier extends Notifier<TtsModelSize> {
  @override
  TtsModelSize build() =>
      ref.watch(settingsRepositoryProvider).getTtsModelSize();

  Future<void> setTtsModelSize(TtsModelSize size) async {
    await ref.read(settingsRepositoryProvider).setTtsModelSize(size);
    state = size;
  }
}

final ttsModelDirProvider = Provider<String>((ref) {
  final modelsBaseDir = ref.watch(modelsDirectoryPathProvider);
  if (modelsBaseDir == null) return '';
  final modelSize = ref.watch(ttsModelSizeProvider);
  return p.join(modelsBaseDir, modelSize.dirName);
});

final ttsLanguageProvider =
    NotifierProvider<TtsLanguageNotifier, TtsLanguage>(
  TtsLanguageNotifier.new,
);

class TtsLanguageNotifier extends Notifier<TtsLanguage> {
  @override
  TtsLanguage build() =>
      ref.watch(settingsRepositoryProvider).getTtsLanguage();

  Future<void> setLanguage(TtsLanguage language) async {
    await ref.read(settingsRepositoryProvider).setTtsLanguage(language);
    state = language;
  }
}

final ttsRefWavPathProvider =
    NotifierProvider<TtsRefWavPathNotifier, String>(TtsRefWavPathNotifier.new);

class TtsRefWavPathNotifier extends _SettingStringNotifier {
  @override
  String Function(SettingsRepository) get _getter =>
      (repo) => repo.getTtsRefWavPath();

  @override
  Future<void> Function(SettingsRepository, String) get _setter =>
      (repo, value) => repo.setTtsRefWavPath(value);

  Future<void> setTtsRefWavPath(String path) => _update(path);
}

// --- Engine type ---

final ttsEngineTypeProvider =
    NotifierProvider<TtsEngineTypeNotifier, TtsEngineType>(
  TtsEngineTypeNotifier.new,
);

class TtsEngineTypeNotifier extends Notifier<TtsEngineType> {
  @override
  TtsEngineType build() =>
      ref.watch(settingsRepositoryProvider).getTtsEngineType();

  Future<void> setEngineType(TtsEngineType type) async {
    await ref.read(settingsRepositoryProvider).setTtsEngineType(type);
    state = type;
  }
}

// --- Piper model name ---

final piperModelNameProvider =
    NotifierProvider<PiperModelNameNotifier, String>(
  PiperModelNameNotifier.new,
);

class PiperModelNameNotifier extends _SettingStringNotifier {
  @override
  String Function(SettingsRepository) get _getter =>
      (repo) => repo.getPiperModelName();

  @override
  Future<void> Function(SettingsRepository, String) get _setter =>
      (repo, value) => repo.setPiperModelName(value);

  Future<void> setPiperModelName(String name) => _update(name);
}

// --- Piper model directory ---

final piperModelDirProvider = Provider<String>((ref) {
  final modelsBaseDir = ref.watch(modelsDirectoryPathProvider);
  if (modelsBaseDir == null) return '';
  return p.join(modelsBaseDir, 'piper');
});

final piperDicDirProvider = Provider<String>((ref) {
  final piperDir = ref.watch(piperModelDirProvider);
  if (piperDir.isEmpty) return '';
  return p.join(piperDir, 'open_jtalk_dic');
});

// --- Piper synthesis parameters ---

abstract class _SettingDoubleNotifier extends Notifier<double> {
  double Function(SettingsRepository) get _getter;
  Future<void> Function(SettingsRepository, double) get _setter;

  @override
  double build() => _getter(ref.watch(settingsRepositoryProvider));

  Future<void> setValue(double value) async {
    await _setter(ref.read(settingsRepositoryProvider), value);
    state = value;
  }
}

final piperLengthScaleProvider =
    NotifierProvider<PiperLengthScaleNotifier, double>(
  PiperLengthScaleNotifier.new,
);

class PiperLengthScaleNotifier extends _SettingDoubleNotifier {
  @override
  double Function(SettingsRepository) get _getter =>
      (repo) => repo.getPiperLengthScale();
  @override
  Future<void> Function(SettingsRepository, double) get _setter =>
      (repo, value) => repo.setPiperLengthScale(value);
}

final piperNoiseScaleProvider =
    NotifierProvider<PiperNoiseScaleNotifier, double>(
  PiperNoiseScaleNotifier.new,
);

class PiperNoiseScaleNotifier extends _SettingDoubleNotifier {
  @override
  double Function(SettingsRepository) get _getter =>
      (repo) => repo.getPiperNoiseScale();
  @override
  Future<void> Function(SettingsRepository, double) get _setter =>
      (repo, value) => repo.setPiperNoiseScale(value);
}

final piperNoiseWProvider =
    NotifierProvider<PiperNoiseWNotifier, double>(
  PiperNoiseWNotifier.new,
);

class PiperNoiseWNotifier extends _SettingDoubleNotifier {
  @override
  double Function(SettingsRepository) get _getter =>
      (repo) => repo.getPiperNoiseW();
  @override
  Future<void> Function(SettingsRepository, double) get _setter =>
      (repo, value) => repo.setPiperNoiseW(value);
}
