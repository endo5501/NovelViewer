import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_progress_record.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_rules.dart';
import 'package:novel_viewer/features/reading_progress/domain/reading_progress.dart';

final _t0 = DateTime.utc(2026, 10, 1);
final _t1 = DateTime.utc(2026, 10, 2);
final _t2 = DateTime.utc(2026, 10, 3);
final _t3 = DateTime.utc(2026, 10, 4);

ReadingProgress _local(
  String fileName, {
  int offset = 0,
  DateTime? updatedAt,
  String novelId = 'narou_a',
  String? hash = 'h',
}) {
  return ReadingProgress(
    novelId: novelId,
    fileName: fileName,
    updatedAt: updatedAt ?? _t1,
    bodyOffset: offset,
    bodyHash: hash,
  );
}

SyncProgressRecord _rec(
  int episode, {
  int offset = 0,
  DateTime? readAt,
  String? fileName,
  String novelId = 'narou_a',
}) {
  return SyncProgressRecord(
    novelId: novelId,
    episode: episode,
    fileName: fileName ?? '${episode.toString().padLeft(3, '0')}_t.txt',
    bodyOffset: offset,
    bodyHash: 'h',
    readAt: readAt ?? _t0,
  );
}

RemoteProgress _remote(SyncProgressRecord record, {String device = 'win'}) {
  return RemoteProgress(
    deviceId: device,
    deviceName: '$device-name',
    record: record,
  );
}

