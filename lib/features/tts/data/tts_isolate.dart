import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'tts_engine.dart';

// Messages sent to the TTS isolate

sealed class TtsIsolateMessage {}

class LoadModelMessage extends TtsIsolateMessage {
  LoadModelMessage({required this.modelDir, this.nThreads = 4});
  final String modelDir;
  final int nThreads;
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

  void loadModel(String modelDir, {int nThreads = 4}) {
    _sendPort?.send(LoadModelMessage(modelDir: modelDir, nThreads: nThreads));
  }

  void synthesize(String text, {String? refWavPath}) {
    _sendPort?.send(SynthesizeMessage(text: text, refWavPath: refWavPath));
  }

  void dispose() {
    _sendPort?.send(DisposeMessage());
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    _sendPort = null;
    _responseController.close();
  }

  static void _isolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    TtsEngine? engine;

    receivePort.listen((message) {
      if (message is LoadModelMessage) {
        try {
          engine = TtsEngine.open();
          engine!.loadModel(message.modelDir, nThreads: message.nThreads);
          mainSendPort.send(ModelLoadedResponse(success: true));
        } catch (e) {
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

          final result = message.refWavPath != null
              ? engine!.synthesizeWithVoice(message.text, message.refWavPath!)
              : engine!.synthesize(message.text);

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
