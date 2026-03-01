import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show NotifierProvider, Notifier;

import '../data/tts_audio_export_service.dart';
import '../data/tts_audio_repository.dart';
import 'tts_playback_providers.dart';

// --- Export state ---

enum TtsExportState { idle, exporting }

final ttsExportStateProvider =
    NotifierProvider<TtsExportStateNotifier, TtsExportState>(
  TtsExportStateNotifier.new,
);

class TtsExportStateNotifier extends Notifier<TtsExportState> {
  @override
  TtsExportState build() => TtsExportState.idle;

  void set(TtsExportState value) => state = value;
}

// --- Export progress (reuses TtsGenerationProgress) ---

final ttsExportProgressProvider =
    NotifierProvider<TtsExportProgressNotifier, TtsGenerationProgress>(
  TtsExportProgressNotifier.new,
);

class TtsExportProgressNotifier extends Notifier<TtsGenerationProgress> {
  @override
  TtsGenerationProgress build() => TtsGenerationProgress.zero;

  void set(TtsGenerationProgress value) => state = value;
}

// --- Export action ---

/// Prompts user for save location and exports episode audio to MP3.
/// Returns true if export completed, false if user cancelled.
/// Throws on error. Caller is responsible for UI feedback.
Future<bool> exportEpisodeToMp3({
  required TtsExportStateNotifier stateNotifier,
  required TtsExportProgressNotifier progressNotifier,
  required TtsAudioRepository repository,
  required int episodeId,
  required String episodeFileName,
  required int sampleRate,
}) async {
  final defaultFileName = '$episodeFileName.mp3';
  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: 'MP3ファイルの保存先を選択',
    fileName: defaultFileName,
    type: FileType.custom,
    allowedExtensions: ['mp3'],
  );

  if (savePath == null) return false;

  stateNotifier.set(TtsExportState.exporting);
  progressNotifier.set(TtsGenerationProgress.zero);

  try {
    final segments = await repository.getSegments(episodeId);
    final wavSegments = <Uint8List>[];
    for (final segment in segments) {
      final audioData = segment['audio_data'] as Uint8List?;
      if (audioData != null) {
        wavSegments.add(audioData);
      }
    }

    if (wavSegments.isEmpty) {
      throw Exception('エクスポートする音声データがありません');
    }

    await exportToMp3WithProgress(
      wavSegments: wavSegments,
      outputPath: savePath,
      sampleRate: sampleRate,
      bitrate: 128,
      onProgress: (current, total) {
        progressNotifier
            .set(TtsGenerationProgress(current: current, total: total));
      },
    );
    return true;
  } finally {
    stateNotifier.set(TtsExportState.idle);
    progressNotifier.set(TtsGenerationProgress.zero);
  }
}
