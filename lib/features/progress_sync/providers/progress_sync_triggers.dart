import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../data/progress_sync_runner.dart';

export '../data/progress_sync_runner.dart';

/// Pulls when the app comes back to the front, and pushes when it goes to the
/// back or is asked to exit (design D7). `inactive` is left alone: a desktop
/// window enters it every time it loses focus.
class ProgressSyncLifecycle extends WidgetsBindingObserver {
  /// Looked up at each event rather than held, so a runner rebuilt after the
  /// observer registered is the one driven.
  final ProgressSyncRunner Function() _runner;
  final Duration _exitTimeout;

  ProgressSyncLifecycle(
    this._runner, {
    Duration exitTimeout = const Duration(seconds: 3),
  }) : _exitTimeout = exitTimeout;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_runner().pull());
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        unawaited(_runner().push());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Gives the push a few seconds and then lets the app exit regardless: an
  /// unreachable network must not keep the window open. A push cut short is
  /// rebuilt from the latest state on the next run.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    try {
      await _runner().push().timeout(_exitTimeout);
    } on TimeoutException {
      Logger('progress_sync').info('Exit did not wait for the progress push');
    }
    return AppExitResponse.exit;
  }
}
