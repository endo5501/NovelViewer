import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';

void main() {
  late NovelDatabase novelDatabase;
  late NovelRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = NovelDatabase();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE novels (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              site_type TEXT NOT NULL,
              novel_id TEXT NOT NULL,
              title TEXT NOT NULL,
              url TEXT NOT NULL,
              folder_name TEXT NOT NULL UNIQUE,
              episode_count INTEGER NOT NULL DEFAULT 0,
              downloaded_at TEXT NOT NULL,
              updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX idx_novels_site_novel
            ON novels(site_type, novel_id)
          ''');
        },
      ),
    );
    novelDatabase.setDatabase(db);
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
      await repository.upsert(createMetadata(title: '新しいタイトル', episodeCount: 20));

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
      await repository.upsert(createMetadata(
        novelId: 'n0002',
        title: 'Bの小説',
        folderName: 'narou_n0002',
      ));
      await repository.upsert(createMetadata(
        novelId: 'n0001',
        title: 'Aの小説',
        folderName: 'narou_n0001',
      ));

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

      final found = await repository.findBySiteAndNovelId('kakuyomu', 'n1234ab');
      expect(found, isNull);
    });
  });
}
