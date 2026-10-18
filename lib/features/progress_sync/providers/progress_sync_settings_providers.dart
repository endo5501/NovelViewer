import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/oauth/progress_sync_auth.dart';
import '../data/progress_sync_service.dart';
import 'progress_sync_providers.dart';

export 'progress_sync_account_providers.dart' show syncAccountStateProvider;

/// The service's last run, for the settings screen.
final syncRunStatusProvider = Provider<SyncRunStatus>((ref) {
  final status = ref.watch(progressSyncServiceProvider).status;
  void onChange() => ref.invalidateSelf();
  status.addListener(onChange);
  ref.onDispose(() => status.removeListener(onChange));
  return status.value;
});

/// What the settings screen can ask of the account.
abstract class SyncAccountActions {
  /// Signs in and, once signed in, syncs straight away.
  Future<void> signIn();
  Future<void> signOut();
  Future<void> syncNow();
}

class _SyncAccountActions implements SyncAccountActions {
  final Ref _ref;

  _SyncAccountActions(this._ref);

  ProgressSyncAuth? get _auth => _ref.read(progressSyncAuthProvider);

  @override
  Future<void> signIn() async {
    final auth = _auth;
    if (auth == null) return;
    if (await auth.signIn()) await syncNow();
  }

  @override
  Future<void> signOut() async => _auth?.signOut(
    beforeClear: () => _ref.read(progressSyncRunnerProvider).idle,
  );

  @override
  Future<void> syncNow() => _ref.read(progressSyncRunnerProvider).syncNow();
}

final syncAccountActionsProvider = Provider<SyncAccountActions>(
  _SyncAccountActions.new,
);
