/// Which LLM produces word summaries.
///
/// [appleOnDevice] is the one that reaches no server at all, and the one whose
/// availability is not settled by this value: a reader can have it selected on
/// a device where the model is momentarily unusable. That is deliberate. The
/// selection records what the reader wants, and losing availability must not
/// rewrite it, or turning the system intelligence feature off for an afternoon
/// would silently move them to a server.
enum LlmProvider { none, ollama, openai, appleOnDevice }

class LlmConfig {
  final LlmProvider provider;
  final String baseUrl;
  final String model;

  const LlmConfig({
    this.provider = LlmProvider.none,
    this.baseUrl = '',
    this.model = '',
  });

  bool get isConfigured => provider != LlmProvider.none;

  /// Whether this provider is addressed by an endpoint and a model name.
  ///
  /// The on-device model is not: there is nowhere to point it and nothing to
  /// name, so the settings section shows no fields for it.
  bool get needsServerSettings =>
      provider == LlmProvider.ollama || provider == LlmProvider.openai;
}
