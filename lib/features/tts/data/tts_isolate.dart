import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'piper_tts_engine.dart';
import 'tts_engine.dart';
import 'tts_engine_type.dart';
import 'tts_language.dart';
import 'tts_native_bindings.dart';

final _log = Logger('tts.isolate');

/// Owns the native abort flag for a [TtsIsolate] session. Its lifetime is
/// independent of any synthesis context, so the main Isolate can signal abort
/// at any time — including during a model reload — without touching freed
/// memory (fixes the F111 use-after-free).
abstract class TtsAbortHandle {
  /// Native address of the handle, passed to the worker so it can wire the
  /// handle into `qwen3_tts_init`. `0` when no native handle backs this.
  int get address;

  /// Set the abort flag. Safe to call from any isolate at any time.
  void abort();

  /// Release the native handle. Called only after the worker has terminated.
  void free();
}

/// Creates the [TtsAbortHandle] for a session. Injectable for tests.
typedef TtsAbortHandleFactory = TtsAbortHandle Function();

/// Abort handle with no native backing (DLL unavailable / unsupported
/// platform). Abort degrades to a safe no-op.
class _NoopAbortHandle implements TtsAbortHandle {
  const _NoopAbortHandle();

  @override
  int get address => 0;

  @override
  void abort() {}

  @override
  void free() {}
}

/// FFI-backed abort handle.
class _NativeAbortHandle implements TtsAbortHandle {
  _NativeAbortHandle(this._bindings, this._handle);

  final TtsNativeBindings _bindings;
  final Pointer<Void> _handle;

  @override
  int get address => _handle.address;

  @override
  void abort() => _bindings.abort(_handle);

  @override
  void free() => _bindings.freeAbortHandle(_handle);
}

TtsAbortHandle _defaultAbortHandleFactory() {
  try {
    final bindings = TtsNativeBindings.open();
    final handle = bindings.createAbortHandle();
    if (handle == nullptr) {
      _log.warning('createAbortHandle returned null; abort disabled');
      return const _NoopAbortHandle();
    }
    return _NativeAbortHandle(bindings, handle);
  } catch (e) {
    // DLL unavailable (e.g. unsupported platform, or a test host without a
    // native build). Abort degrades to a no-op, matching the project's FFI
    // self-skip posture.
    _log.warning('TTS native library unavailable; abort disabled: $e');
    return const _NoopAbortHandle();
  }
}

// Messages sent to the TTS isolate

sealed class TtsIsolateMessage {}

class LoadModelMessage extends TtsIsolateMessage {
  LoadModelMessage({
    required this.modelDir,
    this.engineType = TtsEngineType.qwen3,
    this.nThreads = 4,
    this.languageId = TtsLanguage.defaultLanguageId,
    this.dicDir,
    this.lengthScale,
    this.noiseScale,
    this.noiseW,
    this.embeddingCacheDir,
    this.abortHandleAddress = 0,
  });
  final String modelDir;
  final TtsEngineType engineType;
  final int nThreads;
  final int languageId;
  // Native address of the session abort handle (0 = none). Wired into
  // qwen3_tts_init so the abort flag is checked during synthesis.
  final int abortHandleAddress;
  // Piper-specific
  final String? dicDir;
  final double? lengthScale;
  final double? noiseScale;
  final double? noiseW;
  final String? embeddingCacheDir;
}

class SynthesizeMessage extends TtsIsolateMessage {
  SynthesizeMessage({required this.text, this.refWavPath});
  final String text;
  final String? refWavPath;
}

class DisposeMessage extends TtsIsolateMessage {
  DisposeMessage();
}

/// Test-only message that forces the worker Isolate to terminate with an
/// uncaught error, used to exercise [TtsIsolate]'s death-detection path
/// without a native crash.
class _CrashMessage extends TtsIsolateMessage {}

// Responses from the TTS isolate

sealed class TtsIsolateResponse {}

class ModelLoadedResponse extends TtsIsolateResponse {
  ModelLoadedResponse({required this.success, this.error});
  final bool success;
  final String? error;
}

class SynthesisResultResponse extends TtsIsolateResponse {
  SynthesisResultResponse({
    required this.audio,
    required this.sampleRate,
    this.error,
  });
  final Float32List? audio;
  final int sampleRate;
  final String? error;
}

/// Signals that the worker Isolate terminated abnormally (uncaught error or an
/// unexpected exit) outside of [TtsIsolate.dispose]. Emitted on the broadcast
/// response stream so any in-flight [TtsSession] operation can resolve
/// deterministically instead of waiting forever (fixes the F144 hang).
class WorkerDiedResponse extends TtsIsolateResponse {
  WorkerDiedResponse(this.error);

