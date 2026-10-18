import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/progress_sync/data/progress_sync_repository.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_progress_record.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

SyncProgressRecord _record(
  String novelId, {
  int episode = 5,
  int offset = 10,
  String readAt = '2026-10-18T00:00:00.000Z',
}) {
  return SyncProgressRecord(
    novelId: novelId,
    episode: episode,
    fileName: '${episode.toString().padLeft(3, '0')}.txt',
    bodyOffset: offset,
    bodyHash: 'h',
    readAt: DateTime.parse(readAt),
  );
}

void main() {
  late NovelDatabase novelDatabase;
  late ProgressSyncRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    repository = ProgressSyncRepository(novelDatabase);
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  group('remote records', () {
    test('stores the records of every other device', () async {
      await repository.replaceRemote(
        selfDeviceId: 'self',
        devices: [
          DeviceProgress(
            deviceId: 'win',
            deviceName: 'Windows (desk)',
            records: [_record('narou_a', episode: 5)],
          ),
          DeviceProgress(
            deviceId: 'pad',
            deviceName: 'iPad (pad)',
            records: [_record('narou_a', episode: 7)],
          ),
        ],
      );

      final remote = await repository.findRemoteByNovel('narou_a');
      expect(remote.map((r) => r.deviceId).toSet(), {'win', 'pad'});
      final win = remote.singleWhere((r) => r.deviceId == 'win');
      expect(win.deviceName, 'Windows (desk)');
      expect(win.record.episode, 5);
      expect(win.record.fileName, '005.txt');
      expect(win.record.bodyOffset, 10);
      expect(win.record.bodyHash, 'h');
      expect(win.record.readAt, DateTime.parse('2026-10-18T00:00:00.000Z'));
    });

    test('replaces a device wholesale on the next pull', () async {
      await repository.replaceRemote(
        selfDeviceId: 'self',
        devices: [
          DeviceProgress(
            deviceId: 'win',
            deviceName: 'Windows',
            records: [_record('narou_a'), _record('narou_b')],
          ),
        ],
      );
      await repository.replaceRemote(
        selfDeviceId: 'self',
        devices: [
          DeviceProgress(
            deviceId: 'win',
            deviceName: 'Windows',
            records: [_record('narou_a', episode: 9)],
          ),
        ],
      );

      expect(
        (await repository.findRemoteByNovel('narou_a')).single.record.episode,
        9,
      );
      expect(await repository.findRemoteByNovel('narou_b'), isEmpty);
    });

    test('drops a device whose file is gone from Drive', () async {
      await repository.replaceRemote(
        selfDeviceId: 'self',
        devices: [
          DeviceProgress(
            deviceId: 'old',
            deviceName: 'Old iPad',
            records: [_record('narou_a')],
          ),
        ],
      );
      await repository.replaceRemote(selfDeviceId: 'self', devices: const []);

      expect(await repository.findRemoteByNovel('narou_a'), isEmpty);
    });

    test('never stores this device\'s own file as another device', () async {
      await repository.replaceRemote(
        selfDeviceId: 'self',
        devices: [
          DeviceProgress(
            deviceId: 'self',
            deviceName: 'Mac',
            records: [_record('narou_a')],
          ),
        ],
      );

      expect(await repository.findRemoteByNovel('narou_a'), isEmpty);
    });
  });

  group('own records', () {
    test('keeps the set this device last pushed', () async {
      await repository.replaceOwn([_record('narou_a'), _record('narou_b')]);
      await repository.replaceOwn([_record('narou_a', episode: 6)]);

      final own = await repository.findAllOwn();
      expect(own.keys, ['narou_a']);
      expect(own['narou_a']!.episode, 6);
    });

    test('records an adopted record under its own read_at', () async {
      await repository.upsertOwn(
        _record('narou_a', readAt: '2026-10-01T00:00:00.000Z'),
      );
      await repository.upsertOwn(
        _record('narou_a', episode: 8, readAt: '2026-10-02T00:00:00.000Z'),
      );

      final own = await repository.findAllOwn();
      expect(own['narou_a']!.episode, 8);
      expect(own['narou_a']!.readAt, DateTime.parse('2026-10-02T00:00:00Z'));
    });
  });

  group('handled records', () {
    test('is null for a novel never prompted', () async {
      expect(await repository.findHandled('narou_a'), isNull);
    });

    test('stores the newest handled read_at', () async {
      await repository.saveHandled(
        'narou_a',
        DateTime.parse('2026-10-18T01:02:03Z'),
      );
      expect(
        await repository.findHandled('narou_a'),
        DateTime.parse('2026-10-18T01:02:03Z'),
      );
    });
  });

  test(
    'clearAll empties every sync table but keeps reading progress',
    () async {
      final progress = ReadingProgressRepository(novelDatabase);
      await progress.upsert(novelId: 'narou_a', fileName: '005.txt');
      await repository.replaceRemote(
        selfDeviceId: 'self',
        devices: [
          DeviceProgress(
            deviceId: 'win',
            deviceName: 'Windows',
            records: [_record('narou_a')],
          ),
        ],
      );
      await repository.replaceOwn([_record('narou_a')]);
      await repository.saveHandled('narou_a', DateTime.utc(2026, 10, 18));

      await repository.clearAll();

      expect(await repository.findRemoteByNovel('narou_a'), isEmpty);
      expect(await repository.findAllOwn(), isEmpty);
      expect(await repository.findHandled('narou_a'), isNull);
      expect(await progress.findByNovelId('narou_a'), isNotNull);
    },
  );
}
