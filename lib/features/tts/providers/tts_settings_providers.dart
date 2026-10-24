import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_variant.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/data/tts_language.dart';
import 'package:novel_viewer/features/tts/data/tts_model_size.dart';
import 'package:novel_viewer/features/tts/data/voice_reference_service.dart';
import 'package:novel_viewer/features/tts/providers/tts_availability_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_model_download_providers.dart';

final voiceReferenceServiceProvider = Provider<VoiceReferenceService?>((ref) {
  final libraryPath = ref.watch(libraryPathProvider);
  if (libraryPath == null) return null;
  return VoiceReferenceService(libraryPath: libraryPath);
});

/// Asks the reader for reference audio files to add, offering the
/// [extensions] (lower case, with the dot) the engine in use reads. Answers
/// the picked paths, or null when the picker was closed without a pick.
typedef VoiceFilePicker =
    Future<List<String>?> Function({required Set<String> extensions});

/// The system file picker, overridable in tests. On iOS the picked files
/// arrive as copies in the app's temporary folder, which are then copied into
/// the voices folder like any other added file.
final voiceFilePickerProvider = Provider<VoiceFilePicker>(
  (ref) => ({required extensions}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [for (final e in extensions) e.substring(1)],
      allowMultiple: true,
    );
    if (result == null) return null;
    return [
      for (final file in result.files)
        if (file.path != null) file.path!,
    ];
  },
);

/// The reference-voice extensions the engine in use reads, in lower case.
///
/// The same answer `TtsEngineConfig.acceptedReferenceExtensions` gives for a
/// resolved config, for the voice selector, which lists only these.
final acceptedReferenceExtensionsProvider = Provider<Set<String>>(
  (ref) => switch (ref.watch(ttsEngineTypeProvider)) {
    TtsEngineType.irodori =>
      ref.watch(irodoriModelVariantProvider).referenceExtensions,
    TtsEngineType.qwen3 || TtsEngineType.piper => const {'.wav', '.mp3'},
  },
);

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

final embeddingCacheDirProvider = Provider<String?>((ref) {
  final libraryPath = ref.watch(libraryPathProvider);
  if (libraryPath == null) return null;
  return p.join(p.dirname(libraryPath), 'cache', 'embeddings');
});

final ttsLanguageProvider = NotifierProvider<TtsLanguageNotifier, TtsLanguage>(
  TtsLanguageNotifier.new,
);

class TtsLanguageNotifier extends Notifier<TtsLanguage> {
  @override
  TtsLanguage build() => ref.watch(settingsRepositoryProvider).getTtsLanguage();

  Future<void> setLanguage(TtsLanguage language) async {
    await ref.read(settingsRepositoryProvider).setTtsLanguage(language);
    state = language;
  }
}

final ttsRefWavPathProvider = NotifierProvider<TtsRefWavPathNotifier, String>(
  TtsRefWavPathNotifier.new,
);

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

/// The engine in use: the persisted choice when this platform runs it,
/// otherwise the first engine it does run.
///
/// Every consumer that acts on the engine reads this provider, so resolving
/// here keeps an engine the platform has no library for — the qwen3 default
/// on iOS, or a choice restored from a desktop — from ever being loaded. The
/// persisted value is left alone, so that choice still applies wherever it is
/// supported.
class TtsEngineTypeNotifier extends Notifier<TtsEngineType> {
  /// Piper first: it is the one engine every platform runs.
  static const _fallbackOrder = [
    TtsEngineType.piper,
    TtsEngineType.qwen3,
    TtsEngineType.irodori,
  ];

  @override
  TtsEngineType build() {
    final persisted = ref.watch(settingsRepositoryProvider).getTtsEngineType();
    final supported = ref.watch(supportedTtsEnginesProvider);
    if (supported.isEmpty || supported.contains(persisted)) return persisted;
    return _fallbackOrder.firstWhere(supported.contains);
  }

  Future<void> setEngineType(TtsEngineType type) async {
    await ref.read(settingsRepositoryProvider).setTtsEngineType(type);
    state = type;
  }
}

// --- Piper model name ---

