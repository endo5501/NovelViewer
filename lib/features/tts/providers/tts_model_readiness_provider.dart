import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tts_engine_type.dart';
import 'irodori_model_download_providers.dart';
import 'piper_model_download_providers.dart';
import 'tts_model_download_providers.dart';

/// Whether an engine's model files can be loaded as they are on disk.
enum TtsModelReadiness {
  ready,

  /// Missing, incomplete, or superseded by a newer pinned revision. Callers
  /// must not synthesize; the user re-downloads from the settings screen.
  needsDownload,
}

/// Single entry point for "are this engine's models usable?".
///
/// Each engine's download notifier already answers exactly that question — its
/// `…Completed` state means "the files on disk are complete" both on startup
/// and after a download — so this reads their states instead of re-running the
/// three different completeness predicates. When qwen3 and Irodori bind their
/// markers to a revision the way piper does, this provider needs no change.
///
/// An `…Error` state reports [TtsModelReadiness.needsDownload] even if the
/// files happen to be complete: a download that just failed is exactly when a
/// half-written model is most likely, and the user is one retry away.
final ttsModelReadinessProvider =
    Provider.family<TtsModelReadiness, TtsEngineType>((ref, engineType) {
  final complete = switch (engineType) {
    TtsEngineType.piper =>
      ref.watch(piperModelDownloadProvider) is PiperModelDownloadCompleted,
    TtsEngineType.qwen3 =>
      ref.watch(ttsModelDownloadProvider) is TtsModelDownloadCompleted,
    TtsEngineType.irodori =>
      ref.watch(irodoriModelDownloadProvider) is IrodoriModelDownloadCompleted,
  };

  return complete
      ? TtsModelReadiness.ready
      : TtsModelReadiness.needsDownload;
});
