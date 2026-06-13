import 'dart:async';

import 'package:flutter/foundation.dart';

import 'database_closing_exception.dart';

/// Serializes the open/close lifecycle of a single database connection so that
/// concurrent access cannot double-open, and a `close()` cannot race an
/// in-flight open into re-locking a file that is about to be deleted.
///
/// The wrappers (`NovelDatabase`, `EpisodeCacheDatabase`, `TtsAudioDatabase`,
/// `TtsDictionaryDatabase`) delegate their `database` getter and `close()` to
/// one gate each instead of holding a raw `Database? _database`, which is the
/// root cause of the "novel cannot be deleted" Windows file-lock bug.
///
/// Invariants:
/// - [_open] caches the single in-flight (or completed) open Future, so
///   concurrent [resource] callers share one [_opener] run and one handle.
/// - [close] awaits that in-flight open before closing, so the handle it
///   closes is exactly the one the open produced — nothing is created after
///   close returns.
/// - While [close] runs, [resource] throws [DatabaseClosingException] rather
///   than re-opening.
/// - A failed open is not cached, so the next [resource] access retries.
///
/// The [_opener] MUST NOT call back into the gate (no re-entrancy).
class DbConnectionGate<T> {
  DbConnectionGate({
    required Future<T> Function() opener,
    required Future<void> Function(T resource) closer,
  })  : _opener = opener,
        _closer = closer;

  final Future<T> Function() _opener;
  final Future<void> Function(T resource) _closer;

  Future<T>? _open;
  bool _closing = false;

  /// Test seam: pre-populate the gate with an already-open resource, bypassing
  /// the opener. Mirrors the wrappers' existing `@visibleForTesting`
  /// `setDatabase` hook so injected in-memory databases keep working.
  @visibleForTesting
  void seedResource(T resource) {
    _open = Future<T>.value(resource);
  }

  /// The opened resource, opening it if necessary.
  ///
  /// Throws [DatabaseClosingException] if called while [close] is in progress.
  Future<T> get resource {
    if (_closing) throw const DatabaseClosingException();
    return _open ??= _openOnce();
  }

  Future<T> _openOnce() async {
    try {
      return await _opener();
    } catch (_) {
      // Do not cache a failed open: a later access must be free to retry.
      _open = null;
      rethrow;
    }
  }

  /// Closes the connection, awaiting any in-flight open first so the handle it
  /// produced is the handle that gets closed.
  Future<void> close() async {
    _closing = true;
    try {
      final opening = _open;
      if (opening != null) {
        try {
          final resource = await opening;
          await _closer(resource);
        } catch (_) {
          // The open itself failed — there is no handle to close.
        }
      }
      _open = null;
    } finally {
      _closing = false;
    }
  }
}
