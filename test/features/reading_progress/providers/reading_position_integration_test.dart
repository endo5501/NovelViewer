import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_position_writer.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_position_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/novel_delete/providers/novel_delete_providers.dart';
import '../../../helpers/novel_metadata_db_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('novel deletion waits for queued selection writes', () async {
    final files = _DeleteRecorder();
    final h = await _harness(files: files);
    addTearDown(h.close);
    final writer = h.container.read(readingPositionWriterProvider);
    final gate = Completer<void>();
    final write = writer.enqueue(() async {
      await gate.future;
      await h.repo.upsert(novelId: 'book', fileName: 'a.txt');
    });
    final service = await h.container.read(novelDeleteServiceProvider.future);
    final deletion = service.delete('book', '${h.root.path}/nested/book');
    await pumpEventQueue();
    expect(files.deleted, isFalse);
    gate.complete();
    await write;
    await deletion;
    expect(files.deleted, isTrue);
    expect(await h.repo.findByNovelId('book'), isNull);
  });

  test(
    'startup opens latest novel at its current nested location once',
    () async {
      final h = await _harness();
      addTearDown(h.close);
      await h.repo.upsert(novelId: 'book', fileName: 'a.txt');
      await h.repo.savePosition(
        novelId: 'book',
        fileName: 'a.txt',
        bodyOffset: 40,
        bodyHash: 'hash',
      );
      await h.container.read(readingProgressStartupProvider.future);
      expect(
        h.container.read(currentDirectoryProvider),
        '${h.root.path}/nested/book',
      );
      expect(h.container.read(selectedFileProvider)!.name, 'a.txt');
      final saved = await h.container.read(
        readingPositionForFileProvider(
          '${h.root.path}/nested/book/a.txt',
        ).future,
      );
      expect(saved!.bodyOffset, 40);
      h.container.read(selectedFileProvider.notifier).clear();
      await h.container.read(readingProgressStartupProvider.future);
      expect(h.container.read(selectedFileProvider), isNull);
    },
  );

  test('missing latest file leaves startup at root', () async {
    final h = await _harness();
    addTearDown(h.close);
    await h.repo.upsert(novelId: 'book', fileName: 'gone.txt');
    await h.container.read(readingProgressStartupProvider.future);
    expect(h.container.read(currentDirectoryProvider), h.root.path);
    expect(h.container.read(selectedFileProvider), isNull);
  });

  test('startup lookup yields to user selection', () async {
    final gate = Completer<List<NovelMetadata>>();
    final h = await _harness(catalog: gate.future);
    addTearDown(h.close);
    await h.repo.upsert(novelId: 'book', fileName: 'a.txt');
    final restore = h.container.read(readingProgressStartupProvider.future);
    h.container
        .read(selectedFileProvider.notifier)
        .selectFile(const FileEntry(name: 'manual.txt', path: '/manual.txt'));
    gate.complete([_novel()]);
    await restore;
    expect(h.container.read(selectedFileProvider)!.name, 'manual.txt');
    expect(h.container.read(currentDirectoryProvider), h.root.path);
  });

  test('switch flushes outgoing position before recording next file', () async {
    final h = await _harness();
    addTearDown(h.close);
    h.container.read(readingProgressAutoSaveListenerProvider);
    h.container
        .read(selectedFileProvider.notifier)
        .selectFile(
          FileEntry(name: 'a.txt', path: '${h.root.path}/nested/book/a.txt'),
        );
    final writer = h.container.read(readingPositionWriterProvider);
    await writer.flush();
    writer.observe(const PositionSnapshot('book', 'a.txt', 40, 'hash'));
    h.container
        .read(selectedFileProvider.notifier)
        .selectFile(
          FileEntry(name: 'b.txt', path: '${h.root.path}/nested/book/b.txt'),
        );
    await writer.flush();
    final row = await h.repo.findByNovelId('book');
    expect(row!.fileName, 'b.txt');
    expect(row.bodyOffset, 0);
  });

  test(
    'background notification flushes without changing badge revision',
    () async {
      final h = await _harness();
      addTearDown(h.close);
      await h.repo.upsert(novelId: 'book', fileName: 'a.txt');
      h.container.read(readingPositionLifecycleProvider);
      final writer = h.container.read(readingPositionWriterProvider);
      writer.observe(const PositionSnapshot('book', 'a.txt', 40, 'hash'));
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await writer.enqueue(() async {});
      expect((await h.repo.findByNovelId('book'))!.bodyOffset, 40);
      expect(h.container.read(readingProgressRevisionProvider), 0);
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
    },
  );

  test('a file other than the saved one resolves to the start', () async {
    // The saved row belongs to a.txt, so opening b.txt must not inherit its
    // offset: the provider hands back a fresh record for b.txt at offset 0.
    final h = await _harness();
    addTearDown(h.close);
    await h.repo.upsert(novelId: 'book', fileName: 'a.txt');
    await h.repo.savePosition(
      novelId: 'book',
      fileName: 'a.txt',
      bodyOffset: 40,
      bodyHash: 'hash',
    );
    final other = await h.container.read(
      readingPositionForFileProvider('${h.root.path}/nested/book/b.txt').future,
    );
    expect(other!.fileName, 'b.txt');
    expect(other.bodyOffset, 0);
    expect(other.bodyHash, isNull);
    // The saved file still resolves to its stored position.
    final saved = await h.container.read(
      readingPositionForFileProvider('${h.root.path}/nested/book/a.txt').future,
    );
    expect(saved!.bodyOffset, 40);
  });

  test('application exit commits pending reading position', () async {
    final h = await _harness();
    addTearDown(h.close);
    await h.repo.upsert(novelId: 'book', fileName: 'a.txt');
    h.container.read(readingPositionLifecycleProvider);
    h.container
        .read(readingPositionWriterProvider)
        .observe(const PositionSnapshot('book', 'a.txt', 80, 'hash'));
    await WidgetsBinding.instance.handleRequestAppExit();
    expect((await h.repo.findByNovelId('book'))!.bodyOffset, 80);
  });
}

