import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
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
          status: 'generating',
        );

        expect(id, greaterThan(0));
      });

      test('creates episode with correct field values', () async {
        await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: 'generating',
          refWavPath: '/path/to/ref.wav',
        );

        final episode =
            await repository.findEpisodeByFileName('0001_プロローグ.txt');
        expect(episode, isNotNull);
        expect(episode!['file_name'], '0001_プロローグ.txt');
        expect(episode['sample_rate'], 24000);
        expect(episode['status'], 'generating');
        expect(episode['ref_wav_path'], '/path/to/ref.wav');
      });
    });

    group('updateEpisodeStatus', () {
      test('updates status to completed', () async {
        final id = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: 'generating',
        );

        await repository.updateEpisodeStatus(id, 'completed');

        final episode =
            await repository.findEpisodeByFileName('0001_プロローグ.txt');
        expect(episode!['status'], 'completed');
      });
    });

    group('findEpisodeByFileName', () {
      test('returns null for non-existent file name', () async {
        final result =
            await repository.findEpisodeByFileName('nonexistent.txt');
        expect(result, isNull);
      });

      test('returns episode record for existing file name', () async {
        await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: 'completed',
        );

        final result =
            await repository.findEpisodeByFileName('0001_プロローグ.txt');
        expect(result, isNotNull);
        expect(result!['file_name'], '0001_プロローグ.txt');
      });
    });

    group('insertSegment', () {
      test('inserts a segment with WAV BLOB data', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: 'generating',
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
        expect(segments.first['text'], 'テスト文。');
        expect(segments.first['segment_index'], 0);
        expect(segments.first['audio_data'], wavData);
        expect(segments.first['sample_count'], 100);
      });
    });

    group('getSegments', () {
      test('returns segments ordered by segment_index', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: 'completed',
        );

        // Insert in reverse order
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
        expect(segments[0]['segment_index'], 0);
        expect(segments[1]['segment_index'], 1);
        expect(segments[2]['segment_index'], 2);
      });

      test('returns empty list for episode with no segments', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: 'generating',
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
          status: 'completed',
        );

        // Segment 0: offset=0, length=8 ("今日は天気です。")
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: '今日は天気です。',
          textOffset: 0,
          textLength: 8,
          audioData: Uint8List(4),
          sampleCount: 100,
        );

        // Segment 1: offset=8, length=11 ("明日も晴れるでしょう。")
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 1,
          text: '明日も晴れるでしょう。',
          textOffset: 8,
          textLength: 11,
          audioData: Uint8List(4),
          sampleCount: 200,
        );

        // Segment 2: offset=19, length=12 ("素敵な一日になりそう。")
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
        expect(segment!['segment_index'], 1);
      });

      test('finds segment containing offset in the middle', () async {
        final segment =
            await repository.findSegmentByOffset(episodeId, 19);
        expect(segment, isNotNull);
        expect(segment!['segment_index'], 2);
      });

      test('finds first segment for offset 0', () async {
        final segment =
            await repository.findSegmentByOffset(episodeId, 0);
        expect(segment, isNotNull);
        expect(segment!['segment_index'], 0);
      });

      test('finds last segment for offset beyond all segments', () async {
        final segment =
            await repository.findSegmentByOffset(episodeId, 100);
        expect(segment, isNotNull);
        expect(segment!['segment_index'], 2);
      });
    });

    group('getSegmentCount', () {
      test('returns 0 for episode with no segments', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: 'generating',
        );

        final count = await repository.getSegmentCount(episodeId);
        expect(count, 0);
      });

      test('returns correct count after inserting segments', () async {
        final episodeId = await repository.createEpisode(
          fileName: '0001_プロローグ.txt',
          sampleRate: 24000,
          status: 'generating',
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
          status: 'completed',
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
  });
}
