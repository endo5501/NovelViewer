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
        await save(snapshot);
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
