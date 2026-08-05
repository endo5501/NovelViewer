import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_download_service.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_variant.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_model_download_providers.dart';

sealed class IrodoriModelDownloadState {
  const IrodoriModelDownloadState();
}

class IrodoriModelDownloadIdle extends IrodoriModelDownloadState {
  const IrodoriModelDownloadIdle();
}

class IrodoriModelDownloadDownloading extends IrodoriModelDownloadState {
  final String currentFile;
  final double? progress;
  const IrodoriModelDownloadDownloading({
    required this.currentFile,
    this.progress,
  });
}

class IrodoriModelDownloadCompleted extends IrodoriModelDownloadState {
  final String? modelsDir;
  const IrodoriModelDownloadCompleted({this.modelsDir});
}

class IrodoriModelDownloadError extends IrodoriModelDownloadState {
  final String message;
  const IrodoriModelDownloadError(this.message);
}

/// The pinned expected-size manifest used by [IrodoriModelDownloadService].
/// Defaults to the real, hardcoded sizes; overridable in tests so download
/// fixtures don't need to produce multi-hundred-megabyte-to-gigabyte
/// payloads to match the real manifest.
final irodoriExpectedFileSizesProvider =
    Provider<Map<IrodoriModelVariant, int>>(
  (ref) => IrodoriModelDownloadService.defaultExpectedFileSizes,
);

/// Presence and size of the pre-GGUF safetensors assets.
///
/// Presence is tracked separately from the byte total: a directory left empty
/// by a partial delete reclaims 0 bytes but must still be offered for cleanup,
/// otherwise the leftovers become unreachable from inside the app.
typedef IrodoriLegacyAssets = ({bool present, int bytes});

final irodoriLegacyAssetsProvider = Provider<IrodoriLegacyAssets>((ref) {
  final modelsDir = ref.watch(modelsDirectoryPathProvider);
  if (modelsDir == null) return (present: false, bytes: 0);
  final service = IrodoriModelDownloadService(
    client: ref.read(httpClientProvider),
    expectedFileSizes: ref.read(irodoriExpectedFileSizesProvider),
  );
  return (
    present: service.hasLegacyAssets(modelsDir),
    bytes: service.legacyAssetBytes(modelsDir),
  );
});

final irodoriModelDownloadProvider = NotifierProvider<
    IrodoriModelDownloadNotifier, IrodoriModelDownloadState>(
  IrodoriModelDownloadNotifier.new,
);

class IrodoriModelDownloadNotifier
    extends Notifier<IrodoriModelDownloadState> {
  late IrodoriModelDownloadService _service;

  /// Bumped on every [build]. A transfer captures the value current when it
  /// starts and drops its state writes once it no longer matches.
  ///
  /// [build] re-runs when the selected variant changes, but Riverpod reuses
  /// the notifier instance, so an in-flight transfer survives the rebuild
  /// while `_service` is replaced underneath it. Without this guard the old
  /// transfer's completion would mark the newly selected variant as
  /// downloaded — the UI would offer a model whose GGUF is not on disk, and
  /// loading would fail later instead of offering the download.
  int _generation = 0;

  /// The service owning the transfer currently on the wire, if any.
  ///
  /// Kept separate from [_service] so a cancel issued after a rebuild reaches
  /// the multi-gigabyte transfer that is actually running rather than a fresh
  /// service that owns nothing.
  IrodoriModelDownloadService? _inFlight;

  @override
  IrodoriModelDownloadState build() {
    _generation++;
    _service = IrodoriModelDownloadService(
      client: ref.read(httpClientProvider),
      expectedFileSizes: ref.read(irodoriExpectedFileSizesProvider),
    );

    final modelsDir = ref.watch(modelsDirectoryPathProvider);
    if (modelsDir == null) return const IrodoriModelDownloadIdle();

    // Judged for the selected variant only: having v3 on disk says nothing
    // about v4, so switching the variant re-evaluates readiness.
    final variant = ref.watch(irodoriModelVariantProvider);
    if (_service.isModelDownloaded(modelsDir, variant)) {
      return IrodoriModelDownloadCompleted(modelsDir: modelsDir);
    }
    return const IrodoriModelDownloadIdle();
  }

  /// Whether a transfer is on the wire right now.
  ///
  /// Read from [state] alone this would be wrong: a rebuild resets the state
  /// to idle while the transfer keeps running.
  bool get isDownloading => _inFlight != null;

  Future<void> startDownload() async {
    if (_inFlight != null) return;

    final modelsDir = ref.read(modelsDirectoryPathProvider);
    if (modelsDir == null) return;

    final generation = _generation;
    final service = _service;
    _inFlight = service;

    state = const IrodoriModelDownloadDownloading(
      currentFile: '',
      progress: 0,
    );

    try {
      await service.downloadModel(
        modelsDir,
        ref.read(irodoriModelVariantProvider),
        onProgress: (fileName, progress) {
          if (generation != _generation) return;
          state = IrodoriModelDownloadDownloading(
            currentFile: fileName,
            progress: progress,
          );
        },
      );

      if (generation != _generation) return;
      state = IrodoriModelDownloadCompleted(modelsDir: modelsDir);
    } on IrodoriDownloadCancelledException {
      // A user-initiated cancel is not a failure: return to idle so the
      // user can simply start again without seeing an error message.
      if (generation != _generation) return;
      state = const IrodoriModelDownloadIdle();
    } on SocketException catch (e) {
      if (generation != _generation) return;
      state = IrodoriModelDownloadError('ネットワーク接続エラー: $e');
    } on HttpException catch (e) {
      if (generation != _generation) return;
      state = IrodoriModelDownloadError('サーバーエラー: $e');
    } catch (e) {
      if (generation != _generation) return;
      state = IrodoriModelDownloadError('ダウンロード中にエラー: $e');
    } finally {
      if (identical(_inFlight, service)) _inFlight = null;
    }
  }

  /// Requests the in-flight [startDownload] transfer to stop.
  void cancelDownload() {
    (_inFlight ?? _service).cancel();
  }

  /// Deletes the pre-GGUF safetensors assets.
  ///
  /// Only ever invoked from an explicit user action, after a confirmation
  /// prompt — 2.9 GB is not recoverable, and the files may still be used
  /// elsewhere.
  ///
  /// A partial failure is surfaced rather than swallowed: on Windows a
  /// memory-mapped or otherwise locked file makes `delete(recursive: true)`
  /// throw part-way through, which would otherwise escape as an unhandled
  /// async error with nothing shown to the user. The refresh runs either way
  /// so the remaining size is re-read after a partial delete.
  Future<void> deleteLegacyAssets() async {
    final modelsDir = ref.read(modelsDirectoryPathProvider);
    if (modelsDir == null) return;
    try {
      await _service.deleteLegacyAssets(modelsDir);
    } on FileSystemException catch (e) {
      state = IrodoriModelDownloadError('旧モデルデータの削除に失敗: ${e.message}');
    } catch (e) {
      state = IrodoriModelDownloadError('旧モデルデータの削除に失敗: $e');
    } finally {
      ref.invalidate(irodoriLegacyAssetsProvider);
    }
  }
}
