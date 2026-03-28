import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'piper_tts_engine.dart';
import 'tts_engine.dart';
import 'tts_engine_type.dart';
import 'tts_language.dart';

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
  });
  final String modelDir;
  final TtsEngineType engineType;
  final int nThreads;
  final int languageId;
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

class TtsIsolate {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  final _responseController = StreamController<TtsIsolateResponse>.broadcast();

  /// Timeout for graceful shutdown before force-killing the isolate.
  static const _disposeTimeout = Duration(seconds: 2);

  Stream<TtsIsolateResponse> get responses => _responseController.stream;

  Future<void> spawn() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _receivePort!.sendPort,
    );

    final completer = Completer<SendPort>();

    _receivePort!.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is TtsIsolateResponse) {
        _responseController.add(message);
      }
    });

    _sendPort = await completer.future;
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
    ));
  }

  void synthesize(String text, {String? refWavPath}) {
    _sendPort?.send(SynthesizeMessage(text: text, refWavPath: refWavPath));
  }

  Future<void> dispose() async {
    final isolate = _isolate;
    if (isolate != null) {
      // Listen for isolate exit to know when it has terminated
      final exitPort = ReceivePort();
      isolate.addOnExitListener(exitPort.sendPort);

      // Send DisposeMessage so the isolate can clean up native resources
      _sendPort?.send(DisposeMessage());

      // Wait for isolate to exit gracefully, or force-kill on timeout
      try {
        await exitPort.first.timeout(_disposeTimeout);
      } on TimeoutException {
        isolate.kill(priority: Isolate.immediate);
      } finally {
        exitPort.close();
      }
    }

    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    _sendPort = null;
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
              next.loadModel(message.modelDir, nThreads: message.nThreads);
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
      }
    });
  }
}
