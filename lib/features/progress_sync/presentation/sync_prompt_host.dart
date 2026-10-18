import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

import '../providers/progress_sync_entry_providers.dart';
import '../providers/progress_sync_prompt_actions.dart';

/// Asks "move to the other device's position?" whenever entering a novel
/// raises the question (reading-progress-sync). Closing the dialog counts as
/// staying.
class SyncPromptHost extends ConsumerWidget {
  final Widget child;

  const SyncPromptHost({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<SyncPromptRequest?>(syncPromptProvider, (_, request) {
      if (request == null) return;
      ref.read(syncPromptProvider.notifier).clear();
      if (ref.read(currentDirectoryProvider) != request.directory) return;
      _ask(context, ref, request);
    });
    return child;
  }

  Future<void> _ask(
    BuildContext context,
    WidgetRef ref,
    SyncPromptRequest request,
  ) async {
    final actions = ref.read(syncPromptActionsProvider);
    final move = await showDialog<bool>(
      context: context,
      builder: (context) => _SyncPromptDialog(request: request),
    );
    await actions.answer(request, move: move ?? false);
  }
}

class _SyncPromptDialog extends StatelessWidget {
  final SyncPromptRequest request;

  const _SyncPromptDialog({required this.request});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final record = request.remote.record;
    final readAt = DateFormat.yMd(
      locale,
    ).add_Hm().format(record.readAt.toLocal());
    return AlertDialog(
      title: Text(l10n.syncPrompt_title),
      content: Text(
        l10n.syncPrompt_message(
          request.remote.deviceName,
          record.episode,
          readAt,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.syncPrompt_stay),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.syncPrompt_move),
        ),
      ],
    );
  }
}
