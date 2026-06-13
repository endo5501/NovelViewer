import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_database.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry_provider.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);
  @override
  String? build() => _initialValue;
}

/// Records the per-folder DB `close()` and the file-system operation into one
/// shared [log], so a flow that fails to await the close before the file op is
/// observable as out-of-order. `close()` records after an async gap to surface
/// fire-and-forget release.
class _FakeEpisodeCacheDatabase extends EpisodeCacheDatabase {
  _FakeEpisodeCacheDatabase(this.log) : super('unused');
  final List<String> log;
  @override
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    log.add('close:episode');
  }
}

class _FakeTtsAudioDatabase extends TtsAudioDatabase {
  _FakeTtsAudioDatabase(this.log) : super('unused');
  final List<String> log;
  @override
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    log.add('close:audio');
  }
}

class _FakeTtsDictionaryDatabase extends TtsDictionaryDatabase {
  _FakeTtsDictionaryDatabase(this.log) : super('unused');
  final List<String> log;
  @override
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    log.add('close:dict');
  }
}

class _RecordingFileSystemService extends FileSystemService {
  _RecordingFileSystemService(this.log);
  final List<String> log;
  List<String> orgFolderTree = const [];

  @override
  Future<String> moveDirectory(String srcPath, String destParentPath) async {
    log.add('fileop:move');
    return p.join(destParentPath, p.basename(srcPath));
  }

  @override
  Future<DirectoryEntry> renameDirectory(String path_, String newName) async {
    log.add('fileop:rename');
    return DirectoryEntry(name: newName, path: p.join(p.dirname(path_), newName));
  }

  @override
  Future<void> deleteEmptyDirectory(String path) async {
    log.add('fileop:deleteEmpty');
  }

  @override
  Future<List<String>> listOrganizationalFolderTree(
    String libraryPath,
    Set<String> novelFolderNames,
  ) async =>
      orgFolderTree;
}

/// A registry whose handles are the recording fakes, pre-opened for
/// [openFolder] so `closeAll(openFolder)` has something to close (the close is
/// what the order assertion observes).
PerFolderDbRegistry _fakeRegistry(List<String> log, String openFolder) {
  final registry = PerFolderDbRegistry(
    episodeFactory: (_) => _FakeEpisodeCacheDatabase(log),
    audioFactory: (_) => _FakeTtsAudioDatabase(log),
    dictionaryFactory: (_) => _FakeTtsDictionaryDatabase(log),
  );
  registry.episodeCache(openFolder);
  registry.ttsAudio(openFolder);
  registry.ttsDictionary(openFolder);
  return registry;
}

Widget _panel({
  required String currentDir,
  required String libraryPath,
  required FileSystemService fs,
  required List<String> log,
  required PerFolderDbRegistry registry,
  List<NovelMetadata> novels = const [],
  List<DirectoryEntry> subdirectories = const [],
}) {
  return ProviderScope(
    overrides: [
      currentDirectoryProvider
          .overrideWith(() => _TestCurrentDirectoryNotifier(currentDir)),
      libraryPathProvider.overrideWithValue(libraryPath),
      allNovelsProvider.overrideWith((ref) async => novels),
      fileSystemServiceProvider.overrideWithValue(fs),
      directoryContentsProvider.overrideWith((ref) async =>
          DirectoryContents(files: const [], subdirectories: subdirectories)),
      // The registry owns the per-folder handles; the move/rename/delete flows
      // release them via `registry.closeAll(folder)` (awaited) before the file
      // operation. Pre-opened with the recording fakes so the close is visible.
      perFolderDbRegistryProvider.overrideWithValue(registry),
    ],
    child: const MaterialApp(
      locale: Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: FileBrowserPanel()),
    ),
  );
}

NovelMetadata _novel(String folderName, String title) => NovelMetadata(
      siteType: 'narou',
      novelId: folderName.split('_').last,
      title: title,
      url: 'https://example.com/$folderName',
      folderName: folderName,
      episodeCount: 1,
      downloadedAt: DateTime(2024, 1, 1),
    );

void _expectClosesBeforeFileOp(List<String> log, String fileOp) {
  final opIndex = log.indexOf(fileOp);
  expect(opIndex, greaterThanOrEqualTo(0), reason: '$fileOp SHALL be invoked');
  for (final handle in ['close:episode', 'close:audio', 'close:dict']) {
    final closeIndex = log.indexOf(handle);
    expect(closeIndex, greaterThanOrEqualTo(0),
        reason: '$handle SHALL be closed during release');
    expect(closeIndex, lessThan(opIndex),
        reason: '$handle close() MUST complete before $fileOp');
  }
}

void main() {
  testWidgets('move closes all per-folder handles before moveDirectory',
      (tester) async {
    final log = <String>[];
    final fs = _RecordingFileSystemService(log)
      ..orgFolderTree = ['/library/完結済み'];
    await tester.pumpWidget(_panel(
      currentDir: '/library',
      libraryPath: '/library',
      fs: fs,
      log: log,
      registry: _fakeRegistry(log, '/library/narou_n1'),
      novels: [_novel('narou_n1', 'テスト小説')],
      subdirectories: const [
        DirectoryEntry(
            name: 'narou_n1', path: '/library/narou_n1', displayName: 'テスト小説'),
        DirectoryEntry(name: '完結済み', path: '/library/完結済み'),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.text('テスト小説')),
        buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移動'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('完結済み'),
    ));
    await tester.pumpAndSettle();

    _expectClosesBeforeFileOp(log, 'fileop:move');
  });

  testWidgets('rename closes all per-folder handles before renameDirectory',
      (tester) async {
    final log = <String>[];
    final fs = _RecordingFileSystemService(log);
    await tester.pumpWidget(_panel(
      currentDir: '/library',
      libraryPath: '/library',
      fs: fs,
      log: log,
      registry: _fakeRegistry(log, '/library/完結済み'),
      subdirectories: const [
        DirectoryEntry(name: '完結済み', path: '/library/完結済み'),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.text('完結済み')),
        buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('フォルダ名変更'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '完結');
    await tester.pumpAndSettle();
    await tester.tap(find.text('変更'));
    await tester.pumpAndSettle();

    _expectClosesBeforeFileOp(log, 'fileop:rename');
  });

  testWidgets('empty-folder delete closes all per-folder handles before delete',
      (tester) async {
    final log = <String>[];
    final fs = _RecordingFileSystemService(log);
    await tester.pumpWidget(_panel(
      currentDir: '/library',
      libraryPath: '/library',
      fs: fs,
      log: log,
      registry: _fakeRegistry(log, '/library/完結済み'),
      subdirectories: const [
        DirectoryEntry(name: '完結済み', path: '/library/完結済み'),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.text('完結済み')),
        buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('削除'),
    ));
    await tester.pumpAndSettle();

    _expectClosesBeforeFileOp(log, 'fileop:deleteEmpty');
  });
}
