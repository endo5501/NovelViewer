import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:novel_viewer/features/bookmark/data/bookmark_repository.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/novel_delete/data/novel_delete_service.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';

class _RecordingFileSystemService extends Fake implements FileSystemService {
  final List<String> log;
  final bool throwOnDelete;
  _RecordingFileSystemService(this.log, {this.throwOnDelete = false});

  @override
  Future<void> deleteDirectory(String path) async {
    if (throwOnDelete) {
      // Mimics a Windows file lock surfacing as an IO failure.
      throw Exception('locked');
    }
    log.add('deleteDirectory');
  }
}

class _RecordingNovelRepo extends Fake implements NovelRepository {
  final List<String> log;
  _RecordingNovelRepo(this.log);
  @override
  Future<void> deleteByFolderName(String folderName,
          {DatabaseExecutor? txn}) async =>
      log.add('novel');
}

class _RecordingSummaryRepo extends Fake implements LlmSummaryRepository {
  final List<String> log;
  _RecordingSummaryRepo(this.log);
  @override
  Future<void> deleteByFolderName(String folderName,
          {DatabaseExecutor? txn}) async =>
      log.add('summary');
}

class _RecordingFactCacheRepo extends Fake implements FactCacheRepository {
  final List<String> log;
  _RecordingFactCacheRepo(this.log);
  @override
  Future<void> deleteByFolderName(String folderName,
          {DatabaseExecutor? txn}) async =>
      log.add('factCache');
}

class _RecordingProgressRepo extends Fake implements ReadingProgressRepository {
  final List<String> log;
  _RecordingProgressRepo(this.log);
  @override
  Future<void> deleteByNovelId(String novelId, {DatabaseExecutor? txn}) async =>
      log.add('progress');
}

class _RecordingBookmarkRepo extends Fake implements BookmarkRepository {
  final List<String> log;
  _RecordingBookmarkRepo(this.log);
  @override
  Future<void> deleteByNovelId(String novelId, {DatabaseExecutor? txn}) async =>
      log.add('bookmark');
}

/// Minimal in-memory stand-in that runs the transaction callback inline with a
/// dummy executor — the recording repos ignore [txn], so only ordering and the
/// roll-back-on-throw contract matter here.
class _FakeTransaction extends Fake implements Transaction {}

class _FakeTxnDatabase extends Fake implements Database {
  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action,
          {bool? exclusive}) async =>
      action(_FakeTransaction());
}

class _FakeNovelDatabase extends Fake implements NovelDatabase {
  final Database _db = _FakeTxnDatabase();
  @override
  Future<Database> get database async => _db;
}

void main() {
  late List<String> log;

  NovelDeleteService buildService({
    bool throwOnDelete = false,
    Future<void> Function(String)? releaseFolderHandles,
  }) {
    return NovelDeleteService(
      novelDatabase: _FakeNovelDatabase(),
      novelRepository: _RecordingNovelRepo(log),
      summaryRepository: _RecordingSummaryRepo(log),
      factCacheRepository: _RecordingFactCacheRepo(log),
      readingProgressRepository: _RecordingProgressRepo(log),
      bookmarkRepository: _RecordingBookmarkRepo(log),
      fileSystemService:
          _RecordingFileSystemService(log, throwOnDelete: throwOnDelete),
      releaseFolderHandles: releaseFolderHandles,
    );
  }

  setUp(() => log = <String>[]);

  group('NovelDeleteService deletion order', () {
    test('releases handles (awaited) before file system deletion', () async {
      var releaseFinished = false;
      final service = buildService(releaseFolderHandles: (dir) async {
        // Simulate an async close; the service MUST await this fully before
        // touching the file system.
        await Future<void>.delayed(Duration.zero);
        releaseFinished = true;
        log.add('release');
      });

      await service.delete('narou_n1', '/lib/narou_n1');

      expect(log.first, 'release');
      expect(log.indexOf('release'), lessThan(log.indexOf('deleteDirectory')),
          reason: 'handle release SHALL complete before file deletion');
      expect(releaseFinished, isTrue);
    });

    test('deletes files before DB rows', () async {
      final service = buildService();

      await service.delete('narou_n1', '/lib/narou_n1');

      expect(log.indexOf('deleteDirectory'), lessThan(log.indexOf('novel')),
          reason: 'file system deletion SHALL precede DB record deletion');
      expect(log, containsAll(['novel', 'summary', 'factCache', 'progress']));
    });

    test('releases handles for the target directory (delete flow)', () async {
      String? received;
      final service = buildService(releaseFolderHandles: (dir) async {
        received = dir;
        log.add('release');
      });

      await service.delete('narou_n1', '/lib/narou_n1');

      expect(received, '/lib/narou_n1',
          reason: 'the novel delete flow SHALL release per-folder handles for '
              'the folder being deleted, like move/rename/folder-delete');
    });

    test('does not delete DB rows when file system deletion fails', () async {
      final service = buildService(throwOnDelete: true);

      await expectLater(
        service.delete('narou_n1', '/lib/narou_n1'),
        throwsA(isA<Exception>()),
      );

      expect(log, isNot(contains('novel')),
          reason: 'metadata MUST be preserved so the folder stays a novel '
              'folder and the delete can be retried');
      expect(log, isNot(contains('summary')));
      expect(log, isNot(contains('factCache')));
      expect(log, isNot(contains('progress')));
    });
  });
}
