import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/providers/episode_navigation_controller.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_context/providers/reading_context_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the episode swaps the viewers ask for instead of performing them.
class _SpyEpisodeNav extends EpisodeNavigationController {
  _SpyEpisodeNav(super.ref);
  int next = 0;
  int prev = 0;
  @override
  void navigateToNext() => next++;
  @override
  void navigateToPrevious() => prev++;
}

class _StubSelectedFileNotifier extends SelectedFileNotifier {
  _StubSelectedFileNotifier(this._initial);
  final FileEntry? _initial;
  @override
  FileEntry? build() => _initial;
}

class _StubDisplayMode extends DisplayModeNotifier {
  _StubDisplayMode(this._mode);
  final TextDisplayMode _mode;
  @override
  TextDisplayMode build() => _mode;
}

/// Serves the novel folder's episodes, and nothing at the library root.
class _FakeFileSystemService extends FileSystemService {
  @override
  Future<List<FileEntry>> listTextFiles(String directoryPath) async {
    if (directoryPath != _novelDir) return const [];
    return const [_ep1, _ep2, _ep3];
  }

  @override
  Future<List<DirectoryEntry>> listSubdirectories(String _) async => const [];
}

const _novelDir = '/library/narou_n1234ab';
const _ep1 = FileEntry(name: '001-ep1.txt', path: '$_novelDir/001-ep1.txt');
const _ep2 = FileEntry(name: '002-ep2.txt', path: '$_novelDir/002-ep2.txt');
const _ep3 = FileEntry(name: '003-ep3.txt', path: '$_novelDir/003-ep3.txt');

final _novel = NovelMetadata(
  siteType: 'narou',
  novelId: 'n1234ab',
  title: '異世界転生物語',
  url: 'https://ncode.syosetu.com/n1234ab/',
  folderName: 'narou_n1234ab',
  episodeCount: 3,
  downloadedAt: DateTime(2024, 1, 1),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Everything real from the filesystem service up to adjacency, with the
  /// file browser parked at the library root — the reader went looking for
  /// their next novel and came back without choosing.
  ProviderContainer container(TextDisplayMode mode) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        displayModeProvider.overrideWith(() => _StubDisplayMode(mode)),
        libraryPathProvider.overrideWithValue('/library'),
        allNovelsProvider.overrideWith((ref) => [_novel]),
        fileSystemServiceProvider.overrideWithValue(_FakeFileSystemService()),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier('/library'),
        ),
        selectedFileProvider.overrideWith(
          () => _StubSelectedFileNotifier(_ep2),
        ),
        episodeNavigationControllerProvider.overrideWith(
          (ref) => _SpyEpisodeNav(ref),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> prime(ProviderContainer c, WidgetTester tester) async {
    await c.read(readingEpisodesProvider.future);
    await tester.pumpAndSettle();
  }

  Widget wrap(ProviderContainer c, Widget child) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  _SpyEpisodeNav spyOf(ProviderContainer c) =>
      c.read(episodeNavigationControllerProvider) as _SpyEpisodeNav;

  final longContent = List.generate(
    200,
    (i) => 'これは ${i + 1} 行目の内容です。',
  ).join('\n');

  testWidgets(
    '縦書き: ブラウザがライブラリルートでも最終ページで次話プロンプトが出る',
    (tester) async {
      final c = container(TextDisplayMode.vertical);
      await tester.pumpWidget(
        wrap(
          c,
          const SizedBox(width: 100, height: 400, child: _VerticalHost()),
        ),
      );
      await tester.pumpAndSettle();
      await prime(c, tester);

      // Walk to the last page, then ask for one more.
      for (var i = 0; i < 300; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        if (find.textContaining(_ep3.name).evaluate().isNotEmpty) break;
      }

      expect(
        find.textContaining(_ep3.name),
        findsOneWidget,
        reason: '次話が解決できていれば、境界で次話名のプロンプトが出る',
      );
    },
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets('横書き: ブラウザがライブラリルートでも末尾で次話へ遷移する', (tester) async {
    final c = container(TextDisplayMode.horizontal);
    await tester.pumpWidget(
      wrap(
        c,
        SizedBox(
          width: 400,
          height: 200,
          child: TextContentRenderer(content: longContent),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await prime(c, tester);

    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(TextContentRenderer),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();

    // First press arms the boundary hint, the second confirms it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(spyOf(c).next, 0);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(spyOf(c).next, 1, reason: 'ブラウザの現在地に関わらず次話へ進めなければならない');
  });
}

class _VerticalHost extends StatelessWidget {
  const _VerticalHost();

  @override
  Widget build(BuildContext context) => VerticalTextViewer(
    segments: [PlainTextSegment('あ' * 500)],
    baseStyle: const TextStyle(fontSize: 14.0),
  );
}
