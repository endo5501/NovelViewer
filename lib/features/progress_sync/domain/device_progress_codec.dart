import 'dart:convert';

import 'device_progress.dart';
import 'sync_progress_record.dart';

/// The version of the `device-<id>.json` layout this build reads and writes.
/// A file of any other version is refused rather than half-read.
const int deviceProgressFormat = 1;

String encodeDeviceProgress(DeviceProgress device) {
  return jsonEncode({
    'format': deviceProgressFormat,
    'device_id': device.deviceId,
    'device_name': device.deviceName,
    'novels': {
      for (final record in device.records)
        record.novelId: {
          'episode': record.episode,
          'file_name': record.fileName,
          'body_offset': record.bodyOffset,
          'body_hash': record.bodyHash,
          'read_at': record.readAt.toUtc().toIso8601String(),
        },
    },
  });
}

/// Parses a `device-<id>.json`. Throws [FormatException] for broken JSON, an
/// unknown [deviceProgressFormat], or a missing or mistyped field.
DeviceProgress decodeDeviceProgress(String source) {
  final Object? json = jsonDecode(source);
  try {
    final map = json as Map<String, dynamic>;
    final format = map['format'];
    if (format != deviceProgressFormat) {
      throw FormatException('Unsupported device progress format: $format');
    }
    final novels = map['novels'] as Map<String, dynamic>;
    return DeviceProgress(
      deviceId: map['device_id'] as String,
      deviceName: map['device_name'] as String,
      records: [
        for (final MapEntry(:key, :value) in novels.entries)
          _decodeRecord(key, value as Map<String, dynamic>),
      ],
    );
  } on TypeError catch (e) {
    throw FormatException('Malformed device progress: $e');
  }
}

SyncProgressRecord _decodeRecord(String novelId, Map<String, dynamic> map) {
  return SyncProgressRecord(
    novelId: novelId,
    episode: map['episode'] as int,
    fileName: map['file_name'] as String,
    bodyOffset: map['body_offset'] as int,
    bodyHash: map['body_hash'] as String?,
    readAt: DateTime.parse(map['read_at'] as String),
  );
}
