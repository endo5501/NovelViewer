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
  TtsSession({
    required TtsIsolate isolate,
    Logger? logger,
    Duration modelLoadTimeout = const Duration(seconds: 120),
  })  : _isolate = isolate,
        _log = logger ?? Logger('tts.session'),
        _modelLoadTimeout = modelLoadTimeout;

  final TtsIsolate _isolate;
  final Logger _log;

  /// Backstop for a worker that stays alive but never replies (e.g. stuck in a
  /// native load). Worker *death* is handled deterministically via
  /// [WorkerDiedResponse]; this only covers the no-response-no-death case.
  final Duration _modelLoadTimeout;

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
    // The worker already died: the one-shot WorkerDiedResponse will not replay,
    // so fail fast instead of short-circuiting to a stale `true` or awaiting a
    // reply that never comes (F144 follow-up).
    if (_isolate.hasWorkerDied) {
      _log.warning('ensureModelLoaded skipped; worker already died');
      return false;
    }
    if (_modelLoaded && _loadedKey == config.modelLoadKey) return true;

    if (!_isolateSpawned) {
      try {
        await _isolate.spawn();
      } catch (e) {
        // The worker died before delivering its SendPort. Surface as a load
        // failure rather than propagating or hanging.
        _log.warning('TTS isolate spawn failed: $e');
        return false;
      }
      _isolateSpawned = true;
    }

    final completer = Completer<bool>();
    _activeModelLoadCompleter = completer;
    // Per-call subscription so a stale response from a previous (aborted)
    // load on the broadcast stream cannot complete this call's completer.
    final sub = _isolate.responses.listen((response) {
      if (completer.isCompleted) return;
      if (response is ModelLoadedResponse) {
        if (response.error != null) {
          _log.warning('Model load failed: ${response.error}');
        }
        completer.complete(response.success);
      } else if (response is WorkerDiedResponse) {
        // The worker terminated; the load will never reply. Resolve to false
        // instead of hanging forever (F144).
        _log.warning('Model load aborted; worker died: ${response.error}');
        completer.complete(false);
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
        case IrodoriEngineConfig():
          // Placeholder: full Irodori wiring (refWavPath / guidance scales /
          // steps / caption) into TtsIsolate.loadModel lands in task 5.x.
          // TtsIsolate currently fails any Irodori load explicitly (see
          // TtsIsolate._isolateEntryPoint), so this resolves to `false`
          // through the normal load-failure path below rather than hanging.
          _isolate.loadModel(
            config.modelDir,
            engineType: TtsEngineType.irodori,
          );
      }
      final success = await completer.future.timeout(
        _modelLoadTimeout,
        onTimeout: () {
          _log.warning(
            'Model load timed out after $_modelLoadTimeout; '
            'worker may be stuck',
          );
          return false;
        },
      );
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
    // The worker already died: a fresh listener would never see the one-shot
    // WorkerDiedResponse and synthesize has no timeout, so fail fast (F144
    // follow-up) instead of hanging on a reply that never comes.
    if (_isolate.hasWorkerDied) {
      _log.warning('synthesize skipped; worker already died');
      return null;
    }
    final completer = Completer<SynthesisResultResponse?>();
    _activeSynthesisCompleter = completer;
    final sub = _isolate.responses.listen((response) {
      if (completer.isCompleted) return;
      if (response is SynthesisResultResponse) {
        if (response.error != null || response.audio == null) {
          if (response.error != null) {
            _log.warning('Synthesis failed: ${response.error}');
          }
          completer.complete(null);
        } else {
          completer.complete(response);
        }
      } else if (response is WorkerDiedResponse) {
        // The worker terminated; this synthesis will never reply. Resolve to
        // null instead of hanging forever (F144).
        _log.warning('Synthesis aborted; worker died: ${response.error}');
        completer.complete(null);
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
