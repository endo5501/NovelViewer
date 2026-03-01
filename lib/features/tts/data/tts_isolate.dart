import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'tts_engine.dart';

// Messages sent to the TTS isolate

sealed class TtsIsolateMessage {}

class LoadModelMessage extends TtsIsolateMessage {
  LoadModelMessage({
    required this.modelDir,
    this.nThreads = 4,
    this.languageId = TtsEngine.languageJapanese,
  });
  final String modelDir;
  final int nThreads;
  final int languageId;
}

class SynthesizeMessage extends TtsIsolateMessage {
  SynthesizeMessage({required this.text, this.refWavPath, this.instruct});
  final String text;
  final String? refWavPath;
  final String? instruct;
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

  void loadModel(String modelDir, {int nThreads = 4, int languageId = TtsEngine.languageJapanese}) {
    _sendPort?.send(LoadModelMessage(modelDir: modelDir, nThreads: nThreads, languageId: languageId));
  }

  void synthesize(String text, {String? refWavPath, String? instruct}) {
    _sendPort?.send(SynthesizeMessage(text: text, refWavPath: refWavPath, instruct: instruct));
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

    TtsEngine? engine;

    receivePort.listen((message) {
      if (message is LoadModelMessage) {
        TtsEngine? next;
        try {
          next = TtsEngine.open();
          next.loadModel(message.modelDir, nThreads: message.nThreads);
          next.setLanguage(message.languageId);
          engine?.dispose();
          engine = next;
          mainSendPort.send(ModelLoadedResponse(success: true));
        } catch (e) {
          next?.dispose();
          mainSendPort.send(
            ModelLoadedResponse(success: false, error: e.toString()),
          );
        }
      } else if (message is SynthesizeMessage) {
        try {
          if (engine == null || !engine!.isLoaded) {
            mainSendPort.send(SynthesisResultResponse(
              audio: null,
              sampleRate: 0,
              error: 'Model not loaded',
            ));
            return;
          }

          final result = engine!.synthesize(
            message.text,
            refWavPath: message.refWavPath,
            instruct: message.instruct,
          );

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
        engine?.dispose();
        engine = null;
        receivePort.close();
      }
    });
  }
}
