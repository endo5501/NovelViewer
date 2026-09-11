import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';

abstract class LlmClient {
  /// Generates a completion for [prompt].
  ///
  /// When [schema] is supplied, the client constrains the model to answer with
  /// a JSON object matching it, using whatever mechanism the provider offers.
  /// Clients that cannot express the constraint ignore it; the caller still
  /// validates the response shape after the fact.
  Future<String> generate(String prompt, {LlmResponseSchema? schema});

  /// How much text, in characters, may be handed to this client at once.
  ///
  /// A property of the model behind the client rather than of the pipeline
  /// that calls it: a model running on the device has a far smaller window
  /// than one reached on a server, and the same chunking that suits the
  /// second overflows the first on its first request.
  ///
  /// The default is the value every client used before the budget existed, so
  /// a client with no view on the matter behaves exactly as it did.
  int get maxChunkSize => 4000;

  Future<void> releaseResources() async {}
}
