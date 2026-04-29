enum LlmProvider { none, ollama, openai }

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
}