NovelMetadata _novel() => NovelMetadata(
  siteType: 'narou',
  novelId: 'book',
  title: 'Book',
  url: 'https://example.com/book',
  folderName: 'book',
  episodeCount: 2,
  downloadedAt: DateTime(2026),
);

Future<
  ({
    ProviderContainer container,
    ReadingProgressRepository repo,
    Directory root,
    Future<void> Function() close,
  })
>
_harness({
  Future<List<NovelMetadata>>? catalog,
  FileSystemService? files,
}) async {
  final root = await Directory.systemTemp.createTemp('reading-integration-');
  await Directory('${root.path}/nested/book').create(recursive: true);
  await File('${root.path}/nested/book/a.txt').writeAsString('body');
  await File('${root.path}/nested/book/b.txt').writeAsString('body');
  final database = await seedNovelDatabaseFixture();
  final repo = ReadingProgressRepository(database);
  final container = ProviderContainer(
    overrides: [
      if (files != null) fileSystemServiceProvider.overrideWithValue(files),
      novelDatabaseProvider.overrideWithValue(database),
      readingProgressRepositoryProvider.overrideWithValue(repo),
      libraryPathProvider.overrideWithValue(root.path),
      currentDirectoryProvider.overrideWith(
        () => CurrentDirectoryNotifier(root.path),
      ),
      allNovelsProvider.overrideWith(
        (ref) => catalog ?? Future.value([_novel()]),
      ),
    ],
  );
  return (
    container: container,
    repo: repo,
    root: root,
    close: () async {
      await container.read(readingPositionWriterProvider).flush();
      container.dispose();
      await database.close();
      await root.delete(recursive: true);
    },
  );
}

class _DeleteRecorder extends FileSystemService {
  bool deleted = false;
  @override
  Future<void> deleteDirectory(String path) async {
    deleted = true;
  }
}
