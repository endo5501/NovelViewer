import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/reading_progress/domain/reading_progress.dart';

import '../domain/device_progress.dart';
import '../domain/sync_progress_record.dart';
import '../domain/sync_rules.dart';
import 'progress_sync_repository.dart';
import 'progress_sync_store.dart';

final _log = Logger('progress_sync');

class SyncRunStatus {
  final bool running;
  final DateTime? lastSuccessAt;

  /// The last failure, until a later sync succeeds.
  final String? lastError;

  const SyncRunStatus({
    this.running = false,
    this.lastSuccessAt,
    this.lastError,
  });
}

/// Runs pulls and pushes one at a time (design D7). A request made while a
/// run is in flight joins the next run, so a burst of triggers costs one
/// extra run, not one each.
class ProgressSyncService {
  final bool Function() _isAvailable;
  final bool Function() _isSignedIn;
  final ProgressSyncStore _store;
  final ProgressSyncRepository _repository;
  final Future<String> Function() _deviceId;
  final String _deviceName;
  final Future<void> Function() _flushPendingPositions;
  final Future<List<ReadingProgress>> Function() _loadLocalProgress;
  final Future<Set<String>> Function() _syncableNovelIds;
  final Future<int?> Function(String novelId, String fileName) _episodeOf;
  final DateTime Function() _now;

  final ValueNotifier<SyncRunStatus> status = ValueNotifier(
    const SyncRunStatus(),
  );
  final StreamController<void> _pulled = StreamController.broadcast();

  bool _pendingPush = false;
  bool _pendingPull = false;
  Future<void>? _running;

  ProgressSyncService({
    required bool Function() isAvailable,
    required bool Function() isSignedIn,
    required ProgressSyncStore store,
    required ProgressSyncRepository repository,
    required Future<String> Function() deviceId,
    required String deviceName,
    required Future<void> Function() flushPendingPositions,
    required Future<List<ReadingProgress>> Function() loadLocalProgress,
    required Future<Set<String>> Function() syncableNovelIds,
    required Future<int?> Function(String novelId, String fileName) episodeOf,
    DateTime Function()? now,
  }) : _isAvailable = isAvailable,
       _isSignedIn = isSignedIn,
       _store = store,
       _repository = repository,
       _deviceId = deviceId,
       _deviceName = deviceName,
       _flushPendingPositions = flushPendingPositions,
       _loadLocalProgress = loadLocalProgress,
       _syncableNovelIds = syncableNovelIds,
       _episodeOf = episodeOf,
       _now = now ?? DateTime.now;

  /// Fires after each pull has stored what it received.
  Stream<void> get pulled => _pulled.stream;

  /// Publishes this device's progress.
  Future<void> push() => _request(push: true);

  /// Fetches the other devices' progress.
  Future<void> pull() => _request(pull: true);

  /// The settings screen's "sync now": push, then pull.
  Future<void> syncNow() => _request(push: true, pull: true);

  void dispose() {
    status.dispose();
    _pulled.close();
  }

  /// The single entry point: refuses unless sync is offered and signed in, so
  /// no surface can reach Google without both.
  Future<void> _request({bool push = false, bool pull = false}) {
    if (!_isAvailable() || !_isSignedIn()) return Future.value();
    _pendingPush |= push;
    _pendingPull |= pull;
    return _running ??= _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    status.value = _status(running: true);
    try {
      while (_pendingPush || _pendingPull) {
        final doPush = _pendingPush;
        final doPull = _pendingPull;
        _pendingPush = false;
        _pendingPull = false;
        if (doPush) await _guard('push', _push);
        if (doPull) await _guard('pull', _pull);
      }
    } finally {
      status.value = _status(running: false);
    }
  }

  Future<void> _guard(String what, Future<void> Function() run) async {
    try {
      await run();
      status.value = SyncRunStatus(running: true, lastSuccessAt: _now());
    } catch (e, st) {
      _log.warning('Progress sync $what failed', e, st);
      status.value = _status(lastError: e.toString());
    }
  }

  SyncRunStatus _status({bool? running, String? lastError}) {
    final current = status.value;
    return SyncRunStatus(
      running: running ?? current.running,
      lastSuccessAt: current.lastSuccessAt,
      lastError: lastError ?? current.lastError,
    );
  }

  Future<void> _push() async {
    await _flushPendingPositions();
    final local = await _loadLocalProgress();
    final syncable = await _syncableNovelIds();
    final lastPushed = await _repository.findAllOwn();
    final episodes = <String, int?>{
      for (final progress in local)
        if (syncable.contains(progress.novelId))
          progress.novelId: await _episodeOf(
            progress.novelId,
            progress.fileName,
          ),
    };
    final records = buildOwnRecords(
      local: local,
      syncableNovelIds: syncable,
      lastPushed: lastPushed,
      episodeOf: (novelId, _) => episodes[novelId],
    );
    if (_sameRecords(records, lastPushed)) return;
    await _store.writeOwn(
      DeviceProgress(
        deviceId: await _deviceId(),
        deviceName: _deviceName,
        records: records,
      ),
    );
    await _repository.replaceOwn(records);
  }

  Future<void> _pull() async {
    final devices = await _store.fetchAll();
    await _repository.replaceRemote(
      selfDeviceId: await _deviceId(),
      devices: devices,
    );
    _pulled.add(null);
  }

  static bool _sameRecords(
    List<SyncProgressRecord> records,
    Map<String, SyncProgressRecord> lastPushed,
  ) {
    return const MapEquality<String, SyncProgressRecord>().equals({
      for (final record in records) record.novelId: record,
    }, lastPushed);
  }
}
