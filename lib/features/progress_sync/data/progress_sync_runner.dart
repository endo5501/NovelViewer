/// What the sync triggers drive: the service, or a recording fake in tests.
abstract class ProgressSyncRunner {
  Future<void> push();
  Future<void> pull();
  Future<void> syncNow();

  /// Completes once no sync is running.
  Future<void> get idle;
}
