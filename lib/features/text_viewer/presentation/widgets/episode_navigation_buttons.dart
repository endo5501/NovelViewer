import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/episode_navigation/providers/adjacent_files_provider.dart';
import 'package:novel_viewer/features/episode_navigation/providers/episode_navigation_controller.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// A small floating bar with "← Previous" and "Next →" buttons that the
/// horizontal-mode text viewer overlays on its content. Buttons disable
/// themselves at directory boundaries.
class EpisodeNavigationButtons extends ConsumerWidget {
  const EpisodeNavigationButtons({super.key});

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
          OutlinedButton(
            key: const Key('episode_nav_prev_button'),
            onPressed: adjacent.prev == null
                ? null
                : () => controller.navigateToPrevious(),
            child: Text(l10n.textViewer_prevEpisodeButton),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: const Key('episode_nav_next_button'),
            onPressed:
                adjacent.next == null ? null : () => controller.navigateToNext(),
            child: Text(l10n.textViewer_nextEpisodeButton),
          ),
        ],
      ),
    );
  }
}
