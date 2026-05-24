import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';

/// Inline popup shown above a marked word when the pointer hovers it. Reads
/// the cached `word_summaries` rows for (folder, word), decides which type to
/// display from the [hoverPopupProvider] state, and renders the summary plus
/// optional toggle and reference-position warning. Content is non-selectable
/// — copy support lives in the history panel.
class HoverPopupWidget extends ConsumerWidget {
  const HoverPopupWidget({
    super.key,
    required this.folder,
    required this.word,
    required this.currentFileName,
  });

  final String folder;
  final String word;
  final String? currentFileName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheAsync = ref.watch(
      hoverPopupCacheProvider(
        HoverPopupCacheKey(folder: folder, word: word),
      ),
    );
    final activeType = ref.watch(
      hoverPopupProvider.select((s) => s.activeType),
    );

    return cacheAsync.when(
      loading: _LoadingCard.new,
      error: (_, _) => const SizedBox.shrink(),
      data: (summaries) {
        final hasBoth =
            summaries.noSpoiler != null && summaries.spoiler != null;
        final displayed = switch (activeType) {
          SummaryType.noSpoiler =>
            summaries.noSpoiler ?? summaries.spoiler,
          SummaryType.spoiler => summaries.spoiler ?? summaries.noSpoiler,
        };
        if (displayed == null) return const SizedBox.shrink();

        final showWarning = activeType == SummaryType.noSpoiler &&
            summaries.noSpoiler != null &&
            summaries.noSpoiler!.sourceFile != null &&
            summaries.noSpoiler!.sourceFile != currentFileName;

        return _Card(
          summaryText: displayed.summary,
          showToggle: hasBoth,
          activeType: activeType,
          onTypeChange: (t) =>
              ref.read(hoverPopupProvider.notifier).setSummaryType(t),
          showReferenceWarning: showWarning,
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.summaryText,
    required this.showToggle,
    required this.activeType,
    required this.onTypeChange,
    required this.showReferenceWarning,
  });

  final String summaryText;
  final bool showToggle;
  final SummaryType activeType;
  final ValueChanged<SummaryType> onTypeChange;
  final bool showReferenceWarning;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('hover_popup_card'),
      elevation: 4,
      borderRadius: BorderRadius.circular(6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showToggle) ...[
                _TypeToggle(active: activeType, onChange: onTypeChange),
                const SizedBox(height: 8),
              ],
              Text(
                summaryText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (showReferenceWarning) ...[
                const SizedBox(height: 8),
                const _ReferenceWarning(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.active, required this.onChange});

  final SummaryType active;
  final ValueChanged<SummaryType> onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget pill(SummaryType type, String label, Key key) {
      final selected = active == type;
      return Material(
        key: key,
        color: selected ? theme.colorScheme.primary : Colors.transparent,
        child: InkWell(
          onTap: () => onChange(type),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: const Key('hover_popup_type_toggle'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill(
            SummaryType.noSpoiler,
            'なし',
            const Key('hover_popup_type_no_spoiler'),
          ),
          pill(
            SummaryType.spoiler,
            'あり',
            const Key('hover_popup_type_spoiler'),
          ),
        ],
      ),
    );
  }
}

class _ReferenceWarning extends StatelessWidget {
  const _ReferenceWarning();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('hover_popup_reference_warning'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_outlined,
          size: 14,
          color: Colors.orange.shade700,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '別ファイルで解析した要約です',
            style: TextStyle(
              fontSize: 11,
              color: Colors.orange.shade700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Material(
      key: Key('hover_popup_card'),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          key: Key('hover_popup_loading'),
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
