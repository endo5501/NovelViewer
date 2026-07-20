import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry_provider.dart';

import 'db_provider_container.dart';

/// A [TtsAudioDatabase] whose `close()` completes only after a microtask-plus
/// delay, standing in for the real (asynchronous) SQLite close. It never opens
/// a file, so the test needs no temp directory.
class _SlowClosingAudioDatabase extends TtsAudioDatabase {
  _SlowClosingAudioDatabase(super.folderPath, {required this.onClosed});

  final void Function() onClosed;

  @override
  Future<void> close() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    onClosed();
  }
}

void main() {
  group('disposeContainerWithDatabases', () {
    late bool closed;
    late ProviderContainer container;

    setUp(() {
      closed = false;
      final registry = PerFolderDbRegistry(
        audioFactory: (folder) =>
            _SlowClosingAudioDatabase(folder, onClosed: () => closed = true),
      );
      container = ProviderContainer(
        overrides: [perFolderDbRegistryProvider.overrideWithValue(registry)],
      );
      // Open a registry-owned handle, as any provider touching a per-folder DB
      // would.
      container.read(ttsAudioDatabaseProvider('/tmp/does-not-need-to-exist'));
    });

    test('returns only after every per-folder database handle is closed',
        () async {
      await disposeContainerWithDatabases(container);

      expect(
        closed,
        isTrue,
        reason: 'the file lock must be gone before the caller deletes the '
            'folder, otherwise deleteSync fails with errno 32 on Windows',
      );
    });

    test(
        'container.dispose() alone leaves the handle open '
        '(why this helper exists)', () async {
      // Riverpod does not await the Future returned by an onDispose callback,
      // so the registry close is still in flight when dispose() returns.
      container.dispose();

      expect(closed, isFalse);

      // Let the background close finish so the test does not leak it.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });
}
