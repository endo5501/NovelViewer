import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'audiocpp_native_bindings.dart';
import 'irodori_tts_engine.dart';
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

/// Creates the per-engine-family abort handles for a session. Injectable for
/// tests. Returns a handle keyed by the [TtsEngineType] that will consume it:
/// [TtsEngineType.qwen3] for the qwen3_tts_ffi handle and
/// [TtsEngineType.irodori] for the audiocpp_ffi handle. A family whose native
/// library is unavailable is simply absent from the map (that engine then has
/// no native abort). [TtsEngineType.piper] never has a handle.
typedef TtsAbortHandleFactory = Map<TtsEngineType, TtsAbortHandle> Function();

/// FFI-backed abort handle. Parameterized over the owning library's abort /
/// free functions so it is created — and later freed — by the SAME native DLL
/// that will dereference it. Each engine family owns its own handle
/// (qwen3_tts_ffi allocates the qwen3 handle, audiocpp_ffi allocates the
/// irodori handle); a handle is never wired into a different engine's DLL, so
/// no cross-DLL handle sharing occurs.
class _NativeAbortHandle implements TtsAbortHandle {
  _NativeAbortHandle(this._handle, {required this.abortFn, required this.freeFn});

  final Pointer<Void> _handle;
  final void Function(Pointer<Void>) abortFn;
  final void Function(Pointer<Void>) freeFn;

  @override
  int get address => _handle.address;

  @override
  void abort() => abortFn(_handle);

  @override
  void free() => freeFn(_handle);
}

/// Opens a native library and allocates one abort handle from it, backed by
/// that library's own abort/free functions. Returns null (never throws) when
/// the DLL is unavailable or its native create returns nullptr, so a missing
/// engine family degrades to "no native abort" for that family only.
TtsAbortHandle? _openNativeAbortHandle<B>({
  required B Function() open,
  required Pointer<Void> Function(B) createOf,
  required void Function(Pointer<Void>) Function(B) abortOf,
  required void Function(Pointer<Void>) Function(B) freeOf,
}) {
  try {
    final bindings = open();
    final handle = createOf(bindings);
    if (handle == nullptr) return null;
    return _NativeAbortHandle(
      handle,
      abortFn: abortOf(bindings),
      freeFn: freeOf(bindings),
    );
  } catch (e) {
    _log.warning('native abort handle unavailable: $e');
    return null;
  }
}

/// Allocates one abort handle per available engine family. Each handle is
/// created — and will be freed — by the SAME DLL that dereferences it, so no
/// handle is ever shared across DLLs.
Map<TtsEngineType, TtsAbortHandle> _defaultAbortHandleFactory() {
  final handles = <TtsEngineType, TtsAbortHandle>{};

  final qwen3 = _openNativeAbortHandle<TtsNativeBindings>(
    open: TtsNativeBindings.open,
    createOf: (b) => b.createAbortHandle(),
    abortOf: (b) => b.abort,
    freeOf: (b) => b.freeAbortHandle,
  );
  if (qwen3 != null) handles[TtsEngineType.qwen3] = qwen3;

  final audiocpp = _openNativeAbortHandle<AudiocppNativeBindings>(
    open: AudiocppNativeBindings.open,
    createOf: (b) => b.createAbortHandle(),
    abortOf: (b) => b.abort,
    freeOf: (b) => b.freeAbortHandle,
  );
  if (audiocpp != null) handles[TtsEngineType.irodori] = audiocpp;

  if (handles.isEmpty) {
    _log.warning('no TTS native library available; abort disabled');
  }
  return handles;
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
  // Native address of the abort handle for THIS engine family (0 = none):
  // the qwen3 handle for qwen3, the audiocpp handle for irodori, 0 for piper.
  // Wired into the engine's native init so the abort flag is checked during
  // synthesis. The address must match the engine being loaded — a handle is
  // only ever dereferenced by the DLL that allocated it.
  final int abortHandleAddress;
  // Piper-specific
  final String? dicDir;
  final double? lengthScale;
  final double? noiseScale;
  final double? noiseW;
  final String? embeddingCacheDir;
}

class SynthesizeMessage extends TtsIsolateMessage {
  SynthesizeMessage({
    required this.text,
    this.refWavPath,
    this.caption,
    this.speakerGuidanceScale,
    this.captionGuidanceScale,
    this.numInferenceSteps,
  });
  final String text;
  final String? refWavPath;
  // Irodori-only synthesis-time parameters. Ignored by the qwen3/piper
  // branches; passed to IrodoriTtsEngine.synthesize (design D8). Changing any
  // of these must NOT reload the model (they are absent from modelLoadKey).
  final String? caption;
  final double? speakerGuidanceScale;
  final double? captionGuidanceScale;
  final int? numInferenceSteps;
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

  /// Per-engine-family abort handles, keyed by the [TtsEngineType] that
  /// consumes each (qwen3, irodori). Created once at [spawn] and freed only
  /// after the worker Isolate has terminated, so each address is stable across
  /// model reloads and [abort] never touches a freed synthesis context.
  Map<TtsEngineType, TtsAbortHandle> _abortHandles = const {};