  /// Human-readable reason for the death (uncaught error string or exit note).
  final String error;
}

class TtsIsolate {
  TtsIsolate({TtsAbortHandleFactory? abortHandleFactory})
      : _abortHandleFactory = abortHandleFactory ?? _defaultAbortHandleFactory;

  final TtsAbortHandleFactory _abortHandleFactory;

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  ReceivePort? _errorPort;
  ReceivePort? _exitPort;
  final _responseController = StreamController<TtsIsolateResponse>.broadcast();

  /// Set once [dispose] begins, so the spawn-registered error/exit listeners
  /// do not mistake a graceful shutdown for an abnormal worker death.
  bool _disposing = false;

  /// Set once a [WorkerDiedResponse] has been emitted, so a single death that
  /// fires both the error and exit listeners is reported only once.
  bool _workerDeathSignaled = false;

  /// True once the worker Isolate is known to have terminated (either via a
  /// detected abnormal death or a graceful exit). Lets [dispose] skip the
  /// graceful-shutdown wait when the worker is already gone.
  bool _workerExited = false;

  /// Completes with the worker's [SendPort] during [spawn]. Held as a field so
  /// [_handleWorkerDeath] can error-complete it if the worker dies before
  /// delivering its port, preventing spawn() from awaiting forever.
  Completer<SendPort>? _spawnCompleter;

  /// True once an abnormal worker death has been observed. Lets callers
  /// fail fast instead of issuing work to a dead worker (the one-shot
  /// [WorkerDiedResponse] does not replay on the broadcast stream).
  bool get hasWorkerDied => _workerDeathSignaled;

  /// Session abort handle. Created once at [spawn] and freed only after the
  /// worker Isolate has terminated, so its address is stable across model
  /// reloads and [abort] never touches a freed synthesis context.
  TtsAbortHandle? _abortHandle;

  /// Native address of the session abort handle. Exposed for tests.
  int? get debugAbortHandleAddress => _abortHandle?.address;

  /// Timeout for graceful shutdown before force-killing the isolate.
  static const _disposeTimeout = Duration(seconds: 2);

  Stream<TtsIsolateResponse> get responses => _responseController.stream;

  Future<void> spawn() async {
    // Create the session abort handle before spawning the worker so its address
    // is available for the very first loadModel and for abort() at any time.
    _abortHandle = _abortHandleFactory();

    try {
      _receivePort = ReceivePort();

      final completer = Completer<SendPort>();
      _spawnCompleter = completer;

      _receivePort!.listen((message) {
        if (message is SendPort) {
          if (!completer.isCompleted) completer.complete(message);
        } else if (message is TtsIsolateResponse) {
          _responseController.add(message);
        }
      });

      // Detect abnormal worker termination. A fatal uncaught error in the
      // worker fires onError (and, since spawned isolates are errorsAreFatal by
      // default, also onExit). These MUST be wired via Isolate.spawn's onError/
      // onExit arguments — not addErrorListener after spawn — so they are armed
      // atomically when the isolate starts. A post-spawn registration would
      // miss a worker that dies before delivering its SendPort, leaving spawn()
      // awaiting forever (the F144 hang, at spawn time).
      _errorPort = ReceivePort();
      _errorPort!.listen((message) {
        // onError delivers [errorString, stackTraceString].
        final reason = (message is List && message.isNotEmpty)
            ? message.first.toString()
            : message.toString();
        _handleWorkerDeath(reason);
      });

      _exitPort = ReceivePort();
      _exitPort!.listen((_) {
        _handleWorkerDeath('worker isolate exited unexpectedly');
      });

      _isolate = await Isolate.spawn(
        _isolateEntryPoint,
        _receivePort!.sendPort,
        onError: _errorPort!.sendPort,
        onExit: _exitPort!.sendPort,
      );

      _sendPort = await completer.future;
      _spawnCompleter = null;
    } catch (_) {
      // Spawning failed (or the worker died before delivering its SendPort);
      // release the native handle we just created so it is not leaked when the
      // caller treats spawn() failure as "nothing was started".
      _spawnCompleter = null;
      _abortHandle?.free();
      _abortHandle = null;
      _receivePort?.close();
      _receivePort = null;
      _errorPort?.close();
      _errorPort = null;
      _exitPort?.close();
      _exitPort = null;
      _isolate = null;
      rethrow;
    }
  }

