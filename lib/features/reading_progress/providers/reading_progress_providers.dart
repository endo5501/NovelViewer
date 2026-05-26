import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';

final readingProgressRepositoryProvider =
    Provider<ReadingProgressRepository>((ref) {
  return ReadingProgressRepository(ref.watch(novelDatabaseProvider));
});
