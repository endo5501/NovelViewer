import 'piper_native_bindings.dart';
import 'tts_engine.dart';

class PiperTtsEngine {
  PiperTtsEngine(this._bindings);

  factory PiperTtsEngine.open() => PiperTtsEngine(PiperNativeBindings.open());

  // ignore: unused_field
  final PiperNativeBindings _bindings;

  bool get isLoaded => throw UnimplementedError();

  void loadModel(String modelPath, {required String dicDir}) {
    throw UnimplementedError();
  }

  void setLengthScale(double value) {
    throw UnimplementedError();
  }

  void setNoiseScale(double value) {
    throw UnimplementedError();
  }

  void setNoiseW(double value) {
    throw UnimplementedError();
  }

  TtsSynthesisResult synthesize(String text) {
    throw UnimplementedError();
  }

  void dispose() {
    throw UnimplementedError();
  }
}