  /// Reports an abnormal worker termination by emitting a single
  /// [WorkerDiedResponse] on the response stream. Idempotent and suppressed
  /// during [dispose] (a graceful exit is not a death).
  void _handleWorkerDeath(String reason) {
    if (_disposing || _workerDeathSignaled) return;
    _workerDeathSignaled = true;
    _workerExited = true;
    // No further sends can reach a dead worker; null the port so callers and
    // dispose() do not attempt to message it.
    _sendPort = null;
    // If the worker died before delivering its SendPort, unblock spawn() so it
    // does not await forever (which would reintroduce the F144 hang at spawn
    // time). spawn()'s catch handles the resulting cleanup.
    final spawnCompleter = _spawnCompleter;
    if (spawnCompleter != null && !spawnCompleter.isCompleted) {
      spawnCompleter.completeError(
        StateError('TTS worker died during spawn: $reason'),
      );
    }
    _log.warning('TTS worker terminated abnormally: $reason');
    if (!_responseController.isClosed) {
      _responseController.add(WorkerDiedResponse(reason));
    }
  }

  /// Test-only: forces the worker Isolate to terminate with an uncaught error,
  /// exercising the death-detection path. No-op if not spawned.
  void debugCrashWorker() {
    _sendPort?.send(_CrashMessage());
  }

  void loadModel(
    String modelDir, {
    TtsEngineType engineType = TtsEngineType.qwen3,
    int nThreads = 4,
    int languageId = TtsLanguage.defaultLanguageId,
    String? dicDir,
    double? lengthScale,
    double? noiseScale,
    double? noiseW,
    String? embeddingCacheDir,
  }) {
    _sendPort?.send(LoadModelMessage(
      modelDir: modelDir,
      engineType: engineType,
      nThreads: nThreads,
      languageId: languageId,
      dicDir: dicDir,
      lengthScale: lengthScale,
      noiseScale: noiseScale,
      noiseW: noiseW,
      embeddingCacheDir: embeddingCacheDir,
      abortHandleAddress: _abortHandle?.address ?? 0,
    ));
  }

  void synthesize(String text, {String? refWavPath}) {
    _sendPort?.send(SynthesizeMessage(text: text, refWavPath: refWavPath));
  }

  /// Abort any in-progress synthesis by setting the native abort flag directly.
  /// This bypasses the worker Isolate's event loop (which is blocked during
  /// synthesis) by writing to the session abort handle, whose lifetime is
  /// independent of the synthesis context.
  void abort() {
    _abortHandle?.abort();
  }

  Future<void> dispose() async {
    // Suppress the spawn-registered death listeners: the exit we are about to
    // trigger is graceful, not an abnormal death.
    _disposing = true;
    final isolate = _isolate;
    // If the worker already terminated abnormally (death path), it is a
    // Dart-level death with no native call in flight, so the handle is safe to
    // free without waiting — and there is no live worker to message.
    var workerExited = _workerExited;
    if (isolate != null && !_workerExited) {
      // Abort any in-progress synthesis so the worker Isolate's event loop
      // becomes responsive to DisposeMessage, enabling qwen3_tts_free().
      abort();

      // Listen for isolate exit to know when it has terminated
      final exitPort = ReceivePort();
      isolate.addOnExitListener(exitPort.sendPort);

      // Send DisposeMessage so the isolate can clean up native resources
      _sendPort?.send(DisposeMessage());

      // Wait for isolate to exit gracefully, or force-kill on timeout
      try {
        await exitPort.first.timeout(_disposeTimeout);
        workerExited = true;
      } on TimeoutException {
        isolate.kill(priority: Isolate.immediate);
        workerExited = false;
      } finally {
        exitPort.close();
      }
    }

    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    _errorPort?.close();
    _errorPort = null;
    _exitPort?.close();
    _exitPort = null;
    _sendPort = null;
    // Free the session abort handle only if the worker exited cleanly. On the
    // force-kill path the worker may still be blocked in a native synthesis FFI
    // call (Isolate.kill cannot interrupt in-flight native code), and its ggml
    // abort_callback can still read handle->abort_flag — freeing here would
    // reintroduce the F111 use-after-free, just on the timeout branch. Leak the
    // tiny handle in that rare case (the previous ctx-based design likewise
    // freed nothing on timeout).
    if (workerExited) {
      _abortHandle?.free();
    }
    _abortHandle = null;
    if (!_responseController.isClosed) {
      _responseController.close();
    }
  }

  static void _isolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    TtsEngine? qwen3Engine;
    PiperTtsEngine? piperEngine;
    TtsEngineType? activeEngineType;
    String? embeddingCacheDir;

