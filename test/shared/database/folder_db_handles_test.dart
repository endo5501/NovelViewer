import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_database.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/database/folder_db_handles.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';

/// Records a close call into [log] after an async gap, so a caller that fails
/// to await close() before invalidating would be observable as out-of-order.
class _FakeEpisodeCacheDatabase extends EpisodeCacheDatabase {
  _FakeEpisodeCacheDatabase(this.log) : super('unused');
  final List<String> log;
  @override
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    log.add('close:episode');
  }
}

class _FakeTtsAudioDatabase extends TtsAudioDatabase {
  _FakeTtsAudioDatabase(this.log) : super('unused');
  final List<String> log;
  @override
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    log.add('close:audio');
  }
}

class _FakeTtsDictionaryDatabase extends TtsDictionaryDatabase {
  _FakeTtsDictionaryDatabase(this.log) : super('unused');
  final List<String> log;
  @override
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    log.add('close:dict');
  }
}

void main() {
  late List<String> log;
  late ProviderContainer container;
  late List<ProviderOrFamily> invalidated;

  setUp(() {
    log = <String>[];
    invalidated = <ProviderOrFamily>[];
    container = ProviderContainer(overrides: [
      episodeCacheDatabaseProvider
          .overrideWith((ref, _) => _FakeEpisodeCacheDatabase(log)),
      ttsAudioDatabaseProvider
          .overrideWith((ref, _) => _FakeTtsAudioDatabase(log)),
      ttsDictionaryDatabaseProvider
          .overrideWith((ref, _) => _FakeTtsDictionaryDatabase(log)),
    ]);
  });

  tearDown(() => container.dispose());

  void recordingInvalidate(ProviderOrFamily provider) {
    log.add('invalidate');
    invalidated.add(provider);
  }

  group('releaseFolderDbHandles', () {
    test('awaits all three close() calls before any invalidate', () async {
      await releaseFolderDbHandles(
        '/lib/narou_n1',
        read: container.read,
        invalidate: recordingInvalidate,
      );

      // Every close must be recorded (await completed) before the first
      // invalidate. ref.invalidate alone is fire-and-forget; this helper must
      // not rely on it for the close.
      final firstInvalidate = log.indexOf('invalidate');
      expect(firstInvalidate, greaterThanOrEqualTo(0));
      expect(log.indexOf('close:episode'), lessThan(firstInvalidate));
      expect(log.indexOf('close:audio'), lessThan(firstInvalidate));
      expect(log.indexOf('close:dict'), lessThan(firstInvalidate));
    });

    test('closes all three per-folder databases', () async {
      await releaseFolderDbHandles(
        '/lib/narou_n1',
        read: container.read,
        invalidate: recordingInvalidate,
      );

      expect(log.where((e) => e.startsWith('close:')).toSet(),
          {'close:episode', 'close:audio', 'close:dict'});
    });

    test('invalidates all three per-folder database providers', () async {
      await releaseFolderDbHandles(
        '/lib/narou_n1',
        read: container.read,
        invalidate: recordingInvalidate,
      );

      expect(invalidated.length, 3);
    });

    test('reads handles via the normalized folder key', () async {
      // A backslash-spelled path and its normalized form must resolve to the
      // same provider family key, so the release reaches the handle that other
      // call sites opened. We assert the helper applies folderDbKey by checking
      // the invalidated family argument matches the normalized key.
      const raw = r'C:\lib\narou_n1\..\narou_n1';
      await releaseFolderDbHandles(
        raw,
        read: container.read,
        invalidate: recordingInvalidate,
      );

      final key = folderDbKey(raw);
      expect(
        invalidated.contains(ttsAudioDatabaseProvider(key)),
        isTrue,
        reason: 'invalidate SHALL target the normalized key, not the raw path',
      );
    });
  });
}
