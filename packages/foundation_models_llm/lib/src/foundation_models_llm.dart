import 'package:flutter/services.dart';
import 'package:foundation_models_llm/src/on_device_generation_failure.dart';
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

  /// Generates text for [prompt].
  ///
  /// When [schemaFieldName] is given, generation is constrained to a JSON
  /// object carrying exactly that one string field, and the returned text is
  /// that object. The constraint is the model's, not a check applied after the
  /// fact, so a caller does not need a fallback for a malformed answer.
  ///
  /// With no [schemaFieldName] the generated text is returned as it stands.
  ///
  /// [maxResponseTokens] bounds the response so the share of the model's
  /// window left for the prompt is predictable.
  ///
  /// Throws [OnDeviceGenerationException] for every failure, so a caller reads
  /// one exception type rather than a platform's.
  Future<String> generate({
    required String prompt,
    String? schemaFieldName,
    int? maxResponseTokens,
  });
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

  @override
  Future<String> generate({
    required String prompt,
    String? schemaFieldName,
    int? maxResponseTokens,
  }) async {
    try {
      final answer = await _channel.invokeMethod<String>('generate', {
        'prompt': prompt,
        'schemaFieldName': schemaFieldName,
        'maxResponseTokens': maxResponseTokens,
      });
      if (answer == null) {
        // A generate that answers nothing is a broken contract, not an empty
        // summary. Saying so beats caching "" as a word's facts.
        throw const OnDeviceGenerationException(
          OnDeviceGenerationFailure.unknown,
          detail: 'the native side returned no text',
        );
      }
      return answer;
    } on MissingPluginException {
      throw const OnDeviceGenerationException(
        OnDeviceGenerationFailure.modelUnavailable,
        detail: 'no native implementation on this platform',
      );
    } on PlatformException catch (e) {
      throw OnDeviceGenerationException(
        OnDeviceGenerationFailure.fromWireCode(e.code),
        detail: e.message ?? e.code,
      );
    }
  }
}
