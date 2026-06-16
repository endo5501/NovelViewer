import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_database.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/database/folder_db_handles.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';
import 'package:novel_viewer/shared/database/novel_data_database.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry_provider.dart';

class _FakeEpisode extends EpisodeCacheDatabase {
  _FakeEpisode(this.log) : super('unused');
  final List<String> log;
  @override
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    log.add('close:episode');
  }
}

class _FakeAudio extends TtsAudioDatabase {
  _FakeAudio(this.log) : super('unused');
  final List<String> log;
  @override
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    log.add('close:audio');
  }
}

class _FakeDict extends TtsDictionaryDatabase {
  _FakeDict(this.log) : super('unused');
  final List<String> log;
  @override
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    log.add('close:dict');
  }
}

class _FakeNovelData extends NovelDataDatabase {
  _FakeNovelData(this.log) : super('unused');
  final List<String> log;
  @override
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    log.add('close:novel_data');
  }
}

void main() {
  late List<String> log;
  late List<ProviderOrFamily> invalidated;
  late ProviderContainer container;

  setUp(() {
    log = <String>[];
    invalidated = <ProviderOrFamily>[];
    final registry = PerFolderDbRegistry(
      episodeFactory: (_) => _FakeEpisode(log),
      audioFactory: (_) => _FakeAudio(log),
      dictionaryFactory: (_) => _FakeDict(log),
      novelDataFactory: (_) => _FakeNovelData(log),
    );
    // Pre-open the handles so the release has something to close.
    registry.episodeCache('/lib/narou_n1');
    registry.ttsAudio('/lib/narou_n1');
    registry.ttsDictionary('/lib/narou_n1');
    registry.novelData('/lib/narou_n1');
    container = ProviderContainer(overrides: [
      perFolderDbRegistryProvider.overrideWithValue(registry),
    ]);
  });

  tearDown(() => container.dispose());

  void recordingInvalidate(ProviderOrFamily provider) {
    log.add('invalidate');
    invalidated.add(provider);
  }

  group('releaseFolderDbHandles', () {
    test('awaits all four close() calls before any invalidate', () async {
      await releaseFolderDbHandles(
        '/lib/narou_n1',
        read: container.read,
        invalidate: recordingInvalidate,
      );

      final firstInvalidate = log.indexOf('invalidate');
      expect(firstInvalidate, greaterThanOrEqualTo(0));
      expect(log.indexOf('close:episode'), lessThan(firstInvalidate));
      expect(log.indexOf('close:audio'), lessThan(firstInvalidate));
      expect(log.indexOf('close:dict'), lessThan(firstInvalidate));
      expect(log.indexOf('close:novel_data'), lessThan(firstInvalidate));
    });

    test('closes all four per-folder databases', () async {
      await releaseFolderDbHandles(
        '/lib/narou_n1',
        read: container.read,
        invalidate: recordingInvalidate,
      );

      expect(log.where((e) => e.startsWith('close:')).toSet(),
          {'close:episode', 'close:audio', 'close:dict', 'close:novel_data'});
    });

    test('invalidates all four per-folder database providers', () async {
      await releaseFolderDbHandles(
        '/lib/narou_n1',
        read: container.read,
        invalidate: recordingInvalidate,
      );

      expect(invalidated.length, 4);
    });

    test('invalidates providers under the normalized folder key', () async {
      const raw = r'C:\lib\narou_n1\..\narou_n1';
      await releaseFolderDbHandles(
        raw,
        read: container.read,
        invalidate: recordingInvalidate,
      );

      final key = folderDbKey(raw);
      expect(invalidated.contains(ttsAudioDatabaseProvider(key)), isTrue,
          reason: 'invalidate SHALL target the normalized key, not the raw path');
    });
  });
}
