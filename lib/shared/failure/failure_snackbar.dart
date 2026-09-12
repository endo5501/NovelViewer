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
/// [messenger] overrides where the bar is shown. A modal surface — the TTS
/// edit dialog, say — must hand in its own `ScaffoldMessenger`, or the bar
/// lands in the page `Scaffold` underneath the modal barrier, where neither
/// the details action nor the close icon can be reached.
void showFailureSnackBar(
  BuildContext context,
  FailureReport report, {
  ScaffoldMessengerState? messenger,
}) {
  final l10n = AppLocalizations.of(context)!;
  final target = messenger ?? ScaffoldMessenger.of(context);

  // The details action gets no context of its own, and the widget that
  // reported the failure may well be disposed while the snackbar is still up
  // — a dialog closing, a file switching. The root navigator outlives both.
  final navigator = Navigator.of(context, rootNavigator: true);

  // Without this a burst of failures stacks up, and dismissing one only
  // uncovers the last.
  target.removeCurrentSnackBar();
  target.showSnackBar(
    SnackBar(
      content: Text(formatFailureSnackBarBody(report)),
      // SnackBar takes a single action, so dismissal is the built-in close
      // icon rather than a second button.
      showCloseIcon: true,
      // SnackBar defaults `persist` to `action != null`, which ignores the
      // duration outright and keeps the bar up forever. ScaffoldMessenger
      // shows one bar at a time and queues the rest, so that would swallow
      // every later notification in the app until the reader dismissed this
      // one by hand.
      persist: false,
      duration: _failureDuration,
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

/// Long enough to read a cause and open the diagnostics without hurrying,
/// but bounded: `ScaffoldMessenger` shows one bar at a time and queues the
/// rest, so an unbounded failure would swallow every later notification in the
/// app until the reader happened to dismiss it.
const _failureDuration = Duration(minutes: 5);

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
