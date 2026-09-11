import 'package:foundation_models_llm/foundation_models_llm.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_analysis_failure.dart';

/// Generates through Apple's on-device foundation model.
///
/// The novel's text never leaves the device, which is the whole reason a
/// reader picks this client over one that reaches a server.
class FoundationModelsClient extends LlmClient {
  FoundationModelsClient({FoundationModelsLlm? plugin})
    : _plugin = plugin ?? MethodChannelFoundationModelsLlm();

  /// Characters of prompt this client accepts at once.
  ///
  /// The model's window holds the prompt and the response together, and is far
  /// smaller than a server model's. Measured on macOS with varied Japanese
  /// prose, the request starts failing between 5000 and 6000 characters, which
  /// puts Japanese at roughly seven tenths of a token to the character.
  ///
  /// This sits well below that ceiling on purpose. Denser text tokenizes
  /// worse than the sample did, and the margin is what keeps a chunk of
  /// unusually kanji-heavy prose from failing where an average one passes.
  /// Going lower buys no safety and costs a call per chunk, on a model that
  /// is already the slow part of a run.
  static const int onDeviceChunkSize = 3000;

  /// Tokens the response may take.
  ///
  /// Bounded so the share of the window left for the prompt is predictable
  /// rather than whatever the model happens not to use. Not bounded too
  /// tightly: a cap the answer runs into cuts the structured object off before
  /// it is closed, and that arrives as a response that will not parse rather
  /// than as anything mentioning a limit.
  static const int maxResponseTokens = 1000;

  final FoundationModelsLlm _plugin;

  @override
  int get maxChunkSize => onDeviceChunkSize;

  @override
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) async {
    try {
      return await _plugin.generate(
        prompt: prompt,
        schemaFieldName: schema?.fieldName,
        maxResponseTokens: maxResponseTokens,
      );
    } on OnDeviceGenerationException catch (e) {
      throw _asAnalysisFailure(e);
    }
  }

  /// Names the cause in the application's own terms.
  ///
  /// A refusal and an unreachable model get their own types because they lead
  /// the reader somewhere different: one is about the text of this file, the
  /// other about the model being switched off.
  LlmOnDeviceGenerationFailure _asAnalysisFailure(
    OnDeviceGenerationException e,
  ) => switch (e.reason) {
    OnDeviceGenerationFailure.guardrailViolation => LlmOnDeviceRefusedFailure(
      detail: e.detail,
    ),
    OnDeviceGenerationFailure.modelUnavailable => LlmOnDeviceUnavailableFailure(
      detail: e.detail,
    ),
    _ => LlmOnDeviceGenerationFailure(e.reason, detail: e.detail),
  };
}
