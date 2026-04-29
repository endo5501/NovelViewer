import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'tts_audio_database_provider.dart';

/// Tracks novel folders touched in the current session and vacuums each
/// `tts_audio.db` file when the app transitions to
/// `AppLifecycleState.detached` (i.e. on exit).
///
/// Why deferred: `PRAGMA incremental_vacuum(0)` on a 100MB+ database can
/// stall the UI for hundreds of milliseconds. Doing it synchronously inside
/// `deleteEpisode` produced a visible spike each time the user deleted a
/// generated episode. Batching to exit time fixes the spike without
/// permanently leaking deleted-blob pages.
class VacuumLifecycle with WidgetsBindingObserver {
  VacuumLifecycle({
    required this.vacuumFolder,
    Logger? logger,
  }) : _log = logger ?? Logger('tts.vacuum');

  /// Performs `PRAGMA incremental_vacuum(0)` for the given folder.
  final Future<void> Function(String folderPath) vacuumFolder;
  final Logger _log;

  final _dirty = <String>{};
  Future<void>? _inFlight;

  /// Folders queued for vacuum on next `detached` event.
  Iterable<String> get pendingFolders => List.unmodifiable(_dirty);

  /// Marks [folderPath] dirty so its database will be vacuumed at app exit.
  /// Idempotent — repeated calls for the same folder produce a single vacuum.
  void markDirty(String folderPath) {
    _dirty.add(folderPath);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.detached) return;
    if (_inFlight != null) return; // a previous detached batch is still running
    _inFlight = _vacuumAll();
  }

  /// Awaits the in-flight vacuum batch (if any). Useful in tests to assert
  /// post-vacuum state.
  Future<void> flushPending() async {
    final inFlight = _inFlight;
    if (inFlight != null) await inFlight;
  }

  Future<void> _vacuumAll() async {
    if (_dirty.isEmpty) {
      _inFlight = null;
      return;
    }
    final pending = List.of(_dirty);
    _dirty.clear();
    // Run in parallel — each folder writes to its own SQLite file, and at
    // detached time the OS may kill the process at any moment, so don't pay
    // O(N × hundreds-of-ms) when O(slowest folder) suffices.
    await Future.wait(pending.map((folder) async {
      try {
        await vacuumFolder(folder);
      } catch (e, st) {
        _log.warning('vacuum failed for $folder', e, st);
      }
    }));
    _inFlight = null;
  }
}

final vacuumLifecycleProvider = Provider<VacuumLifecycle>((ref) {
  final lifecycle = VacuumLifecycle(
    vacuumFolder: (folder) async {
      final db = ref.read(ttsAudioDatabaseProvider(folder));
      await db.reclaimSpace();
    },
  );
  WidgetsBinding.instance.addObserver(lifecycle);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(lifecycle);
  });
  return lifecycle;
});
