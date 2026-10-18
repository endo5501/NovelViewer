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

  @override
  Future<List<DeviceProgress>> fetchAll() async {
    fetches++;
    if (failWith case final error?) throw error;
    return files.values.toList();
  }

  @override
  Future<void> writeOwn(DeviceProgress own) async {
    writes++;
    if (failWith case final error?) throw error;
    files[own.deviceId] = own;
  }
}
