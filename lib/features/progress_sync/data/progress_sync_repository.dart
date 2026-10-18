import 'package:sqflite/sqflite.dart';

import '../../novel_metadata_db/data/novel_database.dart';
import '../domain/device_progress.dart';
import '../domain/sync_progress_record.dart';

/// The progress-sync tables of `novel_metadata.db` (schema v12).
class ProgressSyncRepository {
  static const _remoteTable = 'sync_remote_progress';
  static const _ownTable = 'sync_own_progress';
  static const _handledTable = 'sync_handled';

  final NovelDatabase _novelDatabase;

  ProgressSyncRepository(this._novelDatabase);

  /// Replaces every received record with [devices], the full result of one
  /// pull: a device missing from it has lost its file on Drive and goes too.
  /// This device's own file is skipped, since its records are not another
  /// device's reading.
  Future<void> replaceRemote({
    required String selfDeviceId,
    required List<DeviceProgress> devices,
  }) async {
    final db = await _novelDatabase.database;
    await db.transaction((txn) async {
      await txn.delete(_remoteTable);
      for (final device in devices) {
        if (device.deviceId == selfDeviceId) continue;
        for (final record in device.records) {
          await txn.insert(_remoteTable, {
            'device_id': device.deviceId,
            'device_name': device.deviceName,
            ..._recordToRow(record),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<List<RemoteProgress>> findRemoteByNovel(String novelId) async {
    final db = await _novelDatabase.database;
    final rows = await db.query(
      _remoteTable,
      where: 'novel_id = ?',
      whereArgs: [novelId],
    );
    return [
      for (final row in rows)
        RemoteProgress(
          deviceId: row['device_id'] as String,
          deviceName: row['device_name'] as String,
          record: _rowToRecord(row),
        ),
    ];
  }

  /// Replaces the set this device last pushed with [records].
  Future<void> replaceOwn(List<SyncProgressRecord> records) async {
    final db = await _novelDatabase.database;
    await db.transaction((txn) async {
      await txn.delete(_ownTable);
      for (final record in records) {
        await txn.insert(
          _ownTable,
          _recordToRow(record),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Records [record] as this device's last pushed position for its novel,
  /// used when the device adopts another device's record so the next push
  /// keeps that record's `read_at` (design D6).
  Future<void> upsertOwn(SyncProgressRecord record) async {
    final db = await _novelDatabase.database;
    await db.insert(
      _ownTable,
      _recordToRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, SyncProgressRecord>> findAllOwn() async {
    final db = await _novelDatabase.database;
    final rows = await db.query(_ownTable, orderBy: 'novel_id');
    return {
      for (final row in rows) row['novel_id'] as String: _rowToRecord(row),
    };
  }

  Future<DateTime?> findHandled(String novelId) async {
    final db = await _novelDatabase.database;
    final rows = await db.query(
      _handledTable,
      where: 'novel_id = ?',
      whereArgs: [novelId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.single['handled_read_at'] as String);
  }

  Future<void> saveHandled(String novelId, DateTime readAt) async {
    final db = await _novelDatabase.database;
    await db.insert(_handledTable, {
      'novel_id': novelId,
      'handled_read_at': readAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Forgets everything sync learned, for sign-out: another account may sign
  /// in next. The device's own `reading_progress` is not sync state and stays.
  Future<void> clearAll() async {
    final db = await _novelDatabase.database;
    await db.transaction((txn) async {
      await txn.delete(_remoteTable);
      await txn.delete(_ownTable);
      await txn.delete(_handledTable);
    });
  }

  static Map<String, Object?> _recordToRow(SyncProgressRecord record) {
    return {
      'novel_id': record.novelId,
      'episode': record.episode,
      'file_name': record.fileName,
      'body_offset': record.bodyOffset,
      'body_hash': record.bodyHash,
      'read_at': record.readAt.toUtc().toIso8601String(),
    };
  }

  static SyncProgressRecord _rowToRecord(Map<String, Object?> row) {
    return SyncProgressRecord(
      novelId: row['novel_id'] as String,
      episode: row['episode'] as int,
      fileName: row['file_name'] as String,
      bodyOffset: row['body_offset'] as int,
      bodyHash: row['body_hash'] as String?,
      readAt: DateTime.parse(row['read_at'] as String),
    );
  }
}
