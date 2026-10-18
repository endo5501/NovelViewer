import '../domain/device_progress.dart';

/// Where devices meet to share progress: every device's file can be read, and
/// each device writes only its own (design D2).
abstract class ProgressSyncStore {
  /// Every device's published progress, this device's included. A file this
  /// build cannot read is skipped, not fatal.
  Future<List<DeviceProgress>> fetchAll();

  /// Replaces this device's own file with [own].
  Future<void> writeOwn(DeviceProgress own);
}
