import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_refresh/domain/refresh_target.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Starts a re-download of [target] and puts its progress on screen.
///
/// Shared by the two entry points a refresh has — the app bar's button, for
/// the novel being read, and the file browser's context menu, for one that is
/// not — so that neither knows anything the other does not. Refusing to
/// interrupt work already in flight is part of that: the guard belongs here
/// rather than in each caller.
void startNovelRefresh(
  BuildContext context,
  WidgetRef ref,
  RefreshTarget target,
) {
  final downloadState = ref.read(downloadProvider);
  if (downloadState.status == DownloadStatus.downloading) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.fileBrowser_downloadInProgressWarning,
        ),
      ),
    );
    return;
  }

  ref
      .read(downloadProvider.notifier)
      .refreshNovel(target.folderName, parentPath: target.parentPath);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => RefreshProgressDialog(novelTitle: target.title),
  );
}

/// The progress of a refresh, from the first index page to the episode count
/// it finished with.
///
/// Dismissal is deliberate rather than incidental: the dialog holds on its
/// result until the reader closes it, and while the download is still running
/// the only way out is to cancel it. A refresh now starts from a single tap on
/// the app bar, so a reader who did not mean to start one needs a way to stop
/// it — the same one the download dialog offers, down to the strings.
class RefreshProgressDialog extends ConsumerWidget {
  final String novelTitle;

  const RefreshProgressDialog({super.key, required this.novelTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.fileBrowser_refreshProgressTitle(novelTitle)),
      content: _buildContent(context, downloadState),
      actions: [
        if (downloadState.status == DownloadStatus.idle ||
            downloadState.status == DownloadStatus.downloading)
          TextButton(
            key: const Key('refresh_cancel_button'),
            onPressed: () => ref.read(downloadProvider.notifier).cancel(),
            child: Text(l10n.common_cancelButton),
          ),
        if (downloadState.status == DownloadStatus.completed ||
            downloadState.status == DownloadStatus.error ||
            downloadState.status == DownloadStatus.cancelled)
          TextButton(
            key: const Key('refresh_close_button'),
            onPressed: () {
              if (downloadState.status == DownloadStatus.completed) {
                ref.invalidate(allNovelsProvider);
                ref.invalidate(directoryContentsProvider);
              }
              ref.read(downloadProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            child: Text(l10n.common_closeButton),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, DownloadState state) {
    final l10n = AppLocalizations.of(context)!;

    String failedSuffix(int failed) {
      if (failed <= 0) return '';
      final lang = Localizations.localeOf(context).languageCode;
      return switch (lang) {
        'ja' => ' (失敗: $failed件)',
        'zh' => ' （失败：$failed个）',
        _ => ' (failed: $failed)',
      };
    }

    String episodeSummary(DownloadState s) {
      if (s.totalEpisodes <= 0) return '';
      final skipped = s.skippedEpisodes > 0
          ? l10n.fileBrowser_skippedEpisodesSuffix(s.skippedEpisodes)
          : '';
      final tail = skipped + failedSuffix(s.failedEpisodes);
      return l10n.fileBrowser_episodeCountFormat(s.totalEpisodes, tail);
    }

    switch (state.status) {
      case DownloadStatus.idle:
      case DownloadStatus.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            if (state.totalEpisodes > 0)
              Text('${state.currentEpisode} / ${episodeSummary(state)}'),
          ],
        );
      case DownloadStatus.completed:
        final summary = episodeSummary(state);
        final completedText = Text(
          l10n.fileBrowser_refreshCompleted(
            summary.isNotEmpty ? '\n$summary' : '',
          ),
        );
        if (!state.indexTruncated) return completedText;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            completedText,
            const SizedBox(height: 8),
            Text(
              l10n.download_indexTruncatedWarning,
              style: const TextStyle(color: Colors.orange),
            ),
          ],
        );
      case DownloadStatus.cancelled:
        return Text(l10n.download_cancelledMessage);
      case DownloadStatus.error:
        return Text(
          l10n.common_errorPrefix(
            state.errorMessage ?? l10n.common_unknownError,
          ),
          style: const TextStyle(color: Colors.red),
        );
    }
  }
}
