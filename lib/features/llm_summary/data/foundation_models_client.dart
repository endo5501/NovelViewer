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

  /// Names the model, as far as it can be named.
  ///
  /// The framework exposes no version for the system model, so this identity
  /// stays the same across an OS update that replaces the model underneath it.
  /// Folding the OS version in would detect that, at the cost of discarding
  /// every cached fact on every OS update — a worse trade for a model that is
  /// only ever one thing at a time on a given device.
  @override
  String get modelId => 'apple:on-device';

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

  /// Generates, giving up the schema constraint if that is what was refused.
  ///
  /// The constraint is the first choice, because an answer the model was made
  /// to shape parses without a fallback. It is not the only one. The safety
  /// guardrails judge the model's own output, and on the constrained path they
  /// judge it by the framework's default rules whatever guardrails the model
  /// was built with — measured on a chapter introducing an etiquette teacher,
  /// the passage was refused under both settings for as long as a schema was
  /// supplied, and answered as soon as it was not. So a refusal here is a
  /// refusal of the constrained path specifically, and the one request worth
  /// making is the same prompt without it.
  ///
  /// Only a refusal is worth a second attempt. A prompt that overran the
  /// window overruns it again without its schema, since dropping the schema
  /// does not shorten the prompt, and the rest do not change between two
  /// attempts a moment apart.
  ///
  /// A request that named no schema has no constraint left to give up, so it
  /// is reported as it stands rather than repeated identically.
  ///
  /// The retried answer is shaped by the model rather than by a schema: it
  /// arrives fenced, or with the named field holding a list where a string was
  /// asked for. It is returned as it came, because the pipeline already reads
  /// both forms from server-backed runtimes that ignore a requested format,
  /// and reshaping it here would give that text two places to be understood.
  @override
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) async {
    try {
      return await _generate(prompt, fieldName: schema?.fieldName);
    } on OnDeviceGenerationException catch (e) {
      if (schema == null ||
          e.reason != OnDeviceGenerationFailure.guardrailViolation) {
        throw _asAnalysisFailure(e);
      }
    }
    try {
      return await _generate(prompt, fieldName: null, sampling: _retrySampling);
    } on OnDeviceGenerationException catch (e) {
      throw _asAnalysisFailure(e);
    }
  }

  /// How the retry picks its tokens.
  ///
  /// Unconstrained, the model repeats a sentence until the response cap cuts
  /// the answer off mid-object, which reaches the caller as text that will not
  /// parse rather than as anything mentioning a limit. Measured on macOS over
  /// the same passages, half the unconstrained answers were unusable under the
  /// framework's default sampling and none were under greedy.
  ///
  /// Only the retry is sampled this way. The constrained path is already
  /// reliable, and there is nothing there for this to fix.
  static const OnDeviceSampling _retrySampling = OnDeviceSampling.greedy;

  Future<String> _generate(
    String prompt, {
    required String? fieldName,
    OnDeviceSampling? sampling,
  }) => _plugin.generate(
    prompt: prompt,
    schemaFieldName: fieldName,
    maxResponseTokens: maxResponseTokens,
    sampling: sampling,
  );

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
