abstract class LlmClient {
  Future<String> generate(String prompt);

  Future<void> releaseResources() async {}
}
