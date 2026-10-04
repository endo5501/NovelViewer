import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_reference/data/novel_reference_repository.dart';
import 'package:novel_viewer/features/novel_reference/domain/reference_graph.dart';
import 'package:novel_viewer/shared/utils/novel_folder_locator.dart';

final novelReferenceRepositoryProvider = Provider<NovelReferenceRepository>((
  ref,
) {
  return NovelReferenceRepository(ref.watch(novelDatabaseProvider));
});

/// Every stored reference-source relation. Invalidate after saving.
final novelReferenceRelationsProvider = FutureProvider<List<ReferenceRelation>>(
  (ref) {
    return ref.watch(novelReferenceRepositoryProvider).findAll();
  },
);

/// The signature of [locateNovelFolders], so the walk can be observed or
/// replaced in tests.
typedef NovelFolderLocator =
    Map<String, String> Function({
      required String libraryRoot,
      required Set<String> registeredFolderNames,
    });

final novelFolderLocatorProvider = Provider<NovelFolderLocator>(
  (ref) => locateNovelFolders,
);
