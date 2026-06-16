import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_database.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';
import 'package:novel_viewer/shared/database/novel_data_database.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry.dart';

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

/// An episode-cache fake whose close() blocks on [gate], so a test can hold a
/// release "in flight" and observe whether another caller waits for it.
class _GatedEpisode extends EpisodeCacheDatabase {
  _GatedEpisode(this.gate, this.log) : super('unused');
  final Future<void> gate;
  final List<String> log;
  @override
  Future<void> close() async {
    await gate;
    log.add('close:episode');
  }
}

void main() {
  late List<String> log;

  PerFolderDbRegistry buildRegistry() => PerFolderDbRegistry(
        episodeFactory: (_) => _FakeEpisode(log),
        audioFactory: (_) => _FakeAudio(log),
        dictionaryFactory: (_) => _FakeDict(log),
        novelDataFactory: (_) => _FakeNovelData(log),
      );

  setUp(() => log = <String>[]);

  group('PerFolderDbRegistry', () {
    test('returns the same handle for a folder until closeAll', () {
      final registry = buildRegistry();
      final a1 = registry.ttsAudio('/lib/n1');
      final a2 = registry.ttsAudio('/lib/n1');
      expect(a1, same(a2));
    });

    test('closeAll closes all four handles then evicts them', () async {
      final registry = buildRegistry();
      final e1 = registry.episodeCache('/lib/n1');
      final a1 = registry.ttsAudio('/lib/n1');
      final d1 = registry.ttsDictionary('/lib/n1');
      final nd1 = registry.novelData('/lib/n1');

      await registry.closeAll('/lib/n1');

      // All four close() awaited.
      expect(log.toSet(),
          {'close:episode', 'close:audio', 'close:dict', 'close:novel_data'});

      // Evicted: a subsequent access creates fresh instances.
      expect(registry.episodeCache('/lib/n1'), isNot(same(e1)));
      expect(registry.ttsAudio('/lib/n1'), isNot(same(a1)));
      expect(registry.ttsDictionary('/lib/n1'), isNot(same(d1)));
      expect(registry.novelData('/lib/n1'), isNot(same(nd1)));
    });

    test('closeAll on a folder with no open handles is a no-op', () async {
      final registry = buildRegistry();
      await registry.closeAll('/lib/never-opened');
      expect(log, isEmpty);
    });

    test('normalizes the folder key so equivalent paths share one handle', () {
      final registry = buildRegistry();
      // Build an equivalent pair using the host OS separators so `..` is
      // resolved by `folderDbKey` (p.normalize) on every platform.
      final base = p.join('lib', 'n1');
      final redundant = p.join('lib', 'n1', '..', 'n1');
      final a1 = registry.ttsAudio(redundant);
      final a2 = registry.ttsAudio(base);
      expect(a1, same(a2),
          reason: 'folderDbKey($redundant) must match folderDbKey($base) '
              '(${folderDbKey(redundant)} == ${folderDbKey(base)})');
    });

    test('closeAll uses the normalized key to reach handles', () async {
      final registry = buildRegistry();
      // Open under the base path, close via an equivalent redundant path built
      // with host OS separators so the normalized keys match on every platform.
      registry.ttsAudio(p.join('lib', 'n1'));
      await registry.closeAll(p.join('lib', 'n1', '..', 'n1'));
      expect(log, contains('close:audio'));
    });

    test('closeEpisodeCache closes only the episode handle', () async {
      final registry = buildRegistry();
      registry.episodeCache('/lib/n1');
      final audio = registry.ttsAudio('/lib/n1');
      final dict = registry.ttsDictionary('/lib/n1');
      final novelData = registry.novelData('/lib/n1');

      await registry.closeEpisodeCache('/lib/n1');

      expect(log, ['close:episode']);
      // tts_audio / tts_dictionary / novel_data handles are untouched.
      expect(registry.ttsAudio('/lib/n1'), same(audio));
      expect(registry.ttsDictionary('/lib/n1'), same(dict));
      expect(registry.novelData('/lib/n1'), same(novelData));
    });

    test('novelData returns the same handle until closeAll', () {
      final registry = buildRegistry();
      final n1 = registry.novelData('/lib/n1');
      final n2 = registry.novelData('/lib/n1');
      expect(n1, same(n2));
    });

    test('releaseInBackground also evicts and closes the novel_data handle',
        () async {
      final registry = buildRegistry();
      final n1 = registry.novelData('/lib/n1');

      registry.releaseInBackground('/lib/n1');

      expect(registry.novelData('/lib/n1'), isNot(same(n1)));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(log, contains('close:novel_data'));
    });

    test('closeAll awaits an in-flight releaseInBackground close', () async {
      final gate = Completer<void>();
      final closeLog = <String>[];
      final registry = PerFolderDbRegistry(
        episodeFactory: (_) => _GatedEpisode(gate.future, closeLog),
        audioFactory: (_) => _FakeAudio(log),
        dictionaryFactory: (_) => _FakeDict(log),
      );
      registry.episodeCache('/lib/n1');

      registry.releaseInBackground('/lib/n1'); // starts the gated bg close

      var closeAllDone = false;
      final closing =
          registry.closeAll('/lib/n1').then((_) => closeAllDone = true);

      await Future<void>.delayed(Duration.zero);
      expect(closeAllDone, isFalse,
          reason: 'closeAll MUST await the in-flight background close so a '
              'file operation does not race it');

      gate.complete();
      await closing;
      expect(closeAllDone, isTrue);
      expect(closeLog, contains('close:episode'));
    });

    test('closeAll awaits ALL overlapping background closes for a folder',
        () async {
      final gates = [Completer<void>(), Completer<void>()];
      final closeLog = <String>[];
      var i = 0;
      final registry = PerFolderDbRegistry(
        episodeFactory: (_) => _GatedEpisode(gates[i++].future, closeLog),
        audioFactory: (_) => _FakeAudio(log),
        dictionaryFactory: (_) => _FakeDict(log),
      );

      registry.episodeCache('/lib/n1'); // E0 (gate0)
      registry.releaseInBackground('/lib/n1'); // bg close C1 of E0
      registry.episodeCache('/lib/n1'); // E1 (gate1), fresh
      registry.releaseInBackground('/lib/n1'); // bg close C2 of E1

      var done = false;
      final closing =
          registry.closeAll('/lib/n1').then((_) => done = true);

      // Complete only the LATER close. If closeAll tracked just the latest
      // background close (overwriting the earlier one), it would finish here.
      gates[1].complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(done, isFalse,
          reason: 'closeAll MUST also await the earlier background close');

      gates[0].complete();
      await closing;
      expect(done, isTrue);
    });

    test('releaseInBackground evicts synchronously and closes in background',
        () async {
      final registry = buildRegistry();
      final a1 = registry.ttsAudio('/lib/n1');

      registry.releaseInBackground('/lib/n1');

      // Evicted synchronously: the next access is a fresh handle even before
      // the background close has run.
      expect(registry.ttsAudio('/lib/n1'), isNot(same(a1)));

      // The old handle is closed in the background.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(log, contains('close:audio'));
    });
  });
}
