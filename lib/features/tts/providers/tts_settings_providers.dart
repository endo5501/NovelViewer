import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/voice_reference_service.dart';

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

final ttsModelDirProvider =
    NotifierProvider<TtsModelDirNotifier, String>(TtsModelDirNotifier.new);

class TtsModelDirNotifier extends _SettingStringNotifier {
  @override
  String Function(SettingsRepository) get _getter =>
      (repo) => repo.getTtsModelDir();

  @override
  Future<void> Function(SettingsRepository, String) get _setter =>
      (repo, value) => repo.setTtsModelDir(value);

  Future<void> setTtsModelDir(String path) => _update(path);
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