  /// Native address of the abort handle for [engineType] (null when that
  /// engine family has no native handle). Exposed for tests.
  int? debugAbortHandleAddressFor(TtsEngineType engineType) =>
      _abortHandles[engineType]?.address;

  /// Timeout for graceful shutdown before force-killing the isolate.
  static const _disposeTimeout = Duration(seconds: 2);

  Stream<TtsIsolateResponse> get responses => _responseController.stream;

  Future<void> spawn() async {
    // Create the per-engine abort handles before spawning the worker so their
    // addresses are available for the very first loadModel and for abort() at
    // any time.
    _abortHandles = _abortHandleFactory();

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
      // release the native handles we just created so they are not leaked when
      // the caller treats spawn() failure as "nothing was started".
      _spawnCompleter = null;
      for (final handle in _abortHandles.values) {
        handle.free();
      }
      _abortHandles = const {};
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
      // Send the handle allocated by THIS engine's DLL so the address is only
      // ever dereferenced by the library that created it (no cross-DLL wiring).
      abortHandleAddress: _abortHandles[engineType]?.address ?? 0,
    ));
  }

  void synthesize(
    String text, {
    String? refWavPath,
    String? caption,
    double? speakerGuidanceScale,
    double? captionGuidanceScale,
    int? numInferenceSteps,
  }) {
    _sendPort?.send(SynthesizeMessage(
      text: text,
      refWavPath: refWavPath,
      caption: caption,
      speakerGuidanceScale: speakerGuidanceScale,
      captionGuidanceScale: captionGuidanceScale,
      numInferenceSteps: numInferenceSteps,
    ));
  }

  /// Abort any in-progress synthesis by setting the native abort flag directly.
  /// This bypasses the worker Isolate's event loop (which is blocked during
  /// synthesis) by writing to the abort handles, whose lifetimes are
  /// independent of the synthesis context. Every live handle is set; flagging
  /// the inactive engine's handle is harmless because synthesis start clears it
  /// per-engine via resetAbort.
  void abort() {
    for (final handle in _abortHandles.values) {
      handle.abort();
    }
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
    // Free the abort handles only if the worker exited cleanly. On the
    // force-kill path the worker may still be blocked in a native synthesis FFI
    // call (Isolate.kill cannot interrupt in-flight native code), and its ggml
    // abort_callback can still read handle->abort_flag — freeing here would
    // reintroduce the F111 use-after-free, just on the timeout branch. Leak the
    // tiny handles in that rare case (the previous ctx-based design likewise
    // freed nothing on timeout). Each handle is freed by the same DLL that
    // allocated it (its own freeFn).
    if (workerExited) {
      for (final handle in _abortHandles.values) {
        handle.free();
      }
    }
    _abortHandles = const {};
    if (!_responseController.isClosed) {
      _responseController.close();
    }
  }

  static void _isolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    TtsEngine? qwen3Engine;
    PiperTtsEngine? piperEngine;
    IrodoriTtsEngine? irodoriEngine;
    TtsEngineType? activeEngineType;
    String? embeddingCacheDir;

    bool isEngineLoaded() {
      switch (activeEngineType) {
        case TtsEngineType.qwen3:
          return qwen3Engine?.isLoaded ?? false;
        case TtsEngineType.piper:
          return piperEngine?.isLoaded ?? false;
        case TtsEngineType.irodori:
          return irodoriEngine?.isLoaded ?? false;
        case null:
          return false;
      }
    }

    TtsSynthesisResult doSynthesize(SynthesizeMessage message) {
      final text = message.text;
      final refWavPath = message.refWavPath;
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
          // caption / guidance / steps are synthesis-time parameters (design
          // D8). Invariant: every production call site that builds a
          // SynthesizeMessage for the irodori engine always supplies
          // speakerGuidanceScale/captionGuidanceScale/numInferenceSteps
          // (product defaults live in settings_repository.dart, not here) —
          // so a null here is a caller bug, not a value to silently paper
          // over with a fallback.
          return irodoriEngine!.synthesize(
            text,
            refWavPath: refWavPath,
            caption: message.caption,
            speakerGuidanceScale: message.speakerGuidanceScale!,
            captionGuidanceScale: message.captionGuidanceScale!,
            numInferenceSteps: message.numInferenceSteps!,
          );
      }
    }

    void disposeEngines() {
      qwen3Engine?.dispose();
      qwen3Engine = null;
      piperEngine?.dispose();
      piperEngine = null;
      irodoriEngine?.dispose();
      irodoriEngine = null;
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
              final next = IrodoriTtsEngine.open();
              next.loadModel(
                message.modelDir,
                nThreads: message.nThreads,
                abortHandle:
                    Pointer<Void>.fromAddress(message.abortHandleAddress),
              );
              irodoriEngine = next;
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
          irodoriEngine?.resetAbort();
          final result = doSynthesize(message);

          // Materialize the audio into a fresh, isolate-owned buffer before
          // sending. We route it through TransferableTypedData only to obtain
          // that copy: materialize() runs here on the worker side and copies
          // the bytes out eagerly, so this is a plain copy — NOT the zero-copy
          // handoff TransferableTypedData enables when the receiver
          // materializes. (Transfer semantics intentionally unchanged.)
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
