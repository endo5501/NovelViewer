import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_history_menu.dart';
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
        leading: _TypeBadge(type: entry.type),
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
                  _UntrackedBadge(),
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
    final value = await showMenu<HistoryContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: buildHistoryContextMenuItems(
        type: entry.type,
        deleteLabel: l10n.bookmark_deleteMenuItem,
        copyNoSpoilerLabel: '要約をコピー(ネタバレなし)',
        copySpoilerLabel: '要約をコピー(ネタバレあり)',
      ),
    );

    if (value == null) return;
    dispatchHistoryContextAction(
      value,
      noSpoilerSummary: entry.noSpoilerSummary,
      spoilerSummary: entry.spoilerSummary,
      onCopy: (text) async {
        await Clipboard.setData(ClipboardData(text: text));
        messenger.showSnackBar(
          const SnackBar(content: Text('クリップボードにコピーしました')),
        );
      },
      onDelete: () => ref
          .read(llmSummaryHistoryProvider.notifier)
          .deleteEntry(entry.word),
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

class _TypeBadge extends StatelessWidget {
  final HistoryEntryType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final (label, color) = switch (type) {
      HistoryEntryType.both => (
          l10n.llmHistory_typeBoth,
          theme.colorScheme.primary,
        ),
      HistoryEntryType.noSpoilerOnly => (
          l10n.llmHistory_typeNoSpoiler,
          theme.colorScheme.secondary,
        ),
      HistoryEntryType.spoilerOnly => (
          l10n.llmHistory_typeSpoiler,
          theme.colorScheme.tertiary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _UntrackedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).disabledColor),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        l10n.llmHistory_untrackedBadge,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).disabledColor,
        ),
      ),
    );
  }
}
