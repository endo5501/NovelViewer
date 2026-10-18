import 'package:novel_viewer/features/progress_sync/data/progress_sync_store.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';

/// An in-memory [ProgressSyncStore]: the Drive appDataFolder as a map of
/// device id to its published progress. Set [failWith] to make every call
/// throw it.
class FakeProgressSyncStore implements ProgressSyncStore {
  final Map<String, DeviceProgress> files = {};
  int fetches = 0;
  int writes = 0;
  Object? failWith;

  /// Awaited before a fetch or a write returns, to hold a call in flight.
  Future<void> Function()? beforeFetchReturns;
  Future<void> Function()? beforeWriteReturns;

  @override
  Future<List<DeviceProgress>> fetchAll() async {
    fetches++;
    if (failWith case final error?) throw error;
    final result = files.values.toList();
    await beforeFetchReturns?.call();
    return result;
  }

  @override
  Future<void> writeOwn(DeviceProgress own) async {
    writes++;
    if (failWith case final error?) throw error;
    await beforeWriteReturns?.call();
    files[own.deviceId] = own;
  }
}
