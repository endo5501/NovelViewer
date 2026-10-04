import 'dart:isolate';

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

/// Every stored reference-source relation.
///
/// Auto-disposed, so a read made once nobody holds the previous one goes to
/// the database. A cache kept beyond its readers would go on naming a novel
/// deleted since: analysis would fail on it as a missing source, and a
/// dialog seeded from it would save the relation back. Writers still
/// invalidate it for the readers that are holding it.
final novelReferenceRelationsProvider =
    FutureProvider.autoDispose<List<ReferenceRelation>>((ref) {
      return ref.watch(novelReferenceRepositoryProvider).findAll();
    });

/// Finds registered novel folders in the library; see [locateNovelFolders].
/// A provider so the walk can be observed or replaced in tests.
typedef NovelFolderLocator =
    Future<Map<String, String>> Function({
      required String libraryRoot,
      required Set<String> registeredFolderNames,
    });

/// Walks on a background isolate: the walk lists every organizing folder in
/// the library, and on a large library or a slow drive that would otherwise
/// freeze the UI before the analysis modal appears.
final novelFolderLocatorProvider = Provider<NovelFolderLocator>(
  (ref) =>
      ({required libraryRoot, required registeredFolderNames}) => Isolate.run(
        () => locateNovelFolders(
          libraryRoot: libraryRoot,
          registeredFolderNames: registeredFolderNames,
        ),
      ),
);
