import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_context/providers/reading_context_providers.dart';
import 'package:path/path.dart' as p;

const _kAppTitleFallback = 'NovelViewer';

/// AppBar 表示用の組み立て済みタイトル文字列。
///
/// 形式:
/// - 表示中のエピソードなし → `NovelViewer`
/// - 表示中のエピソードあり + 一覧内 → `{小説名} — {ファイル名} (N/M)`
/// - 表示中のエピソードあり + 一覧外 → `{小説名}` (進捗算出不可のため fallback)
///
/// The app bar sits above the body, so it answers "what am I reading" — and
/// since the file browser moved into a drawer, the browser's location is no
/// longer an answer to that. Everything here comes from the open episode and
/// the novel folder it belongs to; neither [currentDirectoryProvider] nor
/// [directoryContentsProvider] is consulted.
final selectedFileProgressTitleProvider = Provider<String>((ref) {
  final selected = ref.watch(selectedFileProvider);
  if (selected == null) return _kAppTitleFallback;

  final folder = ref.watch(readingNovelFolderProvider);
  if (folder == null) return _kAppTitleFallback;

  // A registered novel is named by its metadata; anything else — a folder of
  // hand-placed text — is named by its folder, as it always has been.
  final novels =
      ref.watch(allNovelsProvider).value ?? const <NovelMetadata>[];
  final folderName = p.basename(folder);
  final base =
      novels
          .where((novel) => novel.folderName == folderName)
          .firstOrNull
          ?.title ??
      folderName;

  final episodes = ref.watch(readingEpisodesProvider).value ?? const [];
  if (episodes.isEmpty) return base;

  final idx = episodes.indexWhere((f) => f.path == selected.path);
  if (idx < 0) return base;

  return '$base — ${selected.name} (${idx + 1}/${episodes.length})';
});
