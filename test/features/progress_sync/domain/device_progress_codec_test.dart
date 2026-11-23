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

  group('url and title', () {
    final withUrl = DeviceProgress(
      deviceId: 'd',
      deviceName: 'Mac',
      records: [
        SyncProgressRecord(
          novelId: 'narou_n1234ab',
          episode: 5,
          fileName: '005_t.txt',
          bodyOffset: 10,
          bodyHash: 'h',
          readAt: DateTime.utc(2026, 11, 1),
          url: 'https://ncode.syosetu.com/n1234ab/',
          title: 'ある物語',
        ),
      ],
    );

    test('are written into the record and keep format 1', () {
      final json =
          jsonDecode(encodeDeviceProgress(withUrl)) as Map<String, dynamic>;

      expect(json['format'], 1);
      final novel = (json['novels'] as Map)['narou_n1234ab'] as Map;
      expect(novel['url'], 'https://ncode.syosetu.com/n1234ab/');
      expect(novel['title'], 'ある物語');
    });

    test('round-trip through the JSON', () {
      final decoded = decodeDeviceProgress(encodeDeviceProgress(withUrl));

      expect(decoded.records, withUrl.records);
    });

    test('a record written without them reads as null', () {
      // The shape a build before url/title writes.
      const source =
          '{"format":1,"device_id":"d","device_name":"Win","novels":'
          '{"narou_a":{"episode":2,"file_name":"002_t.txt","body_offset":5,'
          '"body_hash":null,"read_at":"2026-10-18T00:00:00.000Z"}}}';

      final record = decodeDeviceProgress(source).records.single;

      expect(record.episode, 2);
      expect(record.url, isNull);
      expect(record.title, isNull);
    });

    test('explicit nulls read as null', () {
      final json = jsonDecode(encodeDeviceProgress(withUrl)) as Map;
      final novel = (json['novels'] as Map)['narou_n1234ab'] as Map;
      novel['url'] = null;
      novel['title'] = null;

      final record = decodeDeviceProgress(jsonEncode(json)).records.single;

      expect(record.url, isNull);
      expect(record.title, isNull);
    });

    test('a url that is not a string is refused', () {
      final json = jsonDecode(encodeDeviceProgress(withUrl)) as Map;
      ((json['novels'] as Map)['narou_n1234ab'] as Map)['url'] = 12;

      expect(
        () => decodeDeviceProgress(jsonEncode(json)),
        throwsA(isA<FormatException>()),
      );
    });

    test('a title that is not a string is refused', () {
      final json = jsonDecode(encodeDeviceProgress(withUrl)) as Map;
      ((json['novels'] as Map)['narou_n1234ab'] as Map)['title'] = ['x'];

      expect(
        () => decodeDeviceProgress(jsonEncode(json)),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
