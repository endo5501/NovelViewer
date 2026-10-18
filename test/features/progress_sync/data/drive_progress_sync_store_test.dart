import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/progress_sync/data/drive_progress_sync_store.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress_codec.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_progress_record.dart';

class _Tokens implements AccessTokenSource {
  int refreshes = 0;
  String current = 'token-1';

  @override
  Future<String> accessToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      refreshes++;
      current = 'token-${refreshes + 1}';
    }
    return current;
  }
}

class _MemoryIds implements DriveFileIdStore {
  String? id;

  @override
  Future<String?> read() async => id;

  @override
  Future<void> write(String? value) async => id = value;
}

DeviceProgress _device(String id, {int episode = 5}) {
  return DeviceProgress(
    deviceId: id,
    deviceName: '$id-name',
    records: [
      SyncProgressRecord(
        novelId: 'narou_a',
        episode: episode,
        fileName: '005.txt',
        bodyOffset: 10,
        bodyHash: 'h',
        readAt: DateTime.utc(2026, 10, 18),
      ),
    ],
  );
}

http.Response _json(Object body, [int status = 200]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  late _Tokens tokens;
  late _MemoryIds ids;
  late List<http.Request> requests;

  setUp(() {
    tokens = _Tokens();
    ids = _MemoryIds();
    requests = [];
  });

  DriveProgressSyncStore storeWith(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return DriveProgressSyncStore(
      client: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
      tokens: tokens,
      fileIds: ids,
    );
  }

  group('fetchAll', () {
    test('lists the device files in appDataFolder and reads each', () async {
      final store = storeWith((request) async {
        if (request.url.path == '/drive/v3/files') {
          return _json({
            'files': [
              {'id': 'f-win', 'name': 'device-win.json'},
              {'id': 'f-pad', 'name': 'device-pad.json'},
            ],
          });
        }
        final id = request.url.pathSegments.last;
        return http.Response(
          encodeDeviceProgress(_device(id == 'f-win' ? 'win' : 'pad')),
          200,
        );
      });

      final devices = await store.fetchAll();

      expect(devices.map((d) => d.deviceId).toSet(), {'win', 'pad'});
      final list = requests.first;
      expect(list.url.queryParameters['spaces'], 'appDataFolder');
      expect(
        list.url.queryParameters['q'],
        contains("name contains 'device-'"),
      );
      expect(list.headers['authorization'], 'Bearer token-1');
      final reads = requests.skip(1);
      expect(
        reads.every((r) => r.url.queryParameters['alt'] == 'media'),
        isTrue,
      );
    });

    test('leaves out the file of the device asking', () async {
      final store = storeWith((request) async {
        if (request.url.path == '/drive/v3/files') {
          return _json({
            'files': [
              {'id': 'f-self', 'name': 'device-self.json'},
              {'id': 'f-win', 'name': 'device-win.json'},
            ],
          });
        }
        return http.Response(encodeDeviceProgress(_device('win')), 200);
      });

      final devices = await store.fetchAll(exceptDeviceId: 'self');

      expect(devices.map((d) => d.deviceId), ['win']);
      expect(
        requests.where((r) => r.url.pathSegments.last == 'f-self'),
        isEmpty,
      );
    });

    test('follows the next page of the listing', () async {
      final store = storeWith((request) async {
        if (request.url.path == '/drive/v3/files') {
          if (request.url.queryParameters['pageToken'] == null) {
            return _json({
              'files': [
                {'id': 'f-1', 'name': 'device-1.json'},
              ],
              'nextPageToken': 'p2',
            });
          }
          return _json({
            'files': [
              {'id': 'f-2', 'name': 'device-2.json'},
            ],
          });
        }
        return http.Response(
          encodeDeviceProgress(_device(request.url.pathSegments.last)),
          200,
        );
      });

      expect((await store.fetchAll()).length, 2);
    });

    test('skips a file of an unknown format and reads the rest', () async {
      final records = <LogRecord>[];
      final sub = Logger('progress_sync').onRecord.listen(records.add);
      addTearDown(sub.cancel);
      final store = storeWith((request) async {
        if (request.url.path == '/drive/v3/files') {
          return _json({
            'files': [
              {'id': 'f-new', 'name': 'device-new.json'},
              {'id': 'f-ok', 'name': 'device-ok.json'},
            ],
          });
        }
        if (request.url.pathSegments.last == 'f-new') {
          return _json({'format': 99});
        }
        return http.Response(encodeDeviceProgress(_device('ok')), 200);
      });

      final devices = await store.fetchAll();

      expect(devices.map((d) => d.deviceId), ['ok']);
      expect(records.any((r) => r.level == Level.WARNING), isTrue);
    });

    test('refreshes the token once on 401 and retries', () async {
      final store = storeWith((request) async {
        if (request.headers['authorization'] == 'Bearer token-1') {
          return http.Response('', 401);
        }
        return _json({'files': []});
      });

      expect(await store.fetchAll(), isEmpty);
      expect(tokens.refreshes, 1);
      expect(requests, hasLength(2));
    });

    test('gives up after a second 401', () async {
      final store = storeWith((_) async => http.Response('', 401));

      await expectLater(
        store.fetchAll(),
        throwsA(isA<ProgressSyncHttpException>()),
      );
      expect(tokens.refreshes, 1);
    });

    test('reports a server error', () async {
      final store = storeWith((_) async => http.Response('boom', 500));

      await expectLater(
        store.fetchAll(),
        throwsA(
          isA<ProgressSyncHttpException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });
  });

  test('two devices writing in turn keep each other\'s records', () async {
    // A small in-memory appDataFolder shared by both devices' stores.
    final drive = <String, ({String name, String body})>{};
    var nextId = 0;
    Future<http.Response> serve(http.Request request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path == '/drive/v3/files') {
        final q = request.url.queryParameters['q']!;
        final exact = RegExp(r"name = '([^']+)'").firstMatch(q)?.group(1);
        return _json({
          'files': [
            for (final MapEntry(:key, :value) in drive.entries)
              if (exact == null || value.name == exact)
                {'id': key, 'name': value.name},
          ],
        });
      }
      if (request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(drive[request.url.pathSegments.last]!.body),
          200,
        );
      }
      if (request.method == 'POST') {
        final name = RegExp(r'"name":"([^"]+)"').firstMatch(request.body)!;
        final body = request.body.split('\r\n\r\n')[2].split('\r\n--')[0];
        final id = 'f${nextId++}';
        drive[id] = (name: name.group(1)!, body: body);
        return _json({'id': id});
      }
      final id = request.url.pathSegments.last;
      drive[id] = (name: drive[id]!.name, body: request.body);
      return _json({'id': id});
    }

    DriveProgressSyncStore storeFor() => DriveProgressSyncStore(
      client: MockClient(serve),
      tokens: tokens,
      fileIds: _MemoryIds(),
    );
    final deviceA = storeFor();
    final deviceB = storeFor();

    await deviceA.writeOwn(_device('a', episode: 1));
    await deviceB.writeOwn(_device('b', episode: 2));
    await deviceA.writeOwn(_device('a', episode: 3));

    final devices = await deviceA.fetchAll();
    expect(
      {for (final d in devices) d.deviceId: d.records.single.episode},
      {'a': 3, 'b': 2},
    );
    expect(drive, hasLength(2));
  });

  group('writeOwn', () {
    test('creates the file in appDataFolder the first time', () async {
      final store = storeWith((request) async {
        if (request.method == 'GET') return _json({'files': []});
        return _json({'id': 'new-id'});
      });

      await store.writeOwn(_device('self'));

      final search = requests[0];
      expect(
        search.url.queryParameters['q'],
        contains("name = 'device-self.json'"),
      );
      final create = requests[1];
      expect(create.method, 'POST');
      expect(create.url.path, '/upload/drive/v3/files');
      expect(create.url.queryParameters['uploadType'], 'multipart');
      expect(create.body, contains('"parents":["appDataFolder"]'));
      expect(create.body, contains('"name":"device-self.json"'));
      expect(create.body, contains('"device_id":"self"'));
      expect(ids.id, 'new-id');
    });

    test('updates the remembered file on later writes', () async {
      ids.id = 'known';
      final store = storeWith((_) async => _json({'id': 'known'}));

      await store.writeOwn(_device('self', episode: 6));

      expect(requests, hasLength(1));
      final update = requests.single;
      expect(update.method, 'PATCH');
      expect(update.url.path, '/upload/drive/v3/files/known');
      expect(update.url.queryParameters['uploadType'], 'media');
      expect(decodeDeviceProgress(update.body).records.single.episode, 6);
    });

    test('finds the file by name when the remembered one is gone', () async {
      ids.id = 'stale';
      final store = storeWith((request) async {
        if (request.method == 'PATCH' && request.url.path.endsWith('/stale')) {
          return http.Response('', 404);
        }
        if (request.method == 'GET') {
          return _json({
            'files': [
              {'id': 'found', 'name': 'device-self.json'},
            ],
          });
        }
        return _json({'id': 'found'});
      });

      await store.writeOwn(_device('self'));

      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'PATCH /upload/drive/v3/files/stale',
        'GET /drive/v3/files',
        'PATCH /upload/drive/v3/files/found',
      ]);
      expect(ids.id, 'found');
    });
  });
}
