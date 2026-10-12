import 'dart:async';
import 'package:logging/logging.dart';

class PositionSnapshot {
  const PositionSnapshot(this.novelId, this.fileName, this.offset, this.hash);
  final String novelId;
  final String fileName;
  final int offset;
  final String hash;

  @override
  bool operator ==(Object other) =>
      other is PositionSnapshot &&
      novelId == other.novelId &&
      fileName == other.fileName &&
      offset == other.offset &&
      hash == other.hash;

  @override
  int get hashCode => Object.hash(novelId, fileName, offset, hash);
}

/// Serializes selection and position writes without delaying active reading.
class ReadingPositionWriter {
  ReadingPositionWriter({required this.save});
  final Future<void> Function(PositionSnapshot snapshot) save;
  static final _log = Logger('reading_progress');
  Future<void> _queue = Future.value();
  PositionSnapshot? _dirty;
  PositionSnapshot? _last;
  Timer? _timer;
  bool _disposed = false;
  final Set<String> _forgotten = {};

  /// Renames still to apply to saves already queued, per novel. See
  /// [renamePending].
  final Map<String, Map<String, String>> _renamed = {};

  void observe(PositionSnapshot snapshot) {
    if (_disposed ||
        _forgotten.contains(snapshot.novelId) ||
        snapshot == _last) {
      return;
    }
    _last = snapshot;
    _dirty = snapshot;
    _timer ??= Timer(const Duration(seconds: 2), () {
      _timer = null;
      unawaited(flush());
    });
  }

  Future<void> enqueue(Future<void> Function() operation) {
    _queue = _queue.then((_) => operation()).catchError((
      Object e,
      StackTrace st,
    ) {
      _log.warning('Failed to persist reading position', e, st);
    });
    return _queue;
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final snapshot = _dirty;
    _dirty = null;
    if (snapshot == null) return _queue;
    return enqueue(() async {
      if (_forgotten.contains(snapshot.novelId)) return;
      try {
        await save(_followRename(snapshot));
      } catch (_) {
        // The write is discarded per the failure contract, but the dedupe
        // guard must not go on suppressing it: a reader sitting still would
        // otherwise never produce another observation, and the position would
        // be lost for good rather than just delayed.
        if (_last == snapshot) _last = null;
        rethrow;
      }
    });
  }

  /// Points a pending position of [novelId] at its file's new name, after a
  /// download renamed the file ([renames] maps old name -> new name).
  ///
  /// The stored row is rekeyed to the new name, and a save only updates the
  /// row of the file it names, so one left under the old name would match
  /// nothing and the position would be lost.
  ///
  /// That covers saves already flushed into the queue too: the rename is
  /// applied when they run, for as long as the queue as it stands now takes to
  /// drain. Past that, an old name is just a name — a later file may reuse it.
  void renamePending(String novelId, Map<String, String> renames) {
    PositionSnapshot? follow(PositionSnapshot? snapshot) {
      if (snapshot == null || snapshot.novelId != novelId) return snapshot;
      final newName = renames[snapshot.fileName];
      if (newName == null) return snapshot;
      return PositionSnapshot(novelId, newName, snapshot.offset, snapshot.hash);
    }

    _dirty = follow(_dirty);
    _last = follow(_last);

    final active = {...?_renamed[novelId], ...renames};
    _renamed[novelId] = active;
    _queue.whenComplete(() {
      // A later rename of the same novel owns the entry from then on.
      if (identical(_renamed[novelId], active)) _renamed.remove(novelId);
    });
  }

  PositionSnapshot _followRename(PositionSnapshot snapshot) {
    final newName = _renamed[snapshot.novelId]?[snapshot.fileName];
    if (newName == null) return snapshot;
    return PositionSnapshot(
      snapshot.novelId,
      newName,
      snapshot.offset,
      snapshot.hash,
    );
  }

  /// Drops any pending position for [novelId] and blocks further writes for
  /// it until the in-flight queue has drained, so a deletion cannot race a
  /// save that would put the row back. The block is released once the returned
  /// future completes: keeping it for the session would silently stop
  /// recording positions if the same folder name is added again later.
  Future<void> forgetNovel(String novelId) async {
    _forgotten.add(novelId);
    if (_dirty?.novelId == novelId) _dirty = null;
    if (_last?.novelId == novelId) _last = null;
    try {
      await _queue;
    } finally {
      _forgotten.remove(novelId);
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(flush());
  }
}
