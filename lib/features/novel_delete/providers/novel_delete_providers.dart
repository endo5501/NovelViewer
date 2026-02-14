import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/novel_delete/data/novel_delete_service.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';

final novelDeleteServiceProvider =
    FutureProvider<NovelDeleteService>((ref) async {
  final novelRepository = ref.watch(novelRepositoryProvider);
  final summaryRepository =
      await ref.watch(llmSummaryRepositoryProvider.future);
  final fileSystemService = ref.watch(fileSystemServiceProvider);
  return NovelDeleteService(
    novelRepository: novelRepository,
    summaryRepository: summaryRepository,
    fileSystemService: fileSystemService,
  );
});
