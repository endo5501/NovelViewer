import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'failure_detail_dialog.dart';
import 'failure_report.dart';
import 'sensitive_redaction.dart';

/// Shows the shared failure notification for [report].
///
/// Every user-facing failure goes through here so the shape stays in one
/// place: a body that survives until the reader dismisses it, and one action
/// that opens the full diagnostics. The old four-second snackbar was gone
/// before a cause could be read, and on iOS there is no log file to fall back
/// on — `Library/Application Support` sits outside what `UIFileSharingEnabled`
/// exposes.
void showFailureSnackBar(BuildContext context, FailureReport report) {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);

  // The details action gets no context of its own, and the widget that
  // reported the failure may well be disposed while the snackbar is still up
  // — a dialog closing, a file switching. The root navigator outlives both.
  final navigator = Navigator.of(context, rootNavigator: true);

  // Without this a burst of failures stacks up, and dismissing one only
  // uncovers the last.
  messenger.removeCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(formatFailureSnackBarBody(report)),
      // SnackBar takes a single action, so dismissal is the built-in close
      // icon rather than a second button.
      showCloseIcon: true,
      duration: const Duration(days: 365),
      action: SnackBarAction(
        label: l10n.failure_detailsAction,
        onPressed: () {
          if (!navigator.mounted) return;
          showFailureDetailDialog(navigator.context, report);
        },
      ),
    ),
  );
}

/// Builds the snackbar body: the localized headline, followed by the raw cause
/// when there is one.
///
/// A headline on its own says nothing actionable — it cannot distinguish "this
/// reference audio is unreadable" from "the model is missing" — so the cause is
/// appended whenever one exists. The cause is generated at runtime and stays
/// untranslated.
String formatFailureSnackBarBody(FailureReport report) {
  final cause = report.cause?.trim();
  if (cause == null || cause.isEmpty) {
    return report.headline;
  }
  return '${report.headline}: ${redactSensitive(cause)}';
}
