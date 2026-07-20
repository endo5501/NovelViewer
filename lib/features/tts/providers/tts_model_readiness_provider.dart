import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/settings_providers.dart';
import '../data/irodori_model_download_service.dart';
import '../data/piper_model_download_service.dart';
import '../data/tts_engine_type.dart';
import '../data/tts_model_download_service.dart';
import 'irodori_model_download_providers.dart';
import 'tts_model_download_providers.dart';
import 'tts_settings_providers.dart';

/// Whether an engine's model files can be loaded as they are on disk.
enum TtsModelReadiness {
  ready,

  /// Missing, incomplete, or superseded by a newer pinned revision. Callers
  /// must not start synthesis; the user re-downloads from the settings screen.
  needsDownload,
}

/// Single entry point for "are this engine's models usable?".
///
/// The three download services answer that question with different signatures
/// (`(dir, modelName)`, `(dir, size)`, `(dir)`), so synthesis entry points that
/// branched per engine would grow a new gap with every engine added. They ask
/// here instead.
///
/// Today only piper can report [TtsModelReadiness.needsDownload] for an
/// up-to-date-looking install, because only its marker records the revision it
/// was fetched from. qwen3 and Irodori delegate to their existing completeness
/// rules; wiring them through the same provider means binding their markers
/// later needs no change on the synthesis side.
final ttsModelReadinessProvider =
    Provider.family<TtsModelReadiness, TtsEngineType>((ref, engineType) {
  final client = ref.watch(httpClientProvider);

  bool downloaded() {
    switch (engineType) {
      case TtsEngineType.piper:
        final modelsDir = ref.watch(piperModelDirProvider);
        final dicDir = ref.watch(piperDicDirProvider);
        if (modelsDir.isEmpty || dicDir.isEmpty) return false;
        final service = PiperModelDownloadService(client: client);
        return service.areModelsDownloaded(
              modelsDir,
              ref.watch(piperModelNameProvider),
            ) &&
            service.isDictionaryDownloaded(dicDir);
      case TtsEngineType.qwen3:
        final modelsDir = ref.watch(ttsModelDirProvider);
        if (modelsDir.isEmpty) return false;
        return TtsModelDownloadService(client: client)
            .areModelsDownloaded(modelsDir, ref.watch(ttsModelSizeProvider));
      case TtsEngineType.irodori:
        final modelsBaseDir = ref.watch(modelsDirectoryPathProvider);
        if (modelsBaseDir == null) return false;
        return IrodoriModelDownloadService(
          client: client,
          expectedFileSizes: ref.watch(irodoriExpectedFileSizesProvider),
        ).areModelsDownloaded(modelsBaseDir);
    }
  }

  return downloaded()
      ? TtsModelReadiness.ready
      : TtsModelReadiness.needsDownload;
});