void main() {
  group('isSamePosition', () {
    test('same episode within the tolerance is the same position', () {
      expect(
        isSamePosition(
          _rec(3, offset: 1000),
          _rec(3, offset: 1000 + samePositionTolerance - 1),
        ),
        isTrue,
      );
    });

    test('a move of the tolerance or more is a different position', () {
      expect(
        isSamePosition(
          _rec(3, offset: 1000),
          _rec(3, offset: 1000 + samePositionTolerance),
        ),
        isFalse,
      );
    });

    test('a different episode is a different position', () {
      expect(isSamePosition(_rec(3), _rec(4)), isFalse);
    });
  });

  group('buildOwnRecord', () {
    test('uses the local updated_at when nothing was pushed before', () {
      final record = buildOwnRecord(
        local: _local('003_t.txt', offset: 50, updatedAt: _t1),
        episode: 3,
        lastPushed: null,
      );

      expect(record, _rec(3, offset: 50, readAt: _t1, fileName: '003_t.txt'));
    });

    test('keeps the last read_at while the position holds still', () {
      final record = buildOwnRecord(
        local: _local('003_t.txt', offset: 1000, updatedAt: _t2),
        episode: 3,
        lastPushed: _rec(3, offset: 1000, readAt: _t0),
      );

      expect(record.readAt, _t0);
      expect(record.bodyOffset, 1000);
    });

    test('keeps the read_at but sends the new offset for a small drift', () {
      final record = buildOwnRecord(
        local: _local('003_t.txt', offset: 990, updatedAt: _t2),
        episode: 3,
        lastPushed: _rec(3, offset: 1000, readAt: _t0),
      );

      expect(record.readAt, _t0);
      expect(record.bodyOffset, 990);
    });

    test('takes the local updated_at once the position moves', () {
      final record = buildOwnRecord(
        local: _local('004_t.txt', updatedAt: _t2),
        episode: 4,
        lastPushed: _rec(3, readAt: _t0),
      );

      expect(record.readAt, _t2);
      expect(record.episode, 4);
    });

    test('keeps the read_at of an adopted record', () {
      // The device adopted another device's record (written as lastPushed
      // with that record's read_at), and the restore landed a little earlier.
      final adopted = _rec(5, offset: 2000, readAt: _t0);
      final record = buildOwnRecord(
        local: _local('005_t.txt', offset: 1500, updatedAt: _t3),
        episode: 5,
        lastPushed: adopted,
      );

      expect(record.readAt, _t0);
    });
  });

  group('buildOwnRecords', () {
    test('leaves out generic-web collections and unregistered novels', () {
      final records = buildOwnRecords(
        local: [
          _local('003_t.txt', novelId: 'narou_a'),
          _local('0001_x.txt', novelId: 'web_list'),
          _local('001_t.txt', novelId: 'narou_gone'),
        ],
        syncableNovelIds: {'narou_a'},
        lastPushed: const {},
        episodeOf: (novelId, fileName) => int.parse(fileName.split('_')[0]),
      );

      expect(records.map((r) => r.novelId), ['narou_a']);
    });

    test('leaves out a novel whose episode cannot be resolved', () {
      final records = buildOwnRecords(
        local: [_local('a.txt')],
        syncableNovelIds: {'narou_a'},
        lastPushed: const {},
        episodeOf: (_, _) => null,
      );

      expect(records, isEmpty);
    });

    test('compares each novel with its own last pushed record', () {
      final records = buildOwnRecords(
        local: [
          _local('003_t.txt', novelId: 'narou_a', updatedAt: _t2),
          _local('007_t.txt', novelId: 'narou_b', updatedAt: _t2),
        ],
        syncableNovelIds: {'narou_a', 'narou_b'},
        lastPushed: {
          'narou_a': _rec(3, readAt: _t0),
          'narou_b': _rec(6, novelId: 'narou_b', readAt: _t0),
        },
        episodeOf: (_, fileName) => int.parse(fileName.split('_')[0]),
      );

      expect(
        {for (final r in records) r.novelId: r.readAt},
        {'narou_a': _t0, 'narou_b': _t2},
      );
    });
  });

  group('resolveEpisodeFile', () {
    test('finds the episode whatever the zero-padding', () {
      expect(
        resolveEpisodeFile(_rec(5, fileName: '05_第五話.txt'), [
          '004_第四話.txt',
          '005_第五話.txt',
          '006_第六話.txt',
        ]),
        '005_第五話.txt',
      );
    });

    test('finds a prefix-less file by its lexical rank', () {
      expect(
        resolveEpisodeFile(_rec(2, fileName: 'b.txt'), ['a.txt', 'b.txt']),
        'b.txt',
      );
    });

    test('falls back to the file name when the episode is ambiguous', () {
      expect(
        resolveEpisodeFile(_rec(5, fileName: '5_new.txt'), [
          '005_old.txt',
          '5_new.txt',
        ]),
        '5_new.txt',
      );
    });

    test('falls back to the file name when no file has the episode', () {
      expect(
        resolveEpisodeFile(_rec(9, fileName: 'extra.txt'), [
          '001_a.txt',
          'extra.txt',
        ]),
        'extra.txt',
      );
    });

    test('resolves nothing when neither matches', () {
      expect(
        resolveEpisodeFile(_rec(120, fileName: '120_t.txt'), [
          '099_t.txt',
          '100_t.txt',
        ]),
        isNull,
      );
    });
  });

  group('decideOnEntry', () {
    const files = ['003_t.txt', '005_t.txt', '007_t.txt'];

    test('does nothing without received records', () {
      expect(
        decideOnEntry(
          local: null,
          currentOwn: null,
          remote: const [],
          handled: null,
          folderFiles: files,
        ),
        isA<NoSyncAction>(),
      );
    });

    test('applies the newest record when this device has no progress', () {
      final newest = _remote(_rec(5, readAt: _t2), device: 'win');
      final decision = decideOnEntry(
        local: null,
        currentOwn: null,
        remote: [
          _remote(_rec(3, readAt: _t1), device: 'mac'),
          newest,
        ],
        handled: null,
        folderFiles: files,
      );

      expect(decision, isA<AutoApplySync>());
      decision as AutoApplySync;
      expect(decision.remote, same(newest));
      expect(decision.fileName, '005_t.txt');
    });

    test('applies even after an earlier prompt was declined', () {
      // A novel deleted and downloaded again keeps its handled marker.
      final decision = decideOnEntry(
        local: null,
        currentOwn: null,
        remote: [_remote(_rec(5, readAt: _t1))],
        handled: _t2,
        folderFiles: files,
      );

      expect(decision, isA<AutoApplySync>());
    });

    test('keeps the record for later when its episode is not here yet', () {
      final decision = decideOnEntry(
        local: null,
        currentOwn: null,
        remote: [_remote(_rec(120, readAt: _t1))],
        handled: null,
        folderFiles: files,
      );

      expect(decision, isA<NoSyncAction>());
    });

    test('prompts when another device read elsewhere more recently', () {
      final newer = _remote(_rec(5, readAt: _t2));
      final decision = decideOnEntry(
        local: _local('003_t.txt'),
        currentOwn: _rec(3, readAt: _t1),
        remote: [newer],
        handled: null,
        folderFiles: files,
      );

      expect(decision, isA<PromptSync>());
      decision as PromptSync;
      expect(decision.remote, same(newer));
      expect(decision.fileName, '005_t.txt');
    });

    test('does not prompt for an older record', () {
      // Windows read to 5 at t1; the iPad only opened 3 (pushed at t0).
      final decision = decideOnEntry(
        local: _local('005_t.txt'),
        currentOwn: _rec(5, readAt: _t1),
        remote: [_remote(_rec(3, readAt: _t0), device: 'pad')],
        handled: null,
        folderFiles: files,
      );

      expect(decision, isA<NoSyncAction>());
    });

    test('does not prompt again for a record already answered', () {
      final decision = decideOnEntry(
        local: _local('003_t.txt'),
        currentOwn: _rec(3, readAt: _t0),
        remote: [_remote(_rec(5, readAt: _t2))],
        handled: _t2,
        folderFiles: files,
      );

      expect(decision, isA<NoSyncAction>());
    });

    test('prompts again for a record newer than the answered one', () {
      final decision = decideOnEntry(
        local: _local('003_t.txt'),
        currentOwn: _rec(3, readAt: _t0),
        remote: [_remote(_rec(7, readAt: _t3))],
        handled: _t2,
        folderFiles: files,
      );

      expect(decision, isA<PromptSync>());
    });

    test('marks a newer record at the same position handled silently', () {
      final decision = decideOnEntry(
        local: _local('005_t.txt', offset: 100),
        currentOwn: _rec(5, offset: 100, readAt: _t0),
        remote: [_remote(_rec(5, offset: 150, readAt: _t2))],
        handled: null,
        folderFiles: files,
      );

      expect(decision, isA<MarkHandledSync>());
      expect((decision as MarkHandledSync).readAt, _t2);
    });

    test('does not prompt for an episode that is not here', () {
      final decision = decideOnEntry(
        local: _local('003_t.txt'),
        currentOwn: _rec(3, readAt: _t0),
        remote: [_remote(_rec(120, readAt: _t2))],
        handled: null,
        folderFiles: files,
      );

      expect(decision, isA<NoSyncAction>());
    });

    test('compares with updated_at when the local episode is unknown', () {
      final decision = decideOnEntry(
        local: _local('gone.txt', updatedAt: _t1),
        currentOwn: null,
        remote: [_remote(_rec(5, readAt: _t2))],
        handled: null,
        folderFiles: files,
      );

      expect(decision, isA<PromptSync>());
    });
  });
}
