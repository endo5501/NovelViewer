import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

final ttsModelDirProvider =
    NotifierProvider<TtsModelDirNotifier, String>(TtsModelDirNotifier.new);

class TtsModelDirNotifier extends Notifier<String> {
  @override
  String build() {
    final repository = ref.watch(settingsRepositoryProvider);
    return repository.getTtsModelDir();
  }

  Future<void> setTtsModelDir(String path) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setTtsModelDir(path);
    state = path;
  }
}

final ttsRefWavPathProvider =
    NotifierProvider<TtsRefWavPathNotifier, String>(TtsRefWavPathNotifier.new);

class TtsRefWavPathNotifier extends Notifier<String> {
  @override
  String build() {
    final repository = ref.watch(settingsRepositoryProvider);
    return repository.getTtsRefWavPath();
  }

  Future<void> setTtsRefWavPath(String path) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setTtsRefWavPath(path);
    state = path;
  }
}
