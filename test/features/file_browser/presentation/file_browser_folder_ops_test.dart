import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_delete/data/novel_delete_service.dart';
import 'package:novel_viewer/features/novel_delete/providers/novel_delete_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_context/providers/reading_context_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);

  @override
  String? build() => _initialValue;
}

/// Records directory operations so flow tests can assert wiring without
/// touching the real filesystem (widget tests run under FakeAsync, which does
/// not drive real disk IO).
class _RecordingFileSystemService extends FileSystemService {
  final List<({String parent, String name})> created = [];
  final List<({String path, String newName})> renamed = [];
  final List<({String src, String dest})> moved = [];
  List<String> orgFolderTree = const [];

  @override
  Future<DirectoryEntry> createDirectory(String parentPath, String name) async {
    created.add((parent: parentPath, name: name));
    return DirectoryEntry(name: name, path: p.join(parentPath, name));
  }

  @override
  Future<DirectoryEntry> renameDirectory(String path_, String newName) async {
    renamed.add((path: path_, newName: newName));
    return DirectoryEntry(
      name: newName,
      path: p.join(p.dirname(path_), newName),
    );
  }

  DirectoryOpError? moveError;

  @override
  Future<String> moveDirectory(String srcPath, String destParentPath) async {
    moved.add((src: srcPath, dest: destParentPath));
    final err = moveError;
    if (err != null) {
      throw DirectoryOpException(err, 'forced');
    }
    return p.join(destParentPath, p.basename(srcPath));
  }

  @override
  Future<List<String>> listOrganizationalFolderTree(
    String libraryPath,
    Set<String> novelFolderNames,
  ) async => orgFolderTree;

  final List<String> deletedEmpty = [];
  DirectoryOpError? deleteError;

  @override
  Future<void> deleteEmptyDirectory(String path) async {
    deletedEmpty.add(path);
    final err = deleteError;
    if (err != null) {
      throw DirectoryOpException(err, 'forced');
    }
  }
}

/// Records the novels it is asked to delete instead of touching disk or DB.
class _RecordingNovelDeleteService extends Fake implements NovelDeleteService {
  final deleted = <String>[];

  @override
  Future<void> delete(String folderName, String folderPath) async =>
      deleted.add(folderName);
}

Widget _panel({
  required String currentDir,
  required String libraryPath,
  required FileSystemService fs,
  List<NovelMetadata> novels = const [],
  List<DirectoryEntry> subdirectories = const [],
  NovelDeleteService? deleteService,
}) {
  return ProviderScope(
    overrides: [
      currentDirectoryProvider.overrideWith(
        () => _TestCurrentDirectoryNotifier(currentDir),
      ),
      libraryPathProvider.overrideWithValue(libraryPath),
      allNovelsProvider.overrideWith((ref) => novels),
      fileSystemServiceProvider.overrideWithValue(fs),
      if (deleteService != null)
        novelDeleteServiceProvider.overrideWith((ref) async => deleteService),
      directoryContentsProvider.overrideWith(
        (ref) async =>
            DirectoryContents(files: const [], subdirectories: subdirectories),
      ),
    ],
    child: const MaterialApp(
      locale: Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: FileBrowserPanel()),
    ),
  );
}

