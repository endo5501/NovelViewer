import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Guards the design's "background analysis write during folder teardown"
/// concern (group 7.3): when a folder's `novel_data.db` handle is released
/// (folder move/delete) while an analysis still holds a repository bound to it,
/// the write MUST fail explicitly rather than corrupt the file or re-lock it.
/// The protection is the shared connection gate the wrapper goes through.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory folder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('analysis_after_close_');
  });

  tearDown(() {
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  });

  test('a folder-scoped summary write after closeAll fails instead of '
      'corrupting the released novel_data.db', () async {
    final registry = PerFolderDbRegistry();
    addTearDown(registry.disposeAll);

    final wrapper = registry.novelData(folder.path);
    final db = await wrapper.database; // analysis captured this handle
    final repo = LlmSummaryRepository(db);

    // A write before teardown succeeds.
    await repo.saveSnapshot(
        word: 'アリス', coveredUpToEpisode: 1, summary: 'ok', sourceFile: '001.txt');

    // Folder teardown (move/delete) releases the handle.
    await registry.closeAll(folder.path);

    // A late analysis write now fails explicitly (closed handle) — it does not
    // silently succeed against a released file.
    await expectLater(
      repo.saveSnapshot(
          word: 'ボブ', coveredUpToEpisode: 1, summary: 'late', sourceFile: '001.txt'),
      throwsA(anything),
    );
  });
}
