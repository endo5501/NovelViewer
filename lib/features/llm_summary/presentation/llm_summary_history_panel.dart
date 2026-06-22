import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_detail_dialog.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_history_menu.dart';
import 'package:novel_viewer/features/llm_summary/presentation/outlined_text_badge.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

class LlmSummaryHistoryPanel extends ConsumerWidget {
  const LlmSummaryHistoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final directory = ref.watch(currentDirectoryProvider);
    final libraryPath = ref.watch(libraryPathProvider);

    final isAtRoot = directory == null ||
        (libraryPath != null && p.equals(directory, libraryPath));
    if (isAtRoot) {
      return Center(child: Text(l10n.bookmark_selectNovelPrompt));
    }

    final historyAsync = ref.watch(llmSummaryHistoryProvider);

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(child: Text(l10n.llmHistory_noEntries));
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) =>
              _HistoryEntryTile(entry: entries[index]),
        );
      },
    );
  }
}

class _HistoryEntryTile extends ConsumerWidget {
  final HistoryEntry entry;

  const _HistoryEntryTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tile = GestureDetector(
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      child: ListTile(
        leading: _SnapshotsBadge(count: entry.snapshotCount),
        title: Text(entry.word),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.summaryPreview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Text(
                  _formatDate(entry.updatedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!entry.isJumpable) ...[
                  const SizedBox(width: 8),
                  OutlinedTextBadge(
                    label: AppLocalizations.of(context)!.llmHistory_untrackedBadge,
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: entry.isJumpable ? () => _jumpToEntry(context, ref) : null,
      ),
    );

    if (!entry.isJumpable) {
      return Opacity(opacity: 0.5, child: tile);
    }
    return tile;
  }

  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final directory = ref.read(currentDirectoryProvider);
    final value = await showMenu<HistoryContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: buildHistoryContextMenuItems(entry: entry, l10n: l10n),
    );

    if (value == null) return;
    dispatchHistoryContextAction(
      value,
      entry: entry,
      onCopy: (text) async {
        await Clipboard.setData(ClipboardData(text: text));
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.contextMenu_copiedToClipboard)),
        );
      },
      onDelete: () => ref
          .read(llmSummaryHistoryProvider.notifier)
          .deleteEntry(entry.word),
      onViewDetails: () {
        if (directory == null || !context.mounted) return;
        showDialog<void>(
          context: context,
          builder: (_) => LlmSummaryDetailDialog(
            folderPath: directory,
            word: entry.word,
          ),
        );
      },
    );
  }

  Future<void> _jumpToEntry(BuildContext context, WidgetRef ref) {
    return ref.read(llmSummaryHistoryProvider.notifier).openEntry(entry);
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _SnapshotsBadge extends StatelessWidget {
  final int count;

  const _SnapshotsBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        l10n.llmHistory_snapshotsBadge(count),
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}

