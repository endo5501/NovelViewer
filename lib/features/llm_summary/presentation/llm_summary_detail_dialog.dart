import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/outlined_text_badge.dart';
import 'package:novel_viewer/features/llm_summary/presentation/summary_snapshot_view.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_detail_provider.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Read-only dialog launched from the analysis-history context menu. Shows two
/// tabs for the selected [word]: the cached Stage-1 facts (`fact_cache`) per
/// source file, and the analysis-result snapshots (`word_summaries`) reusing
/// the hover popup's summary card. Performs no mutation of either table.
class LlmSummaryDetailDialog extends StatelessWidget {
  const LlmSummaryDetailDialog({
    super.key,
    required this.folderPath,
    required this.word,
  });

  /// Absolute path of the novel folder, used to resolve its per-folder
  /// `novel_data.db`.
  final String folderPath;
  final String word;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.historyDetail_dialogTitle(word)),
      content: SizedBox(
        width: 480,
        height: 420,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: l10n.historyDetail_factsTab),
                  Tab(text: l10n.historyDetail_resultTab),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _FactsTab(folderPath: folderPath, word: word),
                    _ResultTab(folderPath: folderPath, word: word),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

/// "事実" tab: per-file list of cached Stage-1 facts. Invalidated rows
/// (sentinel `content_hash`) are kept and greyed out with an "無効" badge.
class _FactsTab extends ConsumerWidget {
  const _FactsTab({required this.folderPath, required this.word});

  final String folderPath;
  final String word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final factsAsync = ref.watch(
      historyDetailFactsProvider((folderPath: folderPath, word: word)),
    );

    return factsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (facts) {
        if (facts.isEmpty) {
          return Center(child: Text(l10n.historyDetail_noFacts));
        }
        // Display per file in ascending file-name order. Sorting here (not
        // only in the provider) keeps the display guarantee at the
        // presentation layer regardless of how the list was sourced.
        final sorted = [...facts]
          ..sort((a, b) => a.fileName.compareTo(b.fileName));
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const Divider(height: 16),
          itemBuilder: (context, index) => _FactSection(entry: sorted[index]),
        );
      },
    );
  }
}

class _FactSection extends StatelessWidget {
  const _FactSection({required this.entry});

  final FactCacheEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isInvalid = entry.contentHash == FactCacheRepository.sentinelHash;

    final section = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.fileName,
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (isInvalid) ...[
              const SizedBox(width: 8),
              OutlinedTextBadge(label: l10n.historyDetail_invalidBadge),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(entry.facts, style: theme.textTheme.bodyMedium),
      ],
    );

    if (isInvalid) {
      return Opacity(opacity: 0.4, child: section);
    }
    return section;
  }
}

/// "解析結果" tab: reuses [SummarySnapshotView] to display the word's snapshots
/// with prev/next navigation. Defaults to the latest (highest-episode)
/// snapshot. Read-only — no re-analyze affordance is passed.
class _ResultTab extends ConsumerStatefulWidget {
  const _ResultTab({required this.folderPath, required this.word});

  final String folderPath;
  final String word;

  @override
  ConsumerState<_ResultTab> createState() => _ResultTabState();
}

class _ResultTabState extends ConsumerState<_ResultTab> {
  int? _selectedEpisode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snapshotsAsync = ref.watch(
      hoverPopupCacheProvider(
        (folderPath: widget.folderPath, word: widget.word),
      ),
    );

    return snapshotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (snapshots) {
        if (snapshots.isEmpty) {
          return Center(child: Text(l10n.historyDetail_noResults));
        }
        // Default to the latest snapshot (snapshots are sorted ascending).
        final displayed = _resolveDisplayed(snapshots);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: SummarySnapshotView(
            snapshots: snapshots,
            displayed: displayed,
            keyPrefix: 'history_detail',
            onSelectEpisode: (episode) =>
                setState(() => _selectedEpisode = episode),
          ),
        );
      },
    );
  }

  WordSummary _resolveDisplayed(List<WordSummary> snapshots) {
    final selected = _selectedEpisode;
    if (selected != null) {
      for (final s in snapshots) {
        if (s.coveredUpToEpisode == selected) return s;
      }
    }
    return snapshots.last;
  }
}
