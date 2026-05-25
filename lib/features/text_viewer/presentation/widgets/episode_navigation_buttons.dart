import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/episode_navigation/providers/adjacent_files_provider.dart';
import 'package:novel_viewer/features/episode_navigation/providers/episode_navigation_controller.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// "← Previous" and "Next →" buttons used by the horizontal-mode viewer at
/// scroll boundaries. Callers can independently hide either side by setting
/// [showPrev] / [showNext] to false — typical use is to show only the prev
/// button when scrolled to the top and only the next button when scrolled to
/// the bottom, avoiding overlap with body text in the middle of the file.
class EpisodeNavigationButtons extends ConsumerWidget {
  const EpisodeNavigationButtons({
    super.key,
    this.showPrev = true,
    this.showNext = true,
  });

  final bool showPrev;
  final bool showNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adjacent = ref.watch(adjacentFilesProvider);
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(episodeNavigationControllerProvider);

    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPrev)
            OutlinedButton(
              key: const Key('episode_nav_prev_button'),
              onPressed: adjacent.prev == null
                  ? null
                  : () => controller.navigateToPrevious(),
              child: Text(l10n.textViewer_prevEpisodeButton),
            ),
          if (showPrev && showNext) const SizedBox(width: 8),
          if (showNext)
            OutlinedButton(
              key: const Key('episode_nav_next_button'),
              onPressed: adjacent.next == null
                  ? null
                  : () => controller.navigateToNext(),
              child: Text(l10n.textViewer_nextEpisodeButton),
            ),
        ],
      ),
    );
  }
}
