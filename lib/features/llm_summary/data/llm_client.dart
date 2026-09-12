import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';

abstract class LlmClient {
  /// Generates a completion for [prompt].
  ///
  /// When [schema] is supplied, the client constrains the model to answer with
  /// a JSON object matching it, using whatever mechanism the provider offers.
  /// Clients that cannot express the constraint ignore it; the caller still
  /// validates the response shape after the fact.
  Future<String> generate(String prompt, {LlmResponseSchema? schema});

  /// Names the model that answers this client's requests.
  ///
  /// A property of the client for the same reason [maxChunkSize] is: what
  /// model answers is a fact about the client, and only the client holds the
  /// provider and the model name together.
  ///
  /// Formed from the provider and the model name, never the endpoint address:
  /// the address says where a model is reached, not what it is, and a reader's
  /// self-hosted server changing address must not orphan its cache.
  ///
  /// Opaque. Stored as written, compared only for equality, never parsed — so
  /// a model name carrying the separator needs no special handling.
  ///
  /// There is deliberately no default. A default would let two different
  /// models share one identity and therefore one fact-cache shelf, which is
  /// the exact confusion the identity exists to prevent, and it would happen
  /// silently. A client that does not name itself fails to compile instead.
  String get modelId;

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
