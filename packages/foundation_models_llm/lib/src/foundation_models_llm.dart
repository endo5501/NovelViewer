import 'package:flutter/services.dart';
import 'package:foundation_models_llm/src/on_device_model_availability.dart';

/// The on-device foundation model, as this package exposes it.
///
/// Declared as an interface so a caller can be tested against a substitute
/// without a method channel. The shipped implementation is
/// [MethodChannelFoundationModelsLlm].
abstract class FoundationModelsLlm {
  /// The channel both sides agree on. Exposed so tests can address it.
  static const String channelName = 'jp.novelviewer/foundation_models_llm';

  /// Whether the model can be used right now, and if not, why.
  ///
  /// Never throws: every failure to get an answer is itself an answer that the
  /// model is unavailable.
  Future<OnDeviceModelAvailability> availability();
}

/// Reaches the native side over a method channel.
class MethodChannelFoundationModelsLlm implements FoundationModelsLlm {
  MethodChannelFoundationModelsLlm({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel(FoundationModelsLlm.channelName);

  final MethodChannel _channel;

  @override
  Future<OnDeviceModelAvailability> availability() async {
    try {
      final answer = await _channel.invokeMethod<String>('availability');
      return OnDeviceModelAvailability.fromWireName(answer);
    } on MissingPluginException {
      // The build carries no native implementation. This is a defensive floor
      // rather than how the application decides: it reads the platform from
      // its capability model and does not call here at all where the platform
      // cannot host the model.
      return OnDeviceModelAvailability.unsupportedPlatform;
    } on PlatformException {
      return OnDeviceModelAvailability.unknown;
    } on TypeError {
      // `invokeMethod<String>` casts, so an answer of the wrong type lands
      // here rather than as a null.
      return OnDeviceModelAvailability.unknown;
    }
  }
}
