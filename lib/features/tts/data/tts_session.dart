import 'dart:async';

import 'package:logging/logging.dart';

import 'tts_engine_type.dart';
import 'tts_isolate.dart';
import '../domain/tts_engine_config.dart';

/// Owns the model-load and synthesis lifecycle for a single TTS pipeline.
///
/// One controller instance owns one [TtsSession] for its lifetime: the
/// session holds the isolate subscription, the in-flight synthesis completer,
/// and the abort wiring. Extracting this state out of the controller removes
/// a class of "are these two booleans in sync?" bugs that previously lived
/// in both the streaming and edit controllers.
class TtsSession {
  TtsSession({required TtsIsolate isolate, Logger? logger})
      : _isolate = isolate,
        _log = logger ?? Logger('tts.session');

  final TtsIsolate _isolate;
  final Logger _log;

  bool _modelLoaded = false;
  bool _isolateSpawned = false;
  Object? _loadedKey;
  Completer<SynthesisResultResponse?>? _activeSynthesisCompleter;
  Completer<bool>? _activeModelLoadCompleter;
  bool _disposed = false;

  bool get modelLoaded => _modelLoaded;
  bool get disposed => _disposed;

  /// Loads the model corresponding to [config]. Successive calls with the
  /// same config are no-ops. Returns `true` if the model was (or is)
  /// loaded, `false` if the load failed or was aborted.
  Future<bool> ensureModelLoaded(TtsEngineConfig config) async {
    if (_disposed) {
      throw StateError('TtsSession.ensureModelLoaded after dispose()');
    }
    if (_modelLoaded && _loadedKey == config.modelLoadKey) return true;

    if (!_isolateSpawned) {
      await _isolate.spawn();
      _isolateSpawned = true;
    }

    final completer = Completer<bool>();
    _activeModelLoadCompleter = completer;
    // Per-call subscription so a stale response from a previous (aborted)
    // load on the broadcast stream cannot complete this call's completer.
    final sub = _isolate.responses.listen((response) {
      if (response is ModelLoadedResponse && !completer.isCompleted) {
        completer.complete(response.success);
      }
    });

    try {
      switch (config) {
        case Qwen3EngineConfig():
          _isolate.loadModel(
            config.modelDir,
            engineType: TtsEngineType.qwen3,
            languageId: config.languageId,
            embeddingCacheDir: config.embeddingCacheDir,
          );
        case PiperEngineConfig():
          _isolate.loadModel(
            config.modelDir,
            engineType: TtsEngineType.piper,
            dicDir: config.dicDir,
            lengthScale: config.lengthScale,
            noiseScale: config.noiseScale,
            noiseW: config.noiseW,
          );
      }
      final success = await completer.future;
      _modelLoaded = success;
      _loadedKey = success ? config.modelLoadKey : null;
      return success;
    } finally {
      _activeModelLoadCompleter = null;
      await sub.cancel();
    }
  }

  /// Sends a synthesis request and resolves with the result, or `null` on
  /// engine error / abort. Only one synthesize may be in flight at a time.
  Future<SynthesisResultResponse?> synthesize({
    required String text,
    String? refWavPath,
  }) async {
    if (_disposed) {
      throw StateError('TtsSession.synthesize after dispose()');
    }
    final completer = Completer<SynthesisResultResponse?>();
    _activeSynthesisCompleter = completer;
    final sub = _isolate.responses.listen((response) {
      if (response is SynthesisResultResponse && !completer.isCompleted) {
        if (response.error != null || response.audio == null) {
          completer.complete(null);
        } else {
          completer.complete(response);
        }
      }
    });

    try {
      _isolate.synthesize(text, refWavPath: refWavPath);
      return await completer.future;
    } finally {
      _activeSynthesisCompleter = null;
      await sub.cancel();
    }
  }

  /// Aborts any in-progress operation. Idempotent.
  void abort() {
    _isolate.abort();
    final modelLoad = _activeModelLoadCompleter;
    if (modelLoad != null && !modelLoad.isCompleted) {
      modelLoad.complete(false);
    }
    _activeModelLoadCompleter = null;
    final synth = _activeSynthesisCompleter;
    if (synth != null && !synth.isCompleted) {
      synth.complete(null);
    }
    _activeSynthesisCompleter = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    abort();
    if (_isolateSpawned) {
      try {
        await _isolate.dispose();
      } catch (e, st) {
        _log.warning('TtsIsolate dispose threw', e, st);
      }
    }
    _isolateSpawned = false;
    _modelLoaded = false;
    _loadedKey = null;
  }

}
