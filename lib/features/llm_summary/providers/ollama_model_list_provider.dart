import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/data/ollama_client.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

/// Fetches the list of installed models from an Ollama server.
///
/// Keyed by base URL so changing the URL automatically starts a fresh fetch
/// and `autoDispose` releases the previous entry once nothing watches it,
/// replacing the ad-hoc generation counter that the dialog previously used to
/// cancel stale requests.
final ollamaModelListProvider =
    FutureProvider.autoDispose.family<List<String>, String>(
  (ref, baseUrl) async {
    final httpClient = ref.watch(httpClientProvider);
    return OllamaClient.fetchModels(
      baseUrl: baseUrl,
      httpClient: httpClient,
    );
  },
);
