/// What the sync triggers drive: the service, or a recording fake in tests.
abstract class ProgressSyncRunner {
  Future<void> push();
  Future<void> pull();
  Future<void> syncNow();
}
