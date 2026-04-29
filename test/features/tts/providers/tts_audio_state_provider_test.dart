import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:novel_viewer/features/tts/domain/tts_episode_status.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_state_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;

  setUp(() {
    tempDir =
        Directory.systemTemp.createTempSync('tts_audio_state_provider_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<TtsAudioState> readState(
      ProviderContainer container, String filePath) async {
    return container.read(ttsAudioStateProvider(filePath).future);
  }

  group('ttsAudioStateProvider', () {
    test('returns TtsAudioState.none when no episode row exists', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final filePath = p.join(tempDir.path, '0001_chapter1.txt');
      final state = await readState(container, filePath);
      expect(state, TtsAudioState.none);
    });

    test('returns TtsAudioState.ready when episode is completed', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final db = container.read(ttsAudioDatabaseProvider(tempDir.path));
      final repo = TtsAudioRepository(db);
      await repo.createEpisode(
        fileName: '0001_chapter1.txt',
        sampleRate: 24000,
        status: TtsEpisodeStatus.completed,
      );

      final filePath = p.join(tempDir.path, '0001_chapter1.txt');
      final state = await readState(container, filePath);
      expect(state, TtsAudioState.ready);
    });

    test('returns TtsAudioState.ready when episode is partial', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final db = container.read(ttsAudioDatabaseProvider(tempDir.path));
      final repo = TtsAudioRepository(db);
      await repo.createEpisode(
        fileName: '0001_chapter1.txt',
        sampleRate: 24000,
        status: TtsEpisodeStatus.partial,
      );

      final filePath = p.join(tempDir.path, '0001_chapter1.txt');
      final state = await readState(container, filePath);
      expect(state, TtsAudioState.ready);
    });

    test('returns TtsAudioState.generating when episode status is generating',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final db = container.read(ttsAudioDatabaseProvider(tempDir.path));
      final repo = TtsAudioRepository(db);
      await repo.createEpisode(
        fileName: '0001_chapter1.txt',
        sampleRate: 24000,
        status: TtsEpisodeStatus.generating,
      );

      final filePath = p.join(tempDir.path, '0001_chapter1.txt');
      final state = await readState(container, filePath);
      expect(state, TtsAudioState.generating);
    });

    test('invalidate causes re-query (state updates after DB change)',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final filePath = p.join(tempDir.path, '0001_chapter1.txt');

      // Initially no episode → none
      var state = await readState(container, filePath);
      expect(state, TtsAudioState.none);

      // Create completed episode in DB
      final db = container.read(ttsAudioDatabaseProvider(tempDir.path));
      final repo = TtsAudioRepository(db);
      await repo.createEpisode(
        fileName: '0001_chapter1.txt',
        sampleRate: 24000,
        status: TtsEpisodeStatus.completed,
      );

      // Without invalidate, cached value is still none.
      // After invalidate, re-query yields ready.
      container.invalidate(ttsAudioStateProvider(filePath));
      state = await readState(container, filePath);
      expect(state, TtsAudioState.ready);
    });
  });
}
