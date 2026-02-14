import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';

final novelDatabaseProvider = Provider<NovelDatabase>((ref) {
  throw UnimplementedError('novelDatabaseProvider must be overridden at startup');
});

final novelRepositoryProvider = Provider<NovelRepository>((ref) {
  return NovelRepository(ref.watch(novelDatabaseProvider));
});

final allNovelsProvider = FutureProvider<List<NovelMetadata>>((ref) {
  final repository = ref.watch(novelRepositoryProvider);
  return repository.findAll();
});
