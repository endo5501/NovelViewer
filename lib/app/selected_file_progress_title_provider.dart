import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

const _kAppTitleFallback = 'NovelViewer';

/// AppBar 表示用の組み立て済みタイトル文字列。
///
/// 形式:
/// - ライブラリルート / 小説タイトル解決不能 → `NovelViewer`
/// - 小説フォルダ + ファイル未選択 → `{小説名}`
/// - 小説フォルダ + ファイル選択中 + 一覧内 → `{小説名} — {ファイル名} (N/M)`
/// - 小説フォルダ + ファイル選択中 + 一覧外 → `{小説名}` (進捗算出不可のため fallback)
final selectedFileProgressTitleProvider = Provider<String>((ref) {
  final base =
      ref.watch(selectedNovelTitleProvider).value ?? _kAppTitleFallback;

  final selected = ref.watch(selectedFileProvider);
  if (selected == null) return base;

  final files = ref.watch(directoryContentsProvider).value?.files ?? const [];
  if (files.isEmpty) return base;

  final idx = files.indexWhere((f) => f.path == selected.path);
  if (idx < 0) return base;

  return '$base — ${selected.name} (${idx + 1}/${files.length})';
});