void main() {
  testWidgets('creates a new folder via the toolbar button', (tester) async {
    final fs = _RecordingFileSystemService();
    await tester.pumpWidget(
      _panel(currentDir: '/library', libraryPath: '/library', fs: fs),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.create_new_folder));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '完結済み');
    await tester.pumpAndSettle();

    await tester.tap(find.text('作成'));
    await tester.pumpAndSettle();

    expect(fs.created, hasLength(1));
    expect(fs.created.single.parent, '/library');
    expect(fs.created.single.name, '完結済み');
  });

  NovelMetadata novel(String folderName, String title) => NovelMetadata(
    siteType: 'narou',
    novelId: folderName.split('_').last,
    title: title,
    url: 'https://example.com/$folderName',
    folderName: folderName,
    episodeCount: 1,
    downloadedAt: DateTime(2024, 1, 1),
  );

  testWidgets('organizational folder context menu offers folder rename', (
    tester,
  ) async {
    final fs = _RecordingFileSystemService();
    await tester.pumpWidget(
      _panel(
        currentDir: '/library',
        libraryPath: '/library',
        fs: fs,
        novels: [novel('narou_n1', 'テスト小説')],
        subdirectories: const [
          DirectoryEntry(name: '完結済み', path: '/library/完結済み'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('完結済み')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();

    // Organizational folders rename the real directory, not a DB title.
    expect(find.text('フォルダ名変更'), findsOneWidget);
    expect(find.text('タイトル変更'), findsNothing);

    await tester.tap(find.text('フォルダ名変更'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '完結');
    await tester.pumpAndSettle();
    await tester.tap(find.text('変更'));
    await tester.pumpAndSettle();

    expect(fs.renamed, hasLength(1));
    expect(fs.renamed.single.path, '/library/完結済み');
    expect(fs.renamed.single.newName, '完結');
  });

  testWidgets('novel folder context menu offers title rename (not folder)', (
    tester,
  ) async {
    final fs = _RecordingFileSystemService();
    await tester.pumpWidget(
      _panel(
        currentDir: '/library',
        libraryPath: '/library',
        fs: fs,
        novels: [novel('narou_n1', 'テスト小説')],
        subdirectories: const [
          DirectoryEntry(
            name: 'narou_n1',
            path: '/library/narou_n1',
            displayName: 'テスト小説',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('テスト小説')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('タイトル変更'), findsOneWidget);
    expect(find.text('フォルダ名変更'), findsNothing);
    expect(find.text('更新'), findsOneWidget);
    expect(find.text('移動'), findsOneWidget);
  });

  testWidgets(
    'moving a novel folder calls moveDirectory with the chosen dest',
    (tester) async {
      final fs = _RecordingFileSystemService();
      fs.orgFolderTree = ['/library/完結済み'];
      await tester.pumpWidget(
        _panel(
          currentDir: '/library',
          libraryPath: '/library',
          fs: fs,
          novels: [novel('narou_n1', 'テスト小説')],
          subdirectories: const [
            DirectoryEntry(
              name: 'narou_n1',
              path: '/library/narou_n1',
              displayName: 'テスト小説',
            ),
            DirectoryEntry(name: '完結済み', path: '/library/完結済み'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(
        tester.getCenter(find.text('テスト小説')),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('移動'));
      await tester.pumpAndSettle();

      // Destination dialog lists the organizational folder; pick it (scoped to
      // the dialog since the same name also appears in the file list).
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('完結済み'),
        ),
      );
      await tester.pumpAndSettle();

      expect(fs.moved, hasLength(1));
      expect(fs.moved.single.src, '/library/narou_n1');
      expect(fs.moved.single.dest, '/library/完結済み');
    },
  );

  testWidgets('moving a novel folder follows the open episode to it', (
    tester,
  ) async {
    // The refresh target is resolved from the path of the file on screen, so a
    // selection left pointing at where the novel used to be would send the
    // next update back to the old location and duplicate the folder there.
    final fs = _RecordingFileSystemService();
    fs.orgFolderTree = ['/library/完結済み'];
    await tester.pumpWidget(
      _panel(
        currentDir: '/library',
        libraryPath: '/library',
        fs: fs,
        novels: [novel('narou_n1', 'テスト小説')],
        subdirectories: const [
          DirectoryEntry(
            name: 'narou_n1',
            path: '/library/narou_n1',
            displayName: 'テスト小説',
          ),
          DirectoryEntry(name: '完結済み', path: '/library/完結済み'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FileBrowserPanel)),
    );
    container
        .read(selectedFileProvider.notifier)
        .selectFile(
          const FileEntry(name: '0001.txt', path: '/library/narou_n1/0001.txt'),
        );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('テスト小説')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('移動'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('完結済み'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(selectedFileProvider)?.path,
      p.join('/library/完結済み', 'narou_n1', '0001.txt'),
    );
  });

  testWidgets('renaming a folder follows the open episode into it', (
    tester,
  ) async {
    // The reading context resolves from the open file's path, so a selection
    // left at the old name would list a folder that no longer exists.
    final fs = _RecordingFileSystemService();
    await tester.pumpWidget(
      _panel(
        currentDir: '/library',
        libraryPath: '/library',
        fs: fs,
        subdirectories: const [
          DirectoryEntry(name: '連載中', path: '/library/連載中'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FileBrowserPanel)),
    );
    container
        .read(selectedFileProvider.notifier)
        .selectFile(
          const FileEntry(
            name: '0001.txt',
            path: '/library/連載中/narou_n1/0001.txt',
          ),
        );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('連載中')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('フォルダ名変更'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '完結済み');
    await tester.pumpAndSettle();
    await tester.tap(find.text('変更'));
    await tester.pumpAndSettle();

    expect(
      container.read(selectedFileProvider)?.path,
      p.join('/library', '完結済み', 'narou_n1', '0001.txt'),
    );
  });

  testWidgets('moving an unrelated folder leaves the open episode alone', (
    tester,
  ) async {
    final fs = _RecordingFileSystemService();
    fs.orgFolderTree = ['/library/完結済み'];
    await tester.pumpWidget(
      _panel(
        currentDir: '/library',
        libraryPath: '/library',
        fs: fs,
        novels: [novel('narou_n1', 'テスト小説'), novel('narou_n2', '別の小説')],
        subdirectories: const [
          DirectoryEntry(
            name: 'narou_n2',
            path: '/library/narou_n2',
            displayName: '別の小説',
          ),
          DirectoryEntry(name: '完結済み', path: '/library/完結済み'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FileBrowserPanel)),
    );
    container
        .read(selectedFileProvider.notifier)
        .selectFile(
          const FileEntry(name: '0001.txt', path: '/library/narou_n1/0001.txt'),
        );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('別の小説')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('移動'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('完結済み'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(selectedFileProvider)?.path,
      '/library/narou_n1/0001.txt',
    );
  });

  testWidgets('move name collision shows an error message', (tester) async {
    final fs = _RecordingFileSystemService();
    fs.orgFolderTree = ['/library/完結済み'];
    fs.moveError = DirectoryOpError.nameCollision;
    await tester.pumpWidget(
      _panel(
        currentDir: '/library',
        libraryPath: '/library',
        fs: fs,
        novels: [novel('narou_n1', 'テスト小説')],
        subdirectories: const [
          DirectoryEntry(
            name: 'narou_n1',
            path: '/library/narou_n1',
            displayName: 'テスト小説',
          ),
          DirectoryEntry(name: '完結済み', path: '/library/完結済み'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('テスト小説')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('移動'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('完結済み'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('同名のフォルダが既に存在します'), findsOneWidget);
  });

  testWidgets('deleting an empty organizational folder calls deleteEmpty', (
    tester,
  ) async {
    final fs = _RecordingFileSystemService();
    await tester.pumpWidget(
      _panel(
        currentDir: '/library',
        libraryPath: '/library',
        fs: fs,
        subdirectories: const [
          DirectoryEntry(name: '完結済み', path: '/library/完結済み'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('完結済み')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    // Confirm in the dialog.
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('削除')),
    );
    await tester.pumpAndSettle();

    expect(fs.deletedEmpty, ['/library/完結済み']);
  });

  testWidgets('a folder operation reloads both listings', (tester) async {
    // The reader's listing and the browser's are separate providers over the
    // same directories, so a folder operation has to reload both — otherwise
    // the reader pages through a tree that no longer exists.
    final fs = _RecordingFileSystemService();
    var browserBuilds = 0;
    var readingBuilds = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDirectoryProvider.overrideWith(
            () => _TestCurrentDirectoryNotifier('/library'),
          ),
          libraryPathProvider.overrideWithValue('/library'),
          allNovelsProvider.overrideWith((ref) => const <NovelMetadata>[]),
          fileSystemServiceProvider.overrideWithValue(fs),
          directoryContentsProvider.overrideWith((ref) async {
            browserBuilds++;
            return DirectoryContents.empty();
          }),
          readingEpisodesProvider.overrideWith((ref) async {
            readingBuilds++;
            return const <FileEntry>[];
          }),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                // Something has to be listening for an invalidation to
                // recompute anything.
                _ListingWatcher(),
                Expanded(child: FileBrowserPanel()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = (browserBuilds, readingBuilds);

    await tester.tap(find.byIcon(Icons.create_new_folder));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '完結済み');
    await tester.pumpAndSettle();
    await tester.tap(find.text('作成'));
    await tester.pumpAndSettle();

    expect(fs.created, hasLength(1));
    expect(browserBuilds, greaterThan(before.$1));
    expect(readingBuilds, greaterThan(before.$2));
  });

  testWidgets('deleting the novel holding the open episode clears it', (
    tester,
  ) async {
    // Unlike a move or a rename, a delete leaves nothing to read, so the
    // selection goes rather than following. (An organisational folder cannot
    // reach this state: it must be empty to be deleted at all.)
    final fs = _RecordingFileSystemService();
    final deleteService = _RecordingNovelDeleteService();
    await tester.pumpWidget(
      _panel(
        currentDir: '/library',
        libraryPath: '/library',
        fs: fs,
        novels: [novel('narou_n1', 'テスト小説')],
        subdirectories: const [
          DirectoryEntry(
            name: 'narou_n1',
            path: '/library/narou_n1',
            displayName: 'テスト小説',
          ),
        ],
        deleteService: deleteService,
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FileBrowserPanel)),
    );
    container
        .read(selectedFileProvider.notifier)
        .selectFile(
          const FileEntry(name: '0001.txt', path: '/library/narou_n1/0001.txt'),
        );
    await tester.pumpAndSettle();
    expect(
      container.read(readingNovelFolderProvider),
      p.join('/library', 'narou_n1'),
    );

    await tester.tapAt(
      tester.getCenter(find.text('テスト小説')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('削除')),
    );
    await tester.pumpAndSettle();

    expect(deleteService.deleted, ['narou_n1']);
    expect(container.read(selectedFileProvider), isNull);
    expect(container.read(readingNovelFolderProvider), isNull);
  });

  testWidgets('deleting a non-empty folder shows the not-empty error', (
    tester,
  ) async {
    final fs = _RecordingFileSystemService();
    fs.deleteError = DirectoryOpError.notEmpty;
    await tester.pumpWidget(
      _panel(
        currentDir: '/library',
        libraryPath: '/library',
        fs: fs,
        subdirectories: const [
          DirectoryEntry(name: '完結済み', path: '/library/完結済み'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('完結済み')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('削除')),
    );
    await tester.pumpAndSettle();

    expect(find.text('フォルダが空ではないため削除できません'), findsOneWidget);
  });
}

class _ListingWatcher extends ConsumerWidget {
  const _ListingWatcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(directoryContentsProvider);
    ref.watch(readingEpisodesProvider);
    return const SizedBox.shrink();
  }
}
