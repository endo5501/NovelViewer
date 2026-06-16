import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/file_browser/domain/reading_progress_badge.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

NovelMetadata _novel({
  required String folderName,
  required int episodeCount,
}) {
  return NovelMetadata(
    siteType: 'narou',
    novelId: folderName,
    title: 'title-$folderName',
    url: 'https://example.com/$folderName',
    folderName: folderName,
    episodeCount: episodeCount,
    downloadedAt: DateTime(2026, 1, 1),
  );
}

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

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        novelDatabaseProvider.overrideWithValue(novelDatabase),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('combines episode_count and reading_progress per registered novel',
      () async {
    final novelRepo = NovelRepository(novelDatabase);
    await novelRepo.upsert(_novel(folderName: 'narou_n1234ab', episodeCount: 120));
    await novelRepo.upsert(_novel(folderName: 'kakuyomu_1689', episodeCount: 80));

    final progressRepo = ReadingProgressRepository(novelDatabase);
    await progressRepo.upsert(
      novelId: 'narou_n1234ab',
      fileName: '003_chapter3.txt',
    );

    final container = makeContainer();
    final badges =
        await container.read(readingProgressBadgesProvider.future);

    // Reading-in-progress novel.
    expect(badges['narou_n1234ab']!.read, 3);
    expect(badges['narou_n1234ab']!.total, 120);

    // Unread novel: 0 / N from episode_count.
    expect(badges['kakuyomu_1689']!.read, 0);
    expect(badges['kakuyomu_1689']!.total, 80);
  });

  test('does not include folders that are not registered novels', () async {
    final novelRepo = NovelRepository(novelDatabase);
    await novelRepo.upsert(_novel(folderName: 'narou_n1234ab', episodeCount: 10));

    final container = makeContainer();
    final badges =
        await container.read(readingProgressBadgesProvider.future);

    expect(badges.containsKey('narou_n1234ab'), isTrue);
    expect(badges.containsKey('manual_folder'), isFalse);
  });

  test('degrades to unread and logs WARNING when bulk read fails', () async {
    final novelRepo = NovelRepository(novelDatabase);
    await novelRepo.upsert(_novel(folderName: 'narou_n1234ab', episodeCount: 50));

    // Break the reading_progress read path so findAll throws.
    final db = await novelDatabase.database;
    await db.execute('DROP TABLE reading_progress');

    final records = <LogRecord>[];
    final sub = Logger('reading_progress').onRecord.listen(records.add);
    addTearDown(sub.cancel);

    final container = makeContainer();
    final badges =
        await container.read(readingProgressBadgesProvider.future);

    // Still renders totals; progress degrades to 0 (unread).
    expect(badges['narou_n1234ab']!.read, 0);
    expect(badges['narou_n1234ab']!.total, 50);
    expect(
      records.where((r) => r.level == Level.WARNING),
      isNotEmpty,
      reason: 'bulk read failure must be logged at WARNING',
    );
  });

  test('recomputes when the reading-progress revision is bumped', () async {
    final novelRepo = NovelRepository(novelDatabase);
    await novelRepo.upsert(_novel(folderName: 'narou_n1234ab', episodeCount: 120));

    final progressRepo = ReadingProgressRepository(novelDatabase);

    final container = makeContainer();

    // Initially unread.
    final before =
        await container.read(readingProgressBadgesProvider.future);
    expect(before['narou_n1234ab']!.read, 0);

    // Simulate the user advancing inside the novel: progress is saved and the
    // revision is bumped (what the auto-save listener does).
    await progressRepo.upsert(
      novelId: 'narou_n1234ab',
      fileName: '005_chapter5.txt',
    );
    container.read(readingProgressRevisionProvider.notifier).bump();

    final after =
        await container.read(readingProgressBadgesProvider.future);
    expect(after['narou_n1234ab']!.read, 5);
  });

  test('returns badge values usable by the UI (ReadingProgressBadge)',
      () async {
    final novelRepo = NovelRepository(novelDatabase);
    await novelRepo.upsert(_novel(folderName: 'narou_n1234ab', episodeCount: 120));

    final container = makeContainer();
    final badges =
        await container.read(readingProgressBadgesProvider.future);

    expect(badges['narou_n1234ab'], isA<ReadingProgressBadge>());
  });
}
