import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/foundation_models_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/llm_summary/data/ollama_client.dart';
import 'package:novel_viewer/features/llm_summary/data/openai_compatible_client.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config_problem.dart';
import 'package:novel_viewer/features/llm_summary/providers/on_device_llm_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';
import 'package:novel_viewer/shared/database/novel_data_database_provider.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';

final llmConfigProvider = Provider<LlmConfig>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getLlmConfig();
});

/// The stored OpenAI-compatible API key.
///
/// Held as a provider so the completeness check and the client construction
/// read it once between them. Two reads could disagree — a key emptied in
/// between would pass the check and reach the client blank — and each one
/// crosses a platform channel to the device keychain.
///
/// Only the provider that needs a credential reads this: the Ollama path must
/// not touch secure storage at all.
///
/// `autoDispose` so the credential is not held for the life of the container.
/// Selecting a different provider drops the only watchers, and the key leaves
/// memory with them — as it did before it was cached here, when it lived only
/// inside the client that was rebuilt.
final llmApiKeyProvider = FutureProvider.autoDispose<String>(
  (ref) => ref.watch(settingsRepositoryProvider).getApiKey(),
);

/// What stops the current configuration from being used, or null when nothing
/// does.
///
/// The one place that decides. `llmClientProvider` consults it to know whether
/// to build a client at all, and the analysis runner consults it to know what
/// to tell the reader, so a client that was not built and the sentence
/// explaining why cannot describe different things.
///
/// The credential is fetched only for the provider that needs one: the Ollama
/// path must not touch secure storage.
final llmConfigProblemProvider = FutureProvider<LlmConfigProblem?>((ref) async {
  final config = ref.watch(llmConfigProvider);
  final apiKey = config.provider == LlmProvider.openai
      ? await ref.watch(llmApiKeyProvider.future)
      : '';
  return findLlmConfigProblem(config, apiKey: apiKey);
});

final llmClientProvider = FutureProvider<LlmClient?>((ref) async {
  final config = ref.watch(llmConfigProvider);
  // Refuse before reaching the network rather than after. An endpoint URL or
  // model name that is missing used to produce a client whose first request
  // failed with a FormatException naming a character position — an error that
  // told the reader nothing about the field they had left blank.
  if (await ref.watch(llmConfigProblemProvider.future) != null) return null;
  // Inject the shared, provider-managed http.Client (closed via its onDispose)
  // instead of letting each client create its own unclosed one (F163).
  final httpClient = ref.watch(httpClientProvider);
  switch (config.provider) {
    case LlmProvider.ollama:
      return OllamaClient(
        baseUrl: config.baseUrl,
        model: config.model,
        httpClient: httpClient,
      );
    case LlmProvider.openai:
      // The same value the completeness check above passed judgement on.
      final apiKey = await ref.watch(llmApiKeyProvider.future);
      return OpenAiCompatibleClient(
        baseUrl: config.baseUrl,
        apiKey: apiKey,
        model: config.model,
        httpClient: httpClient,
      );
    case LlmProvider.appleOnDevice:
      // No fallback. A reader picks this provider so the novel's text stays
      // on the device; quietly reaching for a server they configured earlier
      // would defeat that choice without ever telling them. Their stored
      // selection is left alone, so turning the system intelligence feature
      // back on is all it takes to resume.
      final availability = await ref.watch(
        onDeviceModelAvailabilityProvider.future,
      );
      if (!availability.isAvailable) return null;
      return FoundationModelsClient(
        plugin: ref.watch(foundationModelsLlmProvider),
      );
    // Unreachable: `noProvider` is a problem, so the guard above already
    // returned. Kept for exhaustiveness.
    case LlmProvider.none:
      return null;
  }
});

/// Folder-scoped `LlmSummaryRepository`, backed by the novel's per-folder
/// `novel_data.db`. The family argument is the novel folder's absolute path.
final llmSummaryRepositoryProvider =
    FutureProvider.family<LlmSummaryRepository, String>((
      ref,
      folderPath,
    ) async {
      // Normalize via folderDbKey so this resolves the SAME novel_data.db thin-view
      // the registry/folder-switch flow evicts & invalidates (which key on
      // folderDbKey). Reading the raw path would key a distinct provider entry that
      // never gets invalidated and could serve a closed handle.
      final db = await ref
          .watch(novelDataDatabaseProvider(folderDbKey(folderPath)))
          .database;
      return LlmSummaryRepository(db);
    });

/// Folder-scoped `FactCacheRepository`, backed by the novel's per-folder
/// `novel_data.db`. The family argument is the novel folder's absolute path.
final factCacheRepositoryProvider =
    FutureProvider.family<FactCacheRepository, String>((ref, folderPath) async {
      final db = await ref
          .watch(novelDataDatabaseProvider(folderDbKey(folderPath)))
          .database;
      return FactCacheRepository(db);
    });

/// Folder-scoped `LlmSummaryService`. The family argument is the novel folder's
/// absolute path; the service's repositories are bound to that folder's
/// `novel_data.db`. Returns null while async dependencies load or no LLM is
/// configured.
final llmSummaryServiceProvider = Provider.family<LlmSummaryService?, String>((
  ref,
  folderPath,
) {
  final clientAsync = ref.watch(llmClientProvider);
  final client = clientAsync.value;
  if (client == null) return null;

  final repoAsync = ref.watch(llmSummaryRepositoryProvider(folderPath));
  final repo = repoAsync.value;
  if (repo == null) return null;

  final factCacheAsync = ref.watch(factCacheRepositoryProvider(folderPath));
  final factCache = factCacheAsync.value;
  if (factCache == null) return null;

  final searchService = ref.watch(textSearchServiceProvider);
  return LlmSummaryService(
    llmClient: client,
    repository: repo,
    factCacheRepository: factCache,
    searchService: searchService,
  );
});

/// Whether word summaries can be produced on this platform.
///
/// Analysis reaches an LLM server the reader runs themselves, addressed by
/// default at a plaintext `http://` endpoint. That is not something a platform
/// takes away: the requests go through `dart:io`'s `HttpClient`, which opens
/// its own sockets and never reaches the layer a transport policy is enforced
/// in. Every platform therefore reports the feature as supported today.
///
/// Two things about an iPad are worth knowing here even so, because neither is
/// a capability. The default endpoint names the machine the app runs on, which
/// on a tablet is not where the server lives, so a reader has to point the
/// settings section at their own host. And reaching that host over the local
/// network needs a usage description in the iOS project and the reader's
/// permission, which they can refuse and later revoke; the attempt that raises
/// the prompt fails while it is up, so a retry is what makes a granted
/// permission visible. A loopback address, which is what the simulator reaches
/// on the developer's own machine, is subject to neither.
///
/// Reading already-stored summaries is not gated: a library folder carried
/// over from a desktop install keeps its analysis history browsable.
final llmSummarySupportedProvider = Provider<bool>(
  (ref) => ref.watch(platformCapabilitiesProvider).llmSummary,
);
