import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:novel_viewer/features/tts/domain/tts_episode.dart';
import 'package:novel_viewer/features/tts/domain/tts_episode_status.dart';
import 'package:novel_viewer/features/tts/domain/tts_segment.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late TtsAudioDatabase database;
  late TtsAudioRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('tts_audio_repo_test_');
    database = TtsAudioDatabase(tempDir.path);
    repository = TtsAudioRepository(database);
  });

  tearDown(() async {
    await database.close();
    tempDir.deleteSync(recursive: true);
  });

  group('TtsAudioRepository', () {
    group('createEpisode', () {
      test('inserts an episode record and returns its id', () async {
        final id = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        expect(id, greaterThan(0));
      });

      test('creates episode with correct field values', () async {
        await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
          refWavPath: '/path/to/ref.wav',
        );

        final episode =
            await repository.findEpisodeByFileName('0001_プロローグ.txt');
        expect(episode, isNotNull);
        expect(episode, isA<TtsEpisode>());
        expect(episode!.fileName, '0001_プロローグ.txt');
        expect(episode.sampleRate, 24000);
        expect(episode.status, TtsEpisodeStatus.generating);
        expect(episode.refWavPath, '/path/to/ref.wav');
      });

      test('creates episode with text_hash', () async {
        await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
          textHash: 'abc123hash',
        );

        final episode =
            await repository.findEpisodeByFileName('0001_プロローグ.txt');
        expect(episode, isNotNull);
        expect(episode!.textHash, 'abc123hash');
      });

      test('creates episode with null text_hash when not provided', () async {
        await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        final episode =
            await repository.findEpisodeByFileName('0001_プロローグ.txt');
        expect(episode, isNotNull);
        expect(episode!.textHash, isNull);
      });
    });

    group('updateEpisodeStatus', () {
      test('updates status to partial', () async {
        final id = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        await repository.updateEpisodeStatus(id, TtsEpisodeStatus.partial);

        final episode =
            await repository.findEpisodeByFileName('0001_プロローグ.txt');
        expect(episode!.status, TtsEpisodeStatus.partial);
      });

      test('updates status to completed', () async {
        final id = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        await repository.updateEpisodeStatus(id, TtsEpisodeStatus.completed);

        final episode =
            await repository.findEpisodeByFileName('0001_プロローグ.txt');
        expect(episode!.status, TtsEpisodeStatus.completed);
      });
    });

    group('findEpisodeByFileName', () {
      test('returns null for non-existent file name', () async {
        final result =
            await repository.findEpisodeByFileName('nonexistent.txt');
        expect(result, isNull);
      });

      test('returns TtsEpisode for existing file name', () async {
        await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.completed,
        );

        final result =
            await repository.findEpisodeByFileName('0001_プロローグ.txt');
        expect(result, isA<TtsEpisode>());
        expect(result!.fileName, '0001_プロローグ.txt');
      });
    });

    group('insertSegment', () {
      test('inserts a segment with WAV BLOB data', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        final wavData = Uint8List.fromList([0x52, 0x49, 0x46, 0x46]);

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト文。',
          textOffset: 0,
          textLength: 5,
          audioData: wavData,
          sampleCount: 100,
        );

        final segments = await repository.getSegments(episodeId);
        expect(segments, hasLength(1));
        expect(segments.first, isA<TtsSegment>());
        expect(segments.first.text, 'テスト文。');
        expect(segments.first.segmentIndex, 0);
        expect(segments.first.audioData, isNotNull);
        expect(segments.first.audioData!.toList(), wavData.toList());
        expect(segments.first.sampleCount, 100);
      });
    });

    group('getSegments', () {
      test('returns segments ordered by segment_index', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.completed,
        );

        for (var i = 2; i >= 0; i--) {
          await repository.insertSegment(
            episodeId: episodeId,
            segmentIndex: i,
            text: 'テスト文$i。',
            textOffset: i * 10,
            textLength: 6,
            audioData: Uint8List(4),
            sampleCount: 100,
          );
        }

        final segments = await repository.getSegments(episodeId);
        expect(segments, hasLength(3));
        expect(segments[0].segmentIndex, 0);
        expect(segments[1].segmentIndex, 1);
        expect(segments[2].segmentIndex, 2);
      });

      test('returns empty list for episode with no segments', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        final segments = await repository.getSegments(episodeId);
        expect(segments, isEmpty);
      });
    });

    group('findSegmentByOffset', () {
      late int episodeId;

      setUp(() async {
        episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.completed,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: '今日は天気です。',
          textOffset: 0,
          textLength: 8,
          audioData: Uint8List(4),
          sampleCount: 100,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 1,
          text: '明日も晴れるでしょう。',
          textOffset: 8,
          textLength: 11,
          audioData: Uint8List(4),
          sampleCount: 200,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 2,
          text: '素敵な一日になりそう。',
          textOffset: 19,
          textLength: 12,
          audioData: Uint8List(4),
          sampleCount: 300,
        );
      });

      test('finds segment containing offset at segment boundary', () async {
        final segment =
            await repository.findSegmentByOffset(episodeId, 8);
        expect(segment, isNotNull);
        expect(segment!.segmentIndex, 1);
      });

      test('finds segment containing offset in the middle', () async {
        final segment =
            await repository.findSegmentByOffset(episodeId, 19);
        expect(segment, isNotNull);
        expect(segment!.segmentIndex, 2);
      });

      test('finds first segment for offset 0', () async {
        final segment =
            await repository.findSegmentByOffset(episodeId, 0);
        expect(segment, isNotNull);
        expect(segment!.segmentIndex, 0);
      });

      test('finds last segment for offset beyond all segments', () async {
        final segment =
            await repository.findSegmentByOffset(episodeId, 100);
        expect(segment, isNotNull);
        expect(segment!.segmentIndex, 2);
      });
    });

    group('getSegmentCount', () {
      test('returns 0 for episode with no segments', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        final count = await repository.getSegmentCount(episodeId);
        expect(count, 0);
      });

      test('returns correct count after inserting segments', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        for (var i = 0; i < 3; i++) {
          await repository.insertSegment(
            episodeId: episodeId,
            segmentIndex: i,
            text: 'テスト$i。',
            textOffset: i * 5,
            textLength: 4,
            audioData: Uint8List(4),
            sampleCount: 100,
          );
        }

        final count = await repository.getSegmentCount(episodeId);
        expect(count, 3);
      });
    });

    group('deleteEpisode', () {
      test('deletes episode and cascades to segments', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.completed,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト文。',
          textOffset: 0,
          textLength: 5,
          audioData: Uint8List(4),
          sampleCount: 100,
        );

        await repository.deleteEpisode(episodeId);

        final episode =
            await repository.findEpisodeByFileName('0001_プロローグ.txt');
        expect(episode, isNull);

        final segments = await repository.getSegments(episodeId);
        expect(segments, isEmpty);
      });
    });

    group('deleteEpisode defers vacuum until exit', () {
      test('does NOT reclaim disk space synchronously', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.completed,
        );

        final largeAudio = Uint8List(100000);
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト文。',
          textOffset: 0,
          textLength: 5,
          audioData: largeAudio,
          sampleCount: 50000,
        );

        final dbFile = File('${tempDir.path}/tts_audio.db');
        final sizeBeforeDelete = dbFile.lengthSync();

        await repository.deleteEpisode(episodeId);

        final sizeAfterDelete = dbFile.lengthSync();
        // Free pages remain because vacuum is deferred to app exit.
        expect(sizeAfterDelete, sizeBeforeDelete);
      });

      test('explicit reclaimSpace() still reclaims free pages', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.completed,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト文。',
          textOffset: 0,
          textLength: 5,
          audioData: Uint8List(100000),
          sampleCount: 50000,
        );

        final dbFile = File('${tempDir.path}/tts_audio.db');
        final sizeBeforeDelete = dbFile.lengthSync();

        await repository.deleteEpisode(episodeId);
        await database.reclaimSpace();

        final sizeAfterReclaim = dbFile.lengthSync();
        expect(sizeAfterReclaim, lessThan(sizeBeforeDelete));
      });

      test('invokes onEpisodeDeleted callback so the lifecycle can mark dirty',
          () async {
        var callbackCount = 0;
        final repoWithCallback = TtsAudioRepository(
          database,
          onEpisodeDeleted: () => callbackCount++,
        );
        final episodeId = await repoWithCallback.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.completed,
        );

        await repoWithCallback.deleteEpisode(episodeId);

        expect(callbackCount, 1);
      });
    });

    group('insertSegment with nullable audio', () {
      test('inserts a segment without audio_data', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト文。',
          textOffset: 0,
          textLength: 5,
        );

        final segments = await repository.getSegments(episodeId);
        expect(segments, hasLength(1));
        expect(segments.first.text, 'テスト文。');
        expect(segments.first.audioData, isNull);
        expect(segments.first.sampleCount, isNull);
      });
    });

    group('updateSegmentText', () {
      test('updates text and clears audio_data', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.completed,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: '山奥の一軒家',
          textOffset: 0,
          textLength: 6,
          audioData: Uint8List.fromList([1, 2, 3]),
          sampleCount: 100,
        );

        await repository.updateSegmentText(episodeId, 0, '山奥のいっけんや');

        final segment = await repository.getSegmentByIndex(episodeId, 0);
        expect(segment.text, '山奥のいっけんや');
        expect(segment.audioData, isNull);
        expect(segment.sampleCount, isNull);
      });

      test('updates text of segment without audio', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'オリジナル',
          textOffset: 0,
          textLength: 5,
        );

        await repository.updateSegmentText(episodeId, 0, '編集済み');

        final segment = await repository.getSegmentByIndex(episodeId, 0);
        expect(segment.text, '編集済み');
        expect(segment.audioData, isNull);
      });
    });

    group('updateSegmentAudio', () {
      test('updates audio_data and sample_count', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト文。',
          textOffset: 0,
          textLength: 5,
        );

        final newAudio = Uint8List.fromList([10, 20, 30]);
        await repository.updateSegmentAudio(episodeId, 0, newAudio, 300);

        final segment = await repository.getSegmentByIndex(episodeId, 0);
        expect(segment.audioData, isNotNull);
        expect(segment.audioData!.toList(), newAudio.toList());
        expect(segment.sampleCount, 300);
      });
    });

    group('updateSegmentRefWavPath', () {
      test('updates ref_wav_path', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト文。',
          textOffset: 0,
          textLength: 5,
        );

        await repository.updateSegmentRefWavPath(
            episodeId, 0, '/path/to/voice.wav');

        final segment = await repository.getSegmentByIndex(episodeId, 0);
        expect(segment.refWavPath, '/path/to/voice.wav');
      });
    });

    group('updateSegmentMemo', () {
      test('updates memo', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト文。',
          textOffset: 0,
          textLength: 5,
        );

        await repository.updateSegmentMemo(episodeId, 0, '感情的に読む');

        final segment = await repository.getSegmentByIndex(episodeId, 0);
        expect(segment.memo, '感情的に読む');
      });
    });

    group('deleteSegment', () {
      test('deletes only the specified segment', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.completed,
        );

        for (var i = 0; i < 3; i++) {
          await repository.insertSegment(
            episodeId: episodeId,
            segmentIndex: i,
            text: 'テスト$i。',
            textOffset: i * 5,
            textLength: 4,
            audioData: Uint8List(4),
            sampleCount: 100,
          );
        }

        await repository.deleteSegment(episodeId, 1);

        final segments = await repository.getSegments(episodeId);
        expect(segments, hasLength(2));
        expect(segments[0].segmentIndex, 0);
        expect(segments[1].segmentIndex, 2);
      });
    });

    group('getAllEpisodeStatuses', () {
      test('returns map with mixed statuses', () async {
        await repository.createEpisode(
          fileName: '0001_chapter1.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.completed,
        );
        await repository.createEpisode(
          fileName: '0002_chapter2.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.partial,
        );
        await repository.createEpisode(
          fileName: '0003_chapter3.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        final statuses = await repository.getAllEpisodeStatuses();

        expect(statuses, hasLength(3));
        expect(statuses['0001_chapter1.txt'], TtsEpisodeStatus.completed);
        expect(statuses['0002_chapter2.txt'], TtsEpisodeStatus.partial);
        expect(statuses['0003_chapter3.txt'], TtsEpisodeStatus.generating);
      });

      test('returns empty map for empty database', () async {
        final statuses = await repository.getAllEpisodeStatuses();
        expect(statuses, isEmpty);
      });
    });

    group('getGeneratedSegmentCount', () {
      test('returns count of segments with audio_data', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.partial,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト0。',
          textOffset: 0,
          textLength: 5,
          audioData: Uint8List(4),
          sampleCount: 100,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 1,
          text: 'テスト1。',
          textOffset: 5,
          textLength: 5,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 2,
          text: 'テスト2。',
          textOffset: 10,
          textLength: 5,
          audioData: Uint8List(4),
          sampleCount: 100,
        );

        final count = await repository.getGeneratedSegmentCount(episodeId);
        expect(count, 2);
      });

      test('returns 0 when no segments have audio', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: TtsEpisodeStatus.generating,
        );

        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト。',
          textOffset: 0,
          textLength: 4,
        );

        final count = await repository.getGeneratedSegmentCount(episodeId);
        expect(count, 0);
      });
    });
  });
}
