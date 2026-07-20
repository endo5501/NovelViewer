import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/db_provider_container.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;

  setUp(() {
    tempDir =
        Directory.systemTemp.createTempSync('tts_audio_db_provider_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ttsAudioDatabaseProvider family', () {
    test('returns the same instance for the same folder path', () {
      final container = ProviderContainer();
      addDbContainerTearDown(container);

      final db1 =
          container.read(ttsAudioDatabaseProvider(tempDir.path));
      final db2 =
          container.read(ttsAudioDatabaseProvider(tempDir.path));
      expect(identical(db1, db2), isTrue);
    });

    test('returns different instances for different folder paths', () {
      final tempDir2 = Directory.systemTemp
          .createTempSync('tts_audio_db_provider_test_b_');
      addTearDown(() => tempDir2.deleteSync(recursive: true));

      final container = ProviderContainer();
      addDbContainerTearDown(container);

      final dbA =
          container.read(ttsAudioDatabaseProvider(tempDir.path));
      final dbB =
          container.read(ttsAudioDatabaseProvider(tempDir2.path));
      expect(identical(dbA, dbB), isFalse);
    });

    test('registry.closeAll releases the handle; a re-read yields a new one',
        () async {
      final container = ProviderContainer();
      addDbContainerTearDown(container);

      final db = container.read(ttsAudioDatabaseProvider(tempDir.path));
      // Force open by accessing the underlying database
      await db.database;

      // The registry owns the handle: closeAll closes it (awaited) and evicts.
      // The thin-view provider is invalidated so it recomputes from the
      // registry on the next read. A bare invalidate alone would NOT release
      // the registry-owned handle.
      await container
          .read(perFolderDbRegistryProvider)
          .closeAll(tempDir.path);
      container.invalidate(ttsAudioDatabaseProvider(tempDir.path));

      // Reading again should yield a brand-new instance.
      final db2 = container.read(ttsAudioDatabaseProvider(tempDir.path));
      expect(identical(db, db2), isFalse);
    });

    test('awaited container disposal releases the file lock on the folder',
        () async {
      final container = ProviderContainer();

      final db = container.read(ttsAudioDatabaseProvider(tempDir.path));
      await db.database; // force open

      await disposeContainerWithDatabases(container);

      // Every handle is closed, so the folder holding tts_audio.db can be
      // removed. On Windows this throws PathAccessException (errno 32) if any
      // close is still in flight — which is exactly what a bare
      // `container.dispose()` leaves behind, since Riverpod does not await the
      // registry's asynchronous onDispose.
      tempDir.deleteSync(recursive: true);
      expect(tempDir.existsSync(), isFalse);
    });
  });
}
