import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress_codec.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_progress_record.dart';

void main() {
  final device = DeviceProgress(
    deviceId: '4f6c',
    deviceName: 'iPad (pad)',
    records: [
      SyncProgressRecord(
        novelId: 'narou_n1234ab',
        episode: 5,
        fileName: '005_第五話.txt',
        bodyOffset: 1234,
        bodyHash: 'ab12',
        readAt: DateTime.utc(2026, 10, 18, 12, 34, 56),
      ),
      SyncProgressRecord(
        novelId: 'kakuyomu_1',
        episode: 1,
        fileName: '1_a.txt',
        bodyOffset: 0,
        bodyHash: null,
        readAt: DateTime.utc(2026, 10, 1),
      ),
    ],
  );

  test('a device round-trips through its JSON', () {
    final decoded = decodeDeviceProgress(encodeDeviceProgress(device));

    expect(decoded.deviceId, '4f6c');
    expect(decoded.deviceName, 'iPad (pad)');
    expect(decoded.records, device.records);
  });

  test('writes the documented shape', () {
    final json =
        jsonDecode(encodeDeviceProgress(device)) as Map<String, dynamic>;

    expect(json['format'], 1);
    expect(json['device_id'], '4f6c');
    expect(json['device_name'], 'iPad (pad)');
    final novel = (json['novels'] as Map)['narou_n1234ab'] as Map;
    expect(novel, {
      'episode': 5,
      'file_name': '005_第五話.txt',
      'body_offset': 1234,
      'body_hash': 'ab12',
      'read_at': '2026-10-18T12:34:56.000Z',
    });
  });

  test('read_at is written in UTC whatever zone it was made in', () {
    final local = DeviceProgress(
      deviceId: 'd',
      deviceName: 'd',
      records: [
        SyncProgressRecord(
          novelId: 'narou_a',
          episode: 1,
          fileName: '1.txt',
          bodyOffset: 0,
          bodyHash: null,
          readAt: DateTime.utc(2026, 10, 18).toLocal(),
        ),
      ],
    );
    final json =
        jsonDecode(encodeDeviceProgress(local)) as Map<String, dynamic>;
    expect(
      ((json['novels'] as Map)['narou_a'] as Map)['read_at'],
      '2026-10-18T00:00:00.000Z',
    );
  });

  test('rejects a format this build does not know', () {
    final json = jsonDecode(encodeDeviceProgress(device)) as Map;
    json['format'] = 2;

    expect(
      () => decodeDeviceProgress(jsonEncode(json)),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects broken JSON', () {
    expect(
      () => decodeDeviceProgress('{"format": 1, "device_id"'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a record missing a field', () {
    final json = jsonDecode(encodeDeviceProgress(device)) as Map;
    ((json['novels'] as Map)['narou_n1234ab'] as Map).remove('episode');

    expect(
      () => decodeDeviceProgress(jsonEncode(json)),
      throwsA(isA<FormatException>()),
    );
  });
}
