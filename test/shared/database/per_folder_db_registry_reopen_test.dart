import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Real files, because the failure lives in sqflite itself: it hands a second
/// open of a path the very connection already open there, so a handle reopened
/// while the evicted one is still closing receives a connection that the close
/// then shuts.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory folder;
  late PerFolderDbRegistry registry;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('registry_reopen_');
    registry = PerFolderDbRegistry();
  });

  tearDown(() async {
    await registry.disposeAll();
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  });

  test(
    'a novel_data handle reopened while the evicted one is still closing '
    'stays usable',
    () async {
      await (await registry.novelData(folder.path).database).query(
        'word_summaries',
      );

      // Leaving the folder, then coming straight back: the reopen starts
      // before the background close has reached novel_data.db.
      registry.releaseInBackground(folder.path);
      final reopened = await registry.novelData(folder.path).database;

      await pumpEventQueue();
      expect(reopened.isOpen, isTrue);
      await expectLater(reopened.query('word_summaries'), completes);
    },
  );

  test(
    'the other per-folder handles reopened during a background close stay '
    'usable',
    () async {
      await registry.episodeCache(folder.path).database;
      await registry.ttsAudio(folder.path).database;
      await registry.ttsDictionary(folder.path).database;

      registry.releaseInBackground(folder.path);
      final episode = await registry.episodeCache(folder.path).database;
      final audio = await registry.ttsAudio(folder.path).database;
      final dictionary = await registry.ttsDictionary(folder.path).database;

      await pumpEventQueue();
      expect(episode.isOpen, isTrue);
      expect(audio.isOpen, isTrue);
      expect(dictionary.isOpen, isTrue);
    },
  );
}
