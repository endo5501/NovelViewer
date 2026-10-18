import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/progress_sync/data/progress_sync_repository.dart';
import 'package:novel_viewer/features/progress_sync/data/progress_sync_service.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_progress_record.dart';
import 'package:novel_viewer/features/reading_progress/domain/reading_progress.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';
import '../fake_progress_sync_store.dart';

final _t1 = DateTime.utc(2026, 10, 1);

ReadingProgress _local(String novelId, String fileName, {int offset = 0}) {
  return ReadingProgress(
    novelId: novelId,
    fileName: fileName,
    updatedAt: _t1,
    bodyOffset: offset,
    bodyHash: 'h',
  );
}

void main() {
  late NovelDatabase novelDatabase;
  late ProgressSyncRepository repository;
  late FakeProgressSyncStore store;
  late List<ReadingProgress> local;
  late List<String> calls;
  late bool available;
  late bool signedIn;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    repository = ProgressSyncRepository(novelDatabase);
    store = FakeProgressSyncStore();
    local = [_local('narou_a', '003_t.txt')];
    calls = [];
    available = true;
    signedIn = true;
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  ProgressSyncService service({Future<void> Function()? flush}) {
    return ProgressSyncService(
      isAvailable: () => available,
      isSignedIn: () => signedIn,
      store: store,
      repository: repository,
      deviceId: () async => 'self',
      deviceName: 'Mac (desk)',
      flushPendingPositions: () async {
        calls.add('flush');
        await flush?.call();
      },
      loadLocalProgress: () async {
        calls.add('load');
        return local;
      },
      syncableNovelIds: () async => {'narou_a', 'narou_b'},
      episodeOf: (_, fileName) async => int.tryParse(fileName.split('_')[0]),
      now: () => DateTime.utc(2026, 10, 18, 9),
    );
  }

  group('refusal', () {
    test('does nothing in a build without sync', () async {
      available = false;
      final sync = service();

      await sync.push();
      await sync.pull();
      await sync.syncNow();

      expect(store.fetches + store.writes, 0);
      expect(calls, isEmpty);
    });

    test('does nothing while signed out', () async {
      signedIn = false;
      final sync = service();

      await sync.push();
      await sync.pull();

      expect(store.fetches + store.writes, 0);
    });
  });

  group('push', () {
    test('flushes pending positions before reading the progress', () async {
      await service().push();

      expect(calls.take(2), ['flush', 'load']);
    });

    test('publishes this device\'s records and remembers them', () async {
      await service().push();

      final own = store.files['self']!;
      expect(own.deviceName, 'Mac (desk)');
      expect(own.records.single.novelId, 'narou_a');
      expect(own.records.single.episode, 3);
      expect((await repository.findAllOwn()).keys, ['narou_a']);
    });

    test('leaves out novels that are not syncable', () async {
      local = [
        _local('narou_a', '003_t.txt'),
        _local('web_list', '0001_x.txt'),
      ];

      await service().push();

      expect(store.files['self']!.records.map((r) => r.novelId), ['narou_a']);
    });

    test('does not upload what was already uploaded', () async {
      final sync = service();
      await sync.push();
      await sync.push();

      expect(store.writes, 1);
    });

    test('uploads again once the position moves', () async {
      final sync = service();
      await sync.push();
      local = [_local('narou_a', '004_t.txt')];
      await sync.push();

      expect(store.writes, 2);
      expect(store.files['self']!.records.single.episode, 4);
    });

    test('a failed push is rebuilt and sent on the next one', () async {
      final sync = service();
      store.failWith = Exception('offline');
      await sync.push();
      store.failWith = null;
      await sync.push();

      expect(store.files['self'], isNotNull);
    });
  });

  group('pull', () {
    test('keeps the other devices\' records', () async {
      store.files['win'] = DeviceProgress(
        deviceId: 'win',
        deviceName: 'Windows',
        records: [
          SyncProgressRecord(
            novelId: 'narou_a',
            episode: 5,
            fileName: '005_t.txt',
            bodyOffset: 1,
            bodyHash: 'h',
            readAt: _t1,
          ),
        ],
      );

      await service().pull();

      final remote = await repository.findRemoteByNovel('narou_a');
      expect(remote.single.deviceId, 'win');
    });

    test('announces each finished pull', () async {
      final sync = service();
      final pulled = <void>[];
      final sub = sync.pulled.listen(pulled.add);
      addTearDown(sub.cancel);

      await sync.pull();
      await Future<void>.delayed(Duration.zero);

      expect(pulled, hasLength(1));
    });
  });

  test('sync now pushes and then pulls', () async {
    final sync = service();
    await sync.syncNow();

    expect(store.writes, 1);
    expect(store.fetches, 1);
    expect(store.files['self'], isNotNull);
  });

  group('serialization', () {
    test('requests made while running collapse into one more run', () async {
      final gate = Completer<void>();
      var flushes = 0;
      final sync = service(
        flush: () async {
          flushes++;
          if (flushes == 1) await gate.future;
        },
      );

      final first = sync.push();
      await Future<void>.delayed(Duration.zero);
      final queued = [sync.push(), sync.push(), sync.push()];
      gate.complete();
      await first;
      await Future.wait(queued);

      expect(flushes, 2);
    });

    test('a pull waits for a running push', () async {
      final gate = Completer<void>();
      final sync = service(flush: () => gate.future);

      final push = sync.push();
      await Future<void>.delayed(Duration.zero);
      final pull = sync.pull();
      await Future<void>.delayed(Duration.zero);
      expect(store.fetches, 0);

      gate.complete();
      await Future.wait([push, pull]);
      expect(store.fetches, 1);
    });
  });

  group('status', () {
    test('records when a sync last succeeded', () async {
      final sync = service();
      await sync.pull();

      expect(sync.status.value.lastSuccessAt, DateTime.utc(2026, 10, 18, 9));
      expect(sync.status.value.lastError, isNull);
      expect(sync.status.value.running, isFalse);
    });

    test('a failure is logged and shown, and reading goes on', () async {
      final records = <LogRecord>[];
      final sub = Logger('progress_sync').onRecord.listen(records.add);
      addTearDown(sub.cancel);
      store.failWith = Exception('offline');
      final sync = service();

      await sync.pull();

      expect(sync.status.value.lastError, contains('offline'));
      expect(sync.status.value.lastSuccessAt, isNull);
      expect(records.where((r) => r.level == Level.WARNING), isNotEmpty);
    });

    test('a later success clears the shown failure', () async {
      final sync = service();
      store.failWith = Exception('offline');
      await sync.pull();
      store.failWith = null;
      await sync.pull();

      expect(sync.status.value.lastError, isNull);
    });

    test('is running while a sync is in flight', () async {
      final gate = Completer<void>();
      final sync = service(flush: () => gate.future);

      final push = sync.push();
      await Future<void>.delayed(Duration.zero);
      expect(sync.status.value.running, isTrue);
      gate.complete();
      await push;
      expect(sync.status.value.running, isFalse);
    });
  });
}
