import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';

abstract class LlmClient {
  /// Generates a completion for [prompt].
  ///
  /// When [schema] is supplied, the client constrains the model to answer with
  /// a JSON object matching it, using whatever mechanism the provider offers.
  /// Clients that cannot express the constraint ignore it; the caller still
  /// validates the response shape after the fact.
  Future<String> generate(String prompt, {LlmResponseSchema? schema});

  Future<void> releaseResources() async {}
}