final piperModelNameProvider = NotifierProvider<PiperModelNameNotifier, String>(
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

final piperNoiseWProvider = NotifierProvider<PiperNoiseWNotifier, double>(
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

// --- Irodori model variant ---

/// The variants this platform can run, in the order the selector lists them:
/// those whose runtime is the platform's Irodori runtime.
final supportedIrodoriVariantsProvider = Provider<List<IrodoriModelVariant>>((
  ref,
) {
  final runtime = ref.watch(irodoriRuntimeProvider);
  return [
    for (final variant in IrodoriModelVariant.values)
      if (variant.runtime == runtime) variant,
  ];
});

final irodoriModelVariantProvider =
    NotifierProvider<IrodoriModelVariantNotifier, IrodoriModelVariant>(
      IrodoriModelVariantNotifier.new,
    );

/// The variant in use: the persisted choice when this platform runs it,
/// otherwise the first variant it does run.
///
/// The persisted value is left alone, as [TtsEngineTypeNotifier] leaves the
/// engine: a reader who restores a desktop backup on the iPad keeps their
/// desktop choice there.
class IrodoriModelVariantNotifier extends Notifier<IrodoriModelVariant> {
  @override
  IrodoriModelVariant build() {
    final persisted = ref
        .watch(settingsRepositoryProvider)
        .getIrodoriModelVariant();
    final supported = ref.watch(supportedIrodoriVariantsProvider);
    if (supported.isEmpty || supported.contains(persisted)) return persisted;
    return supported.first;
  }

  Future<void> setValue(IrodoriModelVariant value) async {
    await ref.read(settingsRepositoryProvider).setIrodoriModelVariant(value);
    state = value;
  }
}

// --- Irodori model directory ---

/// Directory holding the selected variant's single GGUF.
///
/// Each variant gets its own directory because the native loader refuses to
/// start when a model directory contains more than one `.gguf`.
final irodoriModelDirProvider = Provider<String>((ref) {
  final modelsBaseDir = ref.watch(modelsDirectoryPathProvider);
  if (modelsBaseDir == null) return '';
  final variant = ref.watch(irodoriModelVariantProvider);
  return p.join(modelsBaseDir, variant.modelDirName);
});

// --- Irodori synthesis parameters ---

abstract class _SettingIntNotifier extends Notifier<int> {
  int Function(SettingsRepository) get _getter;
  Future<void> Function(SettingsRepository, int) get _setter;

  @override
  int build() => _getter(ref.watch(settingsRepositoryProvider));

  Future<void> setValue(int value) async {
    await _setter(ref.read(settingsRepositoryProvider), value);
    state = value;
  }
}

final irodoriSpeakerGuidanceScaleProvider =
    NotifierProvider<IrodoriSpeakerGuidanceScaleNotifier, double>(
      IrodoriSpeakerGuidanceScaleNotifier.new,
    );

class IrodoriSpeakerGuidanceScaleNotifier extends _SettingDoubleNotifier {
  @override
  double Function(SettingsRepository) get _getter =>
      (repo) => repo.getIrodoriSpeakerGuidanceScale();
  @override
  Future<void> Function(SettingsRepository, double) get _setter =>
      (repo, value) => repo.setIrodoriSpeakerGuidanceScale(value);
}

final irodoriCaptionGuidanceScaleProvider =
    NotifierProvider<IrodoriCaptionGuidanceScaleNotifier, double>(
      IrodoriCaptionGuidanceScaleNotifier.new,
    );

class IrodoriCaptionGuidanceScaleNotifier extends _SettingDoubleNotifier {
  @override
  double Function(SettingsRepository) get _getter =>
      (repo) => repo.getIrodoriCaptionGuidanceScale();
  @override
  Future<void> Function(SettingsRepository, double) get _setter =>
      (repo, value) => repo.setIrodoriCaptionGuidanceScale(value);
}

final irodoriNumInferenceStepsProvider =
    NotifierProvider<IrodoriNumInferenceStepsNotifier, int>(
      IrodoriNumInferenceStepsNotifier.new,
    );

class IrodoriNumInferenceStepsNotifier extends _SettingIntNotifier {
  @override
  int Function(SettingsRepository) get _getter =>
      (repo) => repo.getIrodoriNumInferenceSteps();
  @override
  Future<void> Function(SettingsRepository, int) get _setter =>
      (repo, value) => repo.setIrodoriNumInferenceSteps(value);
}
