import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/novel_update_check/providers/novel_update_check_providers.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Starts the library-wide update check and shows its progress.
///
/// Refuses while a download or refresh is running, with the same warning a
/// refresh gives, so two operations never pace requests to one site
/// independently of each other.
void startNovelUpdateCheck(BuildContext context, WidgetRef ref) {
  if (ref.read(downloadProvider).status == DownloadStatus.downloading) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.fileBrowser_downloadInProgressWarning,
        ),
      ),
    );
    return;
  }

  ref.read(novelUpdateCheckProvider.notifier).start();

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const UpdateCheckProgressDialog(),
  );
}

/// Progress of the update check, then its summary. While the check runs the
/// only way out is to cancel it; once it ended the reader closes the dialog.
class UpdateCheckProgressDialog extends ConsumerWidget {
  const UpdateCheckProgressDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(novelUpdateCheckProvider);
    final l10n = AppLocalizations.of(context)!;
    final running =
        state.status == UpdateCheckStatus.checking ||
        state.status == UpdateCheckStatus.idle;

    return AlertDialog(
      scrollable: true,
      title: Text(l10n.updateCheck_title),
      content: _buildContent(l10n, state),
      actions: [
        if (running)
          TextButton(
            key: const Key('update_check_cancel_button'),
            onPressed: () =>
                ref.read(novelUpdateCheckProvider.notifier).cancel(),
            child: Text(l10n.common_cancelButton),
          )
        else
          TextButton(
            key: const Key('update_check_close_button'),
            onPressed: () {
              ref.read(novelUpdateCheckProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            child: Text(l10n.common_closeButton),
          ),
      ],
    );
  }

  Widget _buildContent(AppLocalizations l10n, UpdateCheckState state) {
    switch (state.status) {
      case UpdateCheckStatus.idle:
      case UpdateCheckStatus.checking:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: state.total > 0 ? state.done / state.total : null,
            ),
            const SizedBox(height: 16),
            if (state.total > 0) Text('${state.done} / ${state.total}'),
          ],
        );
      case UpdateCheckStatus.completed:
        final summary = state.summary;
        final withNew = summary?.withNewEpisodes ?? 0;
        final failed = summary?.failed ?? 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              withNew > 0
                  ? l10n.updateCheck_newWorks(withNew)
                  : l10n.updateCheck_noNewEpisodes,
            ),
            if (failed > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.updateCheck_failedWorks(failed),
                style: const TextStyle(color: Colors.orange),
              ),
            ],
          ],
        );
      case UpdateCheckStatus.cancelled:
        return Text(l10n.updateCheck_cancelledMessage);
      case UpdateCheckStatus.error:
        return Text(
          l10n.common_errorPrefix(
            state.errorMessage ?? l10n.common_unknownError,
          ),
          style: const TextStyle(color: Colors.red),
        );
    }
  }
}
