import 'package:flutter/material.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Read-only presentational view of a single `word_summaries` snapshot: a
/// prev/next snapshot navigator (with an optional future-snapshot warning and
/// an optional [trailing] action) above the snapshot's summary text. Holds no
/// selection state — the caller supplies the [displayed] snapshot and is
/// notified of navigation via [onSelectEpisode].
///
/// Shared by the hover popup (`hover_popup_widget.dart`) and the history detail
/// dialog so both render summaries identically. [keyPrefix] namespaces the
/// widget keys so each host can target its own selector in tests.
class SummarySnapshotView extends StatelessWidget {
  const SummarySnapshotView({
    super.key,
    required this.snapshots,
    required this.displayed,
    required this.onSelectEpisode,
    required this.keyPrefix,
    this.showWarning = false,
    this.trailing,
  });

  /// All snapshots for the word, sorted ascending by `coveredUpToEpisode`.
  final List<WordSummary> snapshots;

  /// The snapshot currently shown; must be an element of [snapshots].
  final WordSummary displayed;

  /// Called with the newly selected snapshot's `coveredUpToEpisode` when the
  /// user taps the prev/next navigator.
  final ValueChanged<int> onSelectEpisode;

  /// Namespaces widget keys, e.g. `hover_popup` or `history_detail`.
  final String keyPrefix;

  /// Whether to show the future-snapshot warning icon next to the navigator.
  final bool showWarning;

  /// Optional action placed to the right of the navigator (e.g. the hover
  /// popup's re-analyze menu button). The detail dialog passes none, keeping
  /// the view read-only.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SnapshotSelector(
                snapshots: snapshots,
                displayed: displayed,
                onSelectEpisode: onSelectEpisode,
                showWarning: showWarning,
                keyPrefix: keyPrefix,
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        Text(
          displayed.summary,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _SnapshotSelector extends StatelessWidget {
  const _SnapshotSelector({
    required this.snapshots,
    required this.displayed,
    required this.onSelectEpisode,
    required this.showWarning,
    required this.keyPrefix,
  });

  final List<WordSummary> snapshots;
  final WordSummary displayed;
  final ValueChanged<int> onSelectEpisode;
  final bool showWarning;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currentIndex = snapshots.indexWhere(
        (s) => s.coveredUpToEpisode == displayed.coveredUpToEpisode);
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex >= 0 && currentIndex < snapshots.length - 1;

    return Row(
      key: Key('${keyPrefix}_snapshot_selector'),
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('${keyPrefix}_snapshot_prev'),
          icon: const Icon(Icons.chevron_left, size: 18),
          tooltip: l10n.hoverPopup_snapshotNavPrev,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: hasPrev
              ? () =>
                  onSelectEpisode(snapshots[currentIndex - 1].coveredUpToEpisode)
              : null,
        ),
        const SizedBox(width: 4),
        Text(
          l10n.hoverPopup_snapshotLabel(displayed.coveredUpToEpisode),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(width: 4),
        IconButton(
          key: Key('${keyPrefix}_snapshot_next'),
          icon: const Icon(Icons.chevron_right, size: 18),
          tooltip: l10n.hoverPopup_snapshotNavNext,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: hasNext
              ? () =>
                  onSelectEpisode(snapshots[currentIndex + 1].coveredUpToEpisode)
              : null,
        ),
        if (showWarning) ...[
          const SizedBox(width: 4),
          Tooltip(
            key: Key('${keyPrefix}_future_warning'),
            message: l10n.hoverPopup_futureSnapshotWarning,
            child: Icon(
              Icons.warning_amber_outlined,
              size: 14,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ],
    );
  }
}
