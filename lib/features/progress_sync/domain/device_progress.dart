import 'sync_progress_record.dart';

/// Everything one device has published: the contents of its
/// `device-<id>.json` on Drive.
class DeviceProgress {
  final String deviceId;
  final String deviceName;
  final List<SyncProgressRecord> records;

  const DeviceProgress({
    required this.deviceId,
    required this.deviceName,
    required this.records,
  });
}

/// A record received from another device, kept until the next pull.
class RemoteProgress {
  final String deviceId;
  final String deviceName;
  final SyncProgressRecord record;

  const RemoteProgress({
    required this.deviceId,
    required this.deviceName,
    required this.record,
  });
}
