import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/novel_delete/data/novel_delete_service.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_reference/data/novel_reference_repository.dart';
import 'package:novel_viewer/features/novel_reference/domain/reference_graph.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

class _ThrowingReadingProgressRepository extends ReadingProgressRepository {
  _ThrowingReadingProgressRepository(super.novelDatabase);

  @override
  Future<void> deleteByNovelId(String novelId, {DatabaseExecutor? txn}) async {
    throw Exception('reading_progress delete failed');
  }
}

class _LockedFileSystemService extends FileSystemService {
  @override
  Future<void> deleteDirectory(String path) async {
    throw const FileSystemException('locked');
  }
}

ReferenceRelation _r(String child, String parent) =>
    ReferenceRelation(child: child, parent: parent);

void main() {
  late NovelDatabase novelDatabase;
  late NovelReferenceRepository references;
  late Directory tempDir;
  late Directory part1Dir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    references = NovelReferenceRepository(novelDatabase);
    await references.replaceParents('part2', ['part1']);
    await references.replaceParents('part1', ['wiki']);
    await references.replaceParents('gaiden', ['other']);
    tempDir = Directory.systemTemp.createTempSync('delete_refs_');
    part1Dir = Directory('${tempDir.path}/part1')..createSync();
  });

  tearDown(() async {
    await novelDatabase.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  NovelDeleteService service({
    ReadingProgressRepository? progress,
    FileSystemService? fs,
  }) => NovelDeleteService(
    novelDatabase: novelDatabase,
    novelRepository: NovelRepository(novelDatabase),
    readingProgressRepository:
        progress ?? ReadingProgressRepository(novelDatabase),
    novelReferenceRepository: references,
    fileSystemService: fs ?? FileSystemService(),
  );

  test('deleting a novel removes its relations on both sides', () async {
    await service().delete('part1', part1Dir.path);

    expect(await references.findAll(), [_r('gaiden', 'other')]);
  });

  test('a failed transaction leaves the relations in place', () async {
    await expectLater(
      service(
        progress: _ThrowingReadingProgressRepository(novelDatabase),
      ).delete('part1', part1Dir.path),
      throwsA(isA<Exception>()),
    );

    expect((await references.findAll()).toSet(), {
      _r('part2', 'part1'),
      _r('part1', 'wiki'),
      _r('gaiden', 'other'),
    });
  });

  test('a failed folder deletion leaves the relations in place', () async {
    await expectLater(
      service(fs: _LockedFileSystemService()).delete('part1', part1Dir.path),
      throwsA(isA<FileSystemException>()),
    );

    expect(await references.findAll(), hasLength(3));
  });
}
