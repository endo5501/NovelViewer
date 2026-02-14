import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/llm_summary/data/ollama_client.dart';
import 'package:novel_viewer/features/llm_summary/data/openai_compatible_client.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:path/path.dart' as p;

final llmConfigProvider = Provider<LlmConfig>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getLlmConfig();
});

final llmClientProvider = Provider<LlmClient?>((ref) {
  final config = ref.watch(llmConfigProvider);
  return switch (config.provider) {
    LlmProvider.ollama => OllamaClient(
        baseUrl: config.baseUrl,
        model: config.model,
      ),
    LlmProvider.openai => OpenAiCompatibleClient(
        baseUrl: config.baseUrl,
        apiKey: config.apiKey,
        model: config.model,
      ),
    LlmProvider.none => null,
  };
});

final llmSummaryRepositoryProvider =
    FutureProvider<LlmSummaryRepository>((ref) async {
  final novelDb = ref.watch(novelDatabaseProvider);
  final db = await novelDb.database;
  return LlmSummaryRepository(db);
});

final llmSummaryServiceProvider = Provider<LlmSummaryService?>((ref) {
  final client = ref.watch(llmClientProvider);
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

class LlmSummaryState {
  final WordSummary? cachedSummary;
  final bool isLoading;
  final String? error;
  final String? currentSummary;

  const LlmSummaryState({
    this.cachedSummary,
    this.isLoading = false,
    this.error,
    this.currentSummary,
  });
}

class LlmSummaryNotifier extends Notifier<LlmSummaryState> {
  @override
  LlmSummaryState build() => const LlmSummaryState();

  Future<void> loadCache({
    required String folderName,
    required String word,
    required SummaryType summaryType,
  }) async {
    final repo = await ref.read(llmSummaryRepositoryProvider.future);

    final cached = await repo.findSummary(
      folderName: folderName,
      word: word,
      summaryType: summaryType,
    );

    state = LlmSummaryState(
      cachedSummary: cached,
      currentSummary: cached?.summary,
    );
  }

  Future<void> analyze({
    required SummaryType summaryType,
  }) async {
    final service = ref.read(llmSummaryServiceProvider);
    if (service == null) return;

    final directory = ref.read(currentDirectoryProvider);
    if (directory == null) return;

    final selectedText = ref.read(selectedTextProvider);
    if (selectedText == null || selectedText.isEmpty) return;

    final selectedFile = ref.read(selectedFileProvider);
    final folderName = p.basename(directory);

    state = LlmSummaryState(
      cachedSummary: state.cachedSummary,
      isLoading: true,
    );

    try {
      final result = await service.generateSummary(
        directoryPath: directory,
        folderName: folderName,
        word: selectedText,
        summaryType: summaryType,
        currentFileName: selectedFile?.name,
      );

      state = LlmSummaryState(currentSummary: result);
    } catch (e) {
      state = LlmSummaryState(error: e.toString());
    }
  }
}

final llmSpoilerSummaryProvider =
    NotifierProvider<LlmSummaryNotifier, LlmSummaryState>(
  LlmSummaryNotifier.new,
);

final llmNoSpoilerSummaryProvider =
    NotifierProvider<LlmSummaryNotifier, LlmSummaryState>(
  LlmSummaryNotifier.new,
);
