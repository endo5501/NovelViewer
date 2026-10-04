import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_reference/data/novel_reference_repository.dart';
import 'package:novel_viewer/features/novel_reference/domain/reference_graph.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

ReferenceRelation _r(String child, String parent) =>
    ReferenceRelation(child: child, parent: parent);

void main() {
  late NovelDatabase novelDatabase;
  late NovelReferenceRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    repository = NovelReferenceRepository(novelDatabase);
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  group('replaceParents', () {
    test('stores several reference sources for one novel', () async {
      await repository.replaceParents('part3', ['part2', 'wiki']);

      expect((await repository.findAll()).toSet(), {
        _r('part3', 'part2'),
        _r('part3', 'wiki'),
      });
    });

    test('replaces the previous set rather than adding to it', () async {
      await repository.replaceParents('part3', ['part2', 'wiki']);
      await repository.replaceParents('part3', ['part1']);

      expect((await repository.findAll()).toSet(), {_r('part3', 'part1')});
    });

    test('leaves other novels\' relations untouched', () async {
      await repository.replaceParents('gaiden', ['part1']);
      await repository.replaceParents('part3', ['part2']);
      await repository.replaceParents('part3', const []);

      expect((await repository.findAll()).toSet(), {_r('gaiden', 'part1')});
    });

    test('stores a repeated parent once', () async {
      await repository.replaceParents('part3', ['part2', 'part2']);

      expect(await repository.findAll(), [_r('part3', 'part2')]);
    });

    test('rejects a self reference and keeps the previous set', () async {
      await repository.replaceParents('a', ['b']);

      await expectLater(
        repository.replaceParents('a', ['a']),
        throwsA(isA<ReferenceCycleException>()),
      );
      expect(await repository.findAll(), [_r('a', 'b')]);
    });

    test('rejects a relation that closes a loop and rolls back', () async {
      await repository.replaceParents('b', ['a']);
      await repository.replaceParents('a', ['wiki']);

      await expectLater(
        repository.replaceParents('a', ['b']),
        throwsA(isA<ReferenceCycleException>()),
      );
      expect((await repository.findAll()).toSet(), {
        _r('b', 'a'),
        _r('a', 'wiki'),
      });
    });
  });

  group('deleteAllFor', () {
    test('removes relations on both the child and the parent side', () async {
      await repository.replaceParents('part2', ['part1']);
      await repository.replaceParents('part1', ['wiki']);
      await repository.replaceParents('gaiden', ['other']);

      await repository.deleteAllFor('part1');

      expect(await repository.findAll(), [_r('gaiden', 'other')]);
    });

    test('joins a caller transaction', () async {
      await repository.replaceParents('part2', ['part1']);
      final db = await novelDatabase.database;

      await expectLater(
        db.transaction((txn) async {
          await repository.deleteAllFor('part1', txn: txn);
          throw StateError('abort');
        }),
        throwsStateError,
      );
      expect(await repository.findAll(), [_r('part2', 'part1')]);
    });
  });
}
