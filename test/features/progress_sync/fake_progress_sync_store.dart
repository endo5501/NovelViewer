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

  /// Makes only writes throw it.
  Object? failWritesWith;

  /// The device id the last fetch was asked to leave out.
  String? lastExceptDeviceId;

  /// Awaited before a fetch or a write returns, to hold a call in flight.
  Future<void> Function()? beforeFetchReturns;
  Future<void> Function()? beforeWriteReturns;

  @override
  Future<List<DeviceProgress>> fetchAll({String? exceptDeviceId}) async {
    fetches++;
    lastExceptDeviceId = exceptDeviceId;
    if (failWith case final error?) throw error;
    final result = [
      for (final MapEntry(:key, :value) in files.entries)
        if (key != exceptDeviceId) value,
    ];
    await beforeFetchReturns?.call();
    return result;
  }

  @override
  Future<void> writeOwn(DeviceProgress own) async {
    writes++;
    if (failWith case final error?) throw error;
    if (failWritesWith case final error?) throw error;
    await beforeWriteReturns?.call();
    files[own.deviceId] = own;
  }
}
