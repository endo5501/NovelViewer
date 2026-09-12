import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'failure_report.dart';

/// Opens the dialog presenting [report] in full.
///
/// Reached from the failure snackbar's details action. Everything the reader
/// needs in order to describe what went wrong lives here, in a form they can
/// copy in one tap, because on iOS the log file this would otherwise be read
/// from sits outside anything the Files app can reach.
Future<void> showFailureDetailDialog(
  BuildContext context,
  FailureReport report,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => FailureDetailDialog(report: report),
  );
}

class FailureDetailDialog extends StatelessWidget {
  const FailureDetailDialog({super.key, required this.report});

  final FailureReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = renderFailureReport(report);

    return AlertDialog(
      title: Text(l10n.failure_detailTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          // Selectable so a reader can lift a single frame out of the stack
          // trace by hand; the copy button covers taking the whole thing.
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final confirmation = l10n.contextMenu_copiedToClipboard;
            await Clipboard.setData(ClipboardData(text: text));
            // The clipboard write crosses a platform channel, and the surface
            // that owned the messenger can be torn down while it is in flight.
            if (!messenger.mounted) return;
            messenger.showSnackBar(SnackBar(content: Text(confirmation)));
          },
          child: Text(l10n.failure_copyButton),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_closeButton),
        ),
      ],
    );
  }
}