    bool isEngineLoaded() {
      switch (activeEngineType) {
        case TtsEngineType.qwen3:
          return qwen3Engine?.isLoaded ?? false;
        case TtsEngineType.piper:
          return piperEngine?.isLoaded ?? false;
        case TtsEngineType.irodori:
          // Placeholder: full IrodoriTtsEngine wiring lands in task 5.x.
          return false;
        case null:
          return false;
      }
    }

    TtsSynthesisResult doSynthesize(String text, String? refWavPath) {
      switch (activeEngineType!) {
        case TtsEngineType.qwen3:
          if (refWavPath != null && embeddingCacheDir != null) {
            return qwen3Engine!.synthesizeWithVoiceCached(
              text,
              refWavPath,
              embeddingCacheDir: embeddingCacheDir!,
            );
          }
          return refWavPath != null
              ? qwen3Engine!.synthesizeWithVoice(text, refWavPath)
              : qwen3Engine!.synthesize(text);
        case TtsEngineType.piper:
          return piperEngine!.synthesize(text);
        case TtsEngineType.irodori:
          // Placeholder: full IrodoriTtsEngine wiring (incl. caption) lands
          // in task 5.x. isEngineLoaded() always reports false for Irodori
          // for now, so this path is unreachable in practice.
          throw UnimplementedError(
            'Irodori engine synthesis is not yet wired into TtsIsolate',
          );
      }
    }

    void disposeEngines() {
      qwen3Engine?.dispose();
      qwen3Engine = null;
      piperEngine?.dispose();
      piperEngine = null;
      activeEngineType = null;
    }

    receivePort.listen((message) {
      if (message is LoadModelMessage) {
        try {
          disposeEngines();

          switch (message.engineType) {
            case TtsEngineType.qwen3:
              final next = TtsEngine.open();
              next.loadModel(
                message.modelDir,
                nThreads: message.nThreads,
                abortHandle:
                    Pointer<Void>.fromAddress(message.abortHandleAddress),
              );
              next.setLanguage(message.languageId);
              qwen3Engine = next;

            case TtsEngineType.piper:
              final next = PiperTtsEngine.open();
              next.loadModel(message.modelDir, dicDir: message.dicDir ?? '');
              if (message.lengthScale != null) {
                next.setLengthScale(message.lengthScale!);
              }
              if (message.noiseScale != null) {
                next.setNoiseScale(message.noiseScale!);
              }
              if (message.noiseW != null) {
                next.setNoiseW(message.noiseW!);
              }
              piperEngine = next;

            case TtsEngineType.irodori:
              // Placeholder: full IrodoriTtsEngine wiring lands in task 5.x.
              // Fails the load explicitly (caught below) rather than
              // silently reporting success with no engine loaded.
              throw UnimplementedError(
                'Irodori engine is not yet wired into TtsIsolate',
              );
          }

          activeEngineType = message.engineType;
          // Include model dir basename in cache path to prevent cross-model
          // cache contamination (e.g. 0.6b vs 1.7b produce different sizes).
          if (message.embeddingCacheDir != null) {
            embeddingCacheDir = p.join(
              message.embeddingCacheDir!,
              p.basename(message.modelDir),
            );
          } else {
            embeddingCacheDir = null;
          }
          mainSendPort.send(ModelLoadedResponse(success: true));
        } catch (e) {
          disposeEngines();
          mainSendPort.send(
            ModelLoadedResponse(success: false, error: e.toString()),
          );
        }
      } else if (message is SynthesizeMessage) {
        try {
          if (!isEngineLoaded()) {
            mainSendPort.send(SynthesisResultResponse(
              audio: null,
              sampleRate: 0,
              error: 'Model not loaded',
            ));
            return;
          }

          qwen3Engine?.resetAbort();
          final result = doSynthesize(message.text, message.refWavPath);

          // Use TransferableTypedData for zero-copy transfer
          final transferable =
              TransferableTypedData.fromList([result.audio.buffer.asByteData()]);
          mainSendPort.send(SynthesisResultResponse(
            audio: transferable.materialize().asFloat32List(),
            sampleRate: result.sampleRate,
          ));
        } catch (e) {
          mainSendPort.send(SynthesisResultResponse(
            audio: null,
            sampleRate: 0,
            error: e.toString(),
          ));
        }
      } else if (message is DisposeMessage) {
        disposeEngines();
        receivePort.close();
      } else if (message is _CrashMessage) {
        // Intentionally thrown OUTSIDE any try/catch so it propagates as an
        // uncaught error, terminating the worker and firing the main isolate's
        // error/exit listeners (test-only; see debugCrashWorker).
        throw StateError('debugCrashWorker: intentional test crash');
      }
    });
  }
}
