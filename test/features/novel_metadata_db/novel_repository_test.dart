import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';

import '../../helpers/novel_metadata_db_fixture.dart';

void main() {
  late NovelDatabase novelDatabase;
  late NovelRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    repository = NovelRepository(novelDatabase);
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  NovelMetadata createMetadata({
    String siteType = 'narou',
    String novelId = 'n1234ab',
    String title = 'テスト小説',
    String url = 'https://ncode.syosetu.com/n1234ab/',
    String folderName = 'narou_n1234ab',
    int episodeCount = 10,
  }) {
    return NovelMetadata(
      siteType: siteType,
      novelId: novelId,
      title: title,
      url: url,
      folderName: folderName,
      episodeCount: episodeCount,
      downloadedAt: DateTime(2026, 1, 1),
    );
  }

  group('upsert', () {
    test('inserts a new novel', () async {
      final metadata = createMetadata();
      await repository.upsert(metadata);

      final all = await repository.findAll();
      expect(all.length, 1);
      expect(all.first.title, 'テスト小説');
      expect(all.first.novelId, 'n1234ab');
      expect(all.first.siteType, 'narou');
    });

    test('updates existing novel with same site type and novel ID', () async {
      await repository.upsert(createMetadata(title: '古いタイトル'));
      await repository.upsert(
        createMetadata(title: '新しいタイトル', episodeCount: 20),
      );

      final all = await repository.findAll();
      expect(all.length, 1);
      expect(all.first.title, '新しいタイトル');
      expect(all.first.episodeCount, 20);
      expect(all.first.updatedAt, isNotNull);
    });
  });

  group('findAll', () {
    test('returns empty list when no novels exist', () async {
      final all = await repository.findAll();
      expect(all, isEmpty);
    });

    test('returns novels ordered by title', () async {
      await repository.upsert(
        createMetadata(
          novelId: 'n0002',
          title: 'Bの小説',
          folderName: 'narou_n0002',
        ),
      );
      await repository.upsert(
        createMetadata(
          novelId: 'n0001',
          title: 'Aの小説',
          folderName: 'narou_n0001',
        ),
      );

      final all = await repository.findAll();
      expect(all.length, 2);
      expect(all[0].title, 'Aの小説');
      expect(all[1].title, 'Bの小説');
    });
  });

  group('findByFolderName', () {
    test('returns novel matching folder name', () async {
      await repository.upsert(createMetadata());

      final found = await repository.findByFolderName('narou_n1234ab');
      expect(found, isNotNull);
      expect(found!.title, 'テスト小説');
    });

    test('returns null for non-existent folder name', () async {
      final found = await repository.findByFolderName('nonexistent');
      expect(found, isNull);
    });
  });

  group('findBySiteAndNovelId', () {
    test('returns novel matching site type and novel ID', () async {
      await repository.upsert(createMetadata());

      final found = await repository.findBySiteAndNovelId('narou', 'n1234ab');
      expect(found, isNotNull);
      expect(found!.title, 'テスト小説');
    });

    test('returns null for non-existent combination', () async {
      await repository.upsert(createMetadata());

      final found = await repository.findBySiteAndNovelId(
        'kakuyomu',
        'n1234ab',
      );
      expect(found, isNull);
    });
  });

  group('deleteByFolderName', () {
    test('deletes novel matching folder name', () async {
      await repository.upsert(createMetadata());

      await repository.deleteByFolderName('narou_n1234ab');

      final all = await repository.findAll();
      expect(all, isEmpty);
    });

    test('does not affect other novels', () async {
      await repository.upsert(createMetadata());
      await repository.upsert(
        createMetadata(
          novelId: 'n5678cd',
          title: '別の小説',
          folderName: 'narou_n5678cd',
        ),
      );

      await repository.deleteByFolderName('narou_n1234ab');

      final all = await repository.findAll();
      expect(all.length, 1);
      expect(all.first.title, '別の小説');
    });

    test('does nothing for non-existent folder name', () async {
      await repository.upsert(createMetadata());

      await repository.deleteByFolderName('nonexistent');

      final all = await repository.findAll();
      expect(all.length, 1);
    });
  });

  group('updateTitle', () {
    test('updates title and updated_at for existing novel', () async {
      await repository.upsert(createMetadata(title: '古いタイトル'));

      await repository.updateTitle('narou_n1234ab', '新しいタイトル');

      final found = await repository.findByFolderName('narou_n1234ab');
      expect(found, isNotNull);
      expect(found!.title, '新しいタイトル');
      expect(found.updatedAt, isNotNull);
    });

    test('does not affect other fields', () async {
      await repository.upsert(
        createMetadata(title: '古いタイトル', episodeCount: 10),
      );

      await repository.updateTitle('narou_n1234ab', '新しいタイトル');

      final found = await repository.findByFolderName('narou_n1234ab');
      expect(found!.episodeCount, 10);
      expect(found.url, 'https://ncode.syosetu.com/n1234ab/');
      expect(found.folderName, 'narou_n1234ab');
    });

    test('throws exception for non-existent folder name', () async {
      expect(
        () => repository.updateTitle('nonexistent', '新しいタイトル'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('recordUpdateCheck', () {
    test('a novel registered by download starts unchecked', () async {
      await repository.upsert(createMetadata());

      final novel = await repository.findByFolderName('narou_n1234ab');
      expect(novel!.latestEpisodeCount, isNull);
      expect(novel.updateCheckedAt, isNull);
    });

    test('stores the observed count and check time only', () async {
      await repository.upsert(createMetadata(episodeCount: 120));
      final before = await repository.findByFolderName('narou_n1234ab');

      await repository.recordUpdateCheck(
        'narou_n1234ab',
        latestEpisodeCount: 125,
        checkedAt: DateTime.utc(2026, 11, 23, 9),
      );

      final after = await repository.findByFolderName('narou_n1234ab');
      expect(after!.latestEpisodeCount, 125);
      expect(after.updateCheckedAt, DateTime.utc(2026, 11, 23, 9));
      expect(after.title, before!.title);
      expect(after.url, before.url);
      expect(after.episodeCount, 120);
      expect(after.downloadedAt, before.downloadedAt);
      expect(after.updatedAt, before.updatedAt);
    });

    test('does not touch other novels', () async {
      await repository.upsert(createMetadata());
      await repository.upsert(
        createMetadata(
          novelId: 'n9999zz',
          url: 'https://ncode.syosetu.com/n9999zz/',
          folderName: 'narou_n9999zz',
        ),
      );

      await repository.recordUpdateCheck(
        'narou_n1234ab',
        latestEpisodeCount: 11,
        checkedAt: DateTime.utc(2026, 11, 23),
      );

      final other = await repository.findByFolderName('narou_n9999zz');
      expect(other!.latestEpisodeCount, isNull);
    });

    test('re-downloading keeps the recorded result', () async {
      await repository.upsert(createMetadata(episodeCount: 120));
      await repository.recordUpdateCheck(
        'narou_n1234ab',
        latestEpisodeCount: 125,
        checkedAt: DateTime.utc(2026, 11, 23),
      );

      await repository.upsert(createMetadata(episodeCount: 125));

      final novel = await repository.findByFolderName('narou_n1234ab');
      expect(novel!.episodeCount, 125);
      expect(novel.latestEpisodeCount, 125);
      expect(novel.updateCheckedAt, DateTime.utc(2026, 11, 23));
    });

    test('a novel deleted meanwhile is skipped without error', () async {
      await repository.recordUpdateCheck(
        'narou_missing',
        latestEpisodeCount: 5,
        checkedAt: DateTime.utc(2026, 11, 23),
      );

      expect(await repository.findAll(), isEmpty);
    });
  });
}
