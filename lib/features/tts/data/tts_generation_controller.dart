import 'dart:async';

import 'text_segmenter.dart';
import 'tts_audio_repository.dart';
import 'tts_isolate.dart';
import 'wav_writer.dart';

class TtsGenerationController {
  TtsGenerationController({
    required TtsIsolate ttsIsolate,
    required TtsAudioRepository repository,
  })  : _ttsIsolate = ttsIsolate,
        _repository = repository;

  final TtsIsolate _ttsIsolate;
  final TtsAudioRepository _repository;
  final _textSegmenter = TextSegmenter();

  bool _cancelled = false;
  int? _currentEpisodeId;
  StreamSubscription<TtsIsolateResponse>? _subscription;
  Completer<SynthesisResultResponse>? _activeSynthesisCompleter;

  /// Called when a segment is generated: (current, total).
  void Function(int current, int total)? onProgress;

  /// Called when an error occurs.
  void Function(String error)? onError;

  Future<void> start({
    required String text,
    required String fileName,
    required String modelDir,
    required int sampleRate,
    String? refWavPath,
  }) async {
    _cancelled = false;

    // Delete existing data for this file
    final existing = await _repository.findEpisodeByFileName(fileName);
    if (existing != null) {
      await _repository.deleteEpisode(existing['id'] as int);
    }

    // Split text into segments
    final segments = _textSegmenter.splitIntoSentences(text);
    if (segments.isEmpty) return;

    // Create episode record
    _currentEpisodeId = await _repository.createEpisode(
      fileName: fileName,
      sampleRate: sampleRate,
      status: 'generating',
      refWavPath: refWavPath,
    );

    // Spawn isolate and load model
    await _ttsIsolate.spawn();

    final modelCompleter = Completer<bool>();
    _subscription = _ttsIsolate.responses.listen((response) {
      if (response is ModelLoadedResponse && !modelCompleter.isCompleted) {
        modelCompleter.complete(response.success);
        if (!response.success) {
          onError?.call('Model load failed: ${response.error}');
        }
      }
    });

    _ttsIsolate.loadModel(modelDir);
    final modelLoaded = await modelCompleter.future;

    if (!modelLoaded || _cancelled) {
      await _cleanup();
      return;
    }

    // Generate each segment sequentially
    for (var i = 0; i < segments.length; i++) {
      if (_cancelled) break;

      final segment = segments[i];
      final result = await _synthesizeSegment(segment.text, refWavPath);

      if (_cancelled) break;

      if (result == null) {
        await _cleanup();
        return;
      }

      // Convert Float32List to WAV bytes
      final wavBytes = WavWriter.toBytes(
        audio: result.audio!,
        sampleRate: result.sampleRate,
      );

      await _repository.insertSegment(
        episodeId: _currentEpisodeId!,
        segmentIndex: i,
        text: segment.text,
        textOffset: segment.offset,
        textLength: segment.length,
        audioData: wavBytes,
        sampleCount: result.audio!.length,
        refWavPath: refWavPath,
      );

      onProgress?.call(i + 1, segments.length);
    }

    if (_cancelled) {
      await _cleanup();
      return;
    }

    // Mark episode as completed
    await _repository.updateEpisodeStatus(_currentEpisodeId!, 'completed');

    await _ttsIsolate.dispose();
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<SynthesisResultResponse?> _synthesizeSegment(
      String text, String? refWavPath) async {
    final completer = Completer<SynthesisResultResponse>();
    _activeSynthesisCompleter = completer;

    late StreamSubscription<TtsIsolateResponse> sub;
    sub = _ttsIsolate.responses.listen((response) {
      if (response is SynthesisResultResponse && !completer.isCompleted) {
        completer.complete(response);
      }
    });

    _ttsIsolate.synthesize(text, refWavPath: refWavPath);

    try {
      final result = await completer.future;

      if (_cancelled) return null;

      if (result.error != null || result.audio == null) {
        onError?.call('Synthesis failed: ${result.error}');
        return null;
      }

      return result;
    } finally {
      _activeSynthesisCompleter = null;
      await sub.cancel();
    }
  }

  Future<void> cancel() async {
    _cancelled = true;
    final completer = _activeSynthesisCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(SynthesisResultResponse(
        audio: null,
        sampleRate: 0,
        error: 'Cancelled',
      ));
    }
    await _cleanup();
  }

  Future<void> _cleanup() async {
    if (_currentEpisodeId != null) {
      await _repository.deleteEpisode(_currentEpisodeId!);
      _currentEpisodeId = null;
    }
    await _subscription?.cancel();
    _subscription = null;
    await _ttsIsolate.dispose();
  }

}
