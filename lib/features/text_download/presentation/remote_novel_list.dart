import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';
import 'package:novel_viewer/features/progress_sync/providers/remote_novel_candidates_provider.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// "Novels read on other devices" in the download dialog
/// (remote-novel-download): the novels other devices read that this device
/// does not have, newest first. Choosing one hands its URL to [onSelected];
/// the download itself still waits for the start button. Absent when there is
/// nothing to offer, which includes a build without sync and signed out.
class RemoteNovelList extends ConsumerStatefulWidget {
  const RemoteNovelList({
    super.key,
    required this.enabled,
    required this.onSelected,
  });

  /// Whether the dialog takes a URL right now.
  final bool enabled;
  final ValueChanged<String> onSelected;

  /// How many rows show before "show all".
  static const initialCount = 5;

  /// The most the list grows to before it scrolls, so it never pushes the URL
  /// field and the start button off a phone screen.
  static const maxListHeight = 240.0;

  @override
  ConsumerState<RemoteNovelList> createState() => _RemoteNovelListState();
}

class _RemoteNovelListState extends ConsumerState<RemoteNovelList> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final candidates =
        ref.watch(remoteNovelCandidatesProvider).asData?.value ??
        const <RemoteProgress>[];
    if (candidates.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final collapsed =
        !_showAll && candidates.length > RemoteNovelList.initialCount;
    final shown = collapsed
        ? candidates.take(RemoteNovelList.initialCount).toList()
        : candidates;

    return Column(
      key: const Key('download_remote_novels'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.download_remoteNovelsTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: RemoteNovelList.maxListHeight,
          ),
          // Not a ListView: the dialog measures its content's intrinsic size,
          // which a lazy viewport refuses. A few hundred rows at most.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (final remote in shown) _buildRow(remote)],
            ),
          ),
        ),
        if (collapsed)
          TextButton(
            key: const Key('download_remote_novels_show_all'),
            onPressed: () => setState(() => _showAll = true),
            child: Text(l10n.download_remoteNovelsShowAll(candidates.length)),
          ),
        // The dialog spaces its sections 16 apart; only a list that shows
        // takes its share of that.
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRow(RemoteProgress remote) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final record = remote.record;
    // Only records with a URL are offered.
    final url = record.url!;
    final readAt = DateFormat.yMd(
      locale,
    ).add_Hm().format(record.readAt.toLocal());
    return ListTile(
      key: Key('download_remote_novel_${record.novelId}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      enabled: widget.enabled,
      title: Text(
        // Some site parsers store '' when a title is missing.
        switch (record.title) {
          final title? when title.isNotEmpty => title,
          _ => url,
        },
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        l10n.download_remoteNovelRow(remote.deviceName, record.episode, readAt),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: widget.enabled ? () => widget.onSelected(url) : null,
    );
  }
}
