import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/llm_summary/data/ollama_client.dart';
import 'package:novel_viewer/features/llm_summary/data/openai_compatible_client.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';

final llmConfigProvider = Provider<LlmConfig>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getLlmConfig();
});

final llmClientProvider = FutureProvider<LlmClient?>((ref) async {
  final config = ref.watch(llmConfigProvider);
  switch (config.provider) {
    case LlmProvider.ollama:
      return OllamaClient(
        baseUrl: config.baseUrl,
        model: config.model,
      );
    case LlmProvider.openai:
      final apiKey =
          await ref.watch(settingsRepositoryProvider).getApiKey();
      if (apiKey.isEmpty) {
        return null;
      }
      return OpenAiCompatibleClient(
        baseUrl: config.baseUrl,
        apiKey: apiKey,
        model: config.model,
      );
    case LlmProvider.none:
      return null;
  }
});

final llmSummaryRepositoryProvider =
    FutureProvider<LlmSummaryRepository>((ref) async {
  final novelDb = ref.watch(novelDatabaseProvider);
  final db = await novelDb.database;
  return LlmSummaryRepository(db);
});

final llmSummaryServiceProvider = Provider<LlmSummaryService?>((ref) {
  final clientAsync = ref.watch(llmClientProvider);
  final client = clientAsync.value;
  if (client == null) return null;

  final repoAsync = ref.watch(llmSummaryRepositoryProvider);
  final repo = repoAsync.value;
  if (repo == null) return null;

  final searchService = ref.watch(textSearchServiceProvider);
  return LlmSummaryService(
    llmClient: client,
    repository: repo,
    searchService: searchService,
  );
});

