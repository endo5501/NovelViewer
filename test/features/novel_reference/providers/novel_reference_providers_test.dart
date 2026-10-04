import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_reference/data/novel_reference_repository.dart';
import 'package:novel_viewer/features/novel_reference/providers/novel_reference_providers.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

void main() {
  late NovelDatabase novelDatabase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  test('relations are read afresh once nothing holds the earlier read', () async {
    // A cache that outlived its readers would keep serving a relation to a
    // novel deleted since, and a dialog seeded from it would save it back.
    final container = ProviderContainer(
      overrides: [novelDatabaseProvider.overrideWithValue(novelDatabase)],
    );
    addTearDown(container.dispose);
    final repository = NovelReferenceRepository(novelDatabase);
    await repository.replaceParents('part2', ['part1']);

    final first = await container.read(novelReferenceRelationsProvider.future);
    expect(first, hasLength(1));
    await repository.deleteAllFor('part1');
    await Future<void>.delayed(Duration.zero);

    final second = await container.read(novelReferenceRelationsProvider.future);
    expect(second, isEmpty);
  });

  test('the default locator walks the library asynchronously', () async {
    final library = Directory.systemTemp.createTempSync('locator_provider_');
    addTearDown(() => library.deleteSync(recursive: true));
    final novel = Directory(p.join(library.path, 'shelf', 'narou_n1'))
      ..createSync(recursive: true);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final located = await container.read(novelFolderLocatorProvider)(
      libraryRoot: library.path,
      registeredFolderNames: {'narou_n1'},
    );

    expect(located, {'narou_n1': novel.path});
  });
}
