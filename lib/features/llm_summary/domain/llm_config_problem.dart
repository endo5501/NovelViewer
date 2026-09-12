import 'llm_config.dart';
import 'llm_config_normalization.dart';

/// Why the current LLM configuration cannot be used.
///
/// One value describes the whole configuration, so a reader is pointed at one
/// field at a time rather than handed a list.
enum LlmConfigProblem {
  /// No provider has been chosen at all.
  noProvider,

  /// The selected provider is reached over the network and has no address.
  missingEndpoint,

  /// The selected provider needs a model named and none is.
  missingModel,

  /// The selected provider needs a credential and none is stored.
  missingApiKey,
}

/// What stops [config] from being used, or null when nothing does.
///
/// This single decision answers two questions that must not disagree: whether
/// to build a client at all, and what to tell the reader when none was built.
/// Deriving both from here is why the message can name the missing field
/// instead of asking a reader who has already chosen a provider to choose one.
///
/// The on-device provider is addressed by nothing, so no server setting is
/// required of it; whether its model is usable right now is a separate
/// question answered elsewhere.
///
/// Values are normalized before being judged, so the function is right even
/// for a caller that did not read them through `SettingsRepository`.
LlmConfigProblem? findLlmConfigProblem(
  LlmConfig config, {
  required String apiKey,
}) {
  if (config.provider == LlmProvider.none) return LlmConfigProblem.noProvider;
  if (!config.needsServerSettings) return null;

  // Ordered so the reader fills in the address first: naming a model or a
  // credential for a server that has not been located leads nowhere.
  if (normalizeEndpointUrl(config.baseUrl).isEmpty) {
    return LlmConfigProblem.missingEndpoint;
  }
  if (normalizeModelName(config.model).isEmpty) {
    return LlmConfigProblem.missingModel;
  }
  if (config.provider == LlmProvider.openai &&
      normalizeApiKey(apiKey).isEmpty) {
    return LlmConfigProblem.missingApiKey;
  }
  return null;
}
