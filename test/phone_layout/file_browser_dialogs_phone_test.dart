import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/app/selected_file_progress_title_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_reference/domain/reference_graph.dart';
import 'package:novel_viewer/features/novel_reference/presentation/reference_sources_dialog.dart';
import 'package:novel_viewer/features/novel_reference/providers/novel_reference_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/phone_display.dart';

/// The dialogs the file browser and the library actions present, on the
/// portrait display of an iPhone 16 (spec adaptive-shell-layout, "Every dialog
/// fits a portrait phone").

/// The height of the iPhone 16 software keyboard with its predictive bar, in
/// logical pixels, as the view insets report it.
const double _phoneKeyboardHeight = 336;

const _novelTitle =
    '転生したら辺境の村の薬師だったので、のんびり暮らしたいと思います'
    '〜追放された元宮廷魔術師は今日も薬草を摘む〜';
const _novelFolder = 'narou_n1234ab';
const _orgFolderName = '完結済み・お気に入り・あとで読み返したい長編ファンタジー作品集';

const _novelDir = DirectoryEntry(
  name: _novelFolder,
  path: '/library/$_novelFolder',
  displayName: _novelTitle,
);
const _orgDir = DirectoryEntry(
  name: _orgFolderName,
  path: '/library/$_orgFolderName',
);

NovelMetadata _novel(
  String folderName,
  String title, {
  String site = 'narou',
}) => NovelMetadata(
  siteType: site,
  novelId: folderName,
  title: title,
  url: 'https://ncode.syosetu.com/$folderName/',
  folderName: folderName,
  episodeCount: 120,
  downloadedAt: DateTime(2024, 1, 1),
);

/// Asserts [finder] is laid out wholly inside the part of the display the
/// reader can see and touch: inside the screen, below the status bar and above
/// the home indicator (or the keyboard, when [bottomObscured] says so).
void expectReachable(
  WidgetTester tester,
  Finder finder, {
  double bottomObscured = kPhoneBottomInset,
}) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  final visible = Rect.fromLTRB(
    0,
    kPhoneTopInset,
    kPhoneDisplaySize.width,
    kPhoneDisplaySize.height - bottomObscured,
  );
  expect(
    rect.left >= visible.left - 0.01 &&
        rect.top >= visible.top - 0.01 &&
        rect.right <= visible.right + 0.01 &&
        rect.bottom <= visible.bottom + 0.01,
    isTrue,
    reason: '$finder at $rect is outside the visible area $visible',
  );
}

/// Raises the software keyboard: it covers the bottom of the view, and the
/// home-indicator inset is folded into it, as iOS reports while it is up.
void showPhoneKeyboard(WidgetTester tester) {
  const ratio = 3.0;
  tester.view.viewInsets = const FakeViewPadding(
    bottom: _phoneKeyboardHeight * ratio,
  );
  tester.view.padding = const FakeViewPadding(top: kPhoneTopInset * ratio);
}

/// Asserts every paragraph under [finder] is shown whole: a dialog whose
/// content is not scrollable hands a [Text] less height than it needs and the
/// rest is clipped without any overflow being reported.
void expectShownWhole(WidgetTester tester, Finder finder) {
  final paragraphs = find.descendant(
    of: finder,
    matching: find.byType(RichText),
    matchRoot: true,
  );
  expect(paragraphs, findsWidgets);
  for (final element in paragraphs.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final needed = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
    expect(
      paragraph.size.height + 0.5 >= needed,
      isTrue,
      reason:
          'text is cut off: given ${paragraph.size.height}px of the '
          '${needed}px it needs',
    );
  }
}

Finder _dialogButton(String label) => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  ),
);

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);

  @override
  String? build() => _initialValue;
}

class _FakeFileSystemService extends FileSystemService {
  _FakeFileSystemService(this.orgTree);

  final List<String> orgTree;

  @override
  Future<List<String>> listOrganizationalFolderTree(
    String libraryPath,
    Set<String> novelFolderNames,
  ) async => orgTree;
}

/// Starts nothing: the test drives the refresh's progress itself.
class _ControlledDownloadNotifier extends DownloadNotifier {
  @override
  Future<void> refreshNovel(
    String folderName, {
    required String parentPath,
  }) async {
    state = const DownloadState(status: DownloadStatus.downloading);
  }

  @override
  void cancel() {}

  void emit(DownloadState next) => state = next;
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ja'));
  });

  /// Mounts the file browser full width at the library root, the way the
  /// phone's drawer shows it.
  Future<void> pumpPanel(
    WidgetTester tester, {
    List<DirectoryEntry> subdirectories = const [_novelDir, _orgDir],
    List<NovelMetadata>? novels,
    List<Override> overrides = const [],
  }) async {
    usePhoneDisplay(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          directoryContentsProvider.overrideWith(
            (ref) async => DirectoryContents(
              files: const [],
              subdirectories: subdirectories,
            ),
          ),
          currentDirectoryProvider.overrideWith(
            () => _TestCurrentDirectoryNotifier('/library'),
          ),
          libraryPathProvider.overrideWithValue('/library'),
          allNovelsProvider.overrideWith(
            (ref) => novels ?? [_novel(_novelFolder, _novelTitle)],
          ),
          ...overrides,
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SafeArea(child: FileBrowserPanel())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Long-presses the tile titled [tileText], as a finger on the phone does,
  /// and picks [menuItem] from the context menu.
  Future<void> openFromMenu(
    WidgetTester tester,
    String tileText,
    String menuItem,
  ) async {
    await tester.longPress(find.text(tileText));
    await tester.pumpAndSettle();
    await tester.tap(find.text(menuItem).last);
    await tester.pumpAndSettle();
  }

  group('file browser panel dialogs', () {
    testWidgets('the delete-novel confirmation fits', (tester) async {
      await pumpPanel(tester);
      await openFromMenu(tester, _novelTitle, l10n.fileBrowser_deleteMenuItem);

      expect(find.byType(AlertDialog), findsOneWidget);
      expectReachable(tester, _dialogButton(l10n.common_cancelButton));
      expectReachable(tester, _dialogButton(l10n.common_deleteButton));
      expectShownWhole(tester, find.byType(AlertDialog));
    });

    testWidgets('the delete-folder confirmation fits', (tester) async {
      await pumpPanel(tester);
      await openFromMenu(
        tester,
        _orgFolderName,
        l10n.fileBrowser_deleteMenuItem,
      );

      expect(find.byType(AlertDialog), findsOneWidget);
      expectReachable(tester, _dialogButton(l10n.common_cancelButton));
      expectReachable(tester, _dialogButton(l10n.common_deleteButton));
      expectShownWhole(tester, find.byType(AlertDialog));
    });

    testWidgets('the rename-title dialog fits', (tester) async {
      await pumpPanel(tester);
      await openFromMenu(tester, _novelTitle, l10n.fileBrowser_renameMenuItem);

      expect(find.byType(TextField), findsOneWidget);
      expectReachable(tester, _dialogButton(l10n.common_cancelButton));
      expectReachable(tester, _dialogButton(l10n.renameTitle_changeButton));
    });

    testWidgets('the rename-title dialog keeps its actions above the '
        'keyboard', (tester) async {
      await pumpPanel(tester);
      await openFromMenu(tester, _novelTitle, l10n.fileBrowser_renameMenuItem);
      showPhoneKeyboard(tester);
      await tester.pumpAndSettle();

      expectReachable(
        tester,
        find.byType(TextField),
        bottomObscured: _phoneKeyboardHeight,
      );
      expectReachable(
        tester,
        _dialogButton(l10n.renameTitle_changeButton),
        bottomObscured: _phoneKeyboardHeight,
      );
    });

    testWidgets('the rename-folder dialog fits', (tester) async {
      await pumpPanel(tester);
      await openFromMenu(
        tester,
        _orgFolderName,
        l10n.fileBrowser_renameFolderMenuItem,
      );

      expect(find.text(l10n.fileBrowser_renameFolderTitle), findsOneWidget);
      expectReachable(tester, _dialogButton(l10n.common_cancelButton));
      expectReachable(tester, _dialogButton(l10n.common_changeButton));
    });

    testWidgets('the rename-folder dialog keeps its actions above the '
        'keyboard', (tester) async {
      await pumpPanel(tester);
      await openFromMenu(
        tester,
        _orgFolderName,
        l10n.fileBrowser_renameFolderMenuItem,
      );
      showPhoneKeyboard(tester);
      await tester.pumpAndSettle();

      expectReachable(
        tester,
        _dialogButton(l10n.common_changeButton),
        bottomObscured: _phoneKeyboardHeight,
      );
    });

    testWidgets('the new-folder dialog fits', (tester) async {
      await pumpPanel(tester);
      await tester.tap(find.byKey(const Key('file_browser_new_folder_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), _orgFolderName);
      await tester.pumpAndSettle();

      expect(find.text(l10n.fileBrowser_newFolderTitle), findsOneWidget);
      expectReachable(tester, _dialogButton(l10n.common_cancelButton));
      expectReachable(tester, _dialogButton(l10n.fileBrowser_createButton));
    });

    testWidgets('the new-folder dialog keeps its actions above the keyboard', (
      tester,
    ) async {
      await pumpPanel(tester);
      await tester.tap(find.byKey(const Key('file_browser_new_folder_button')));
      await tester.pumpAndSettle();
      showPhoneKeyboard(tester);
      await tester.pumpAndSettle();

      expectReachable(
        tester,
        _dialogButton(l10n.fileBrowser_createButton),
        bottomObscured: _phoneKeyboardHeight,
      );
    });

    testWidgets('the move dialog fits a deep tree of long folder names', (
      tester,
    ) async {
      final tree = <String>[];
      var path = '/library';
      for (final name in [
        _orgFolderName,
        '異世界転生・チート・成り上がり系（書籍化済み）',
        '2024年に読了した作品とその続編の置き場所',
        '作者別：月見里ゆうひ先生の作品一覧',
        '未分類・あとで整理する予定のもの',
      ]) {
        path = '$path/$name';
        tree.add(path);
      }
      for (var i = 0; i < 20; i++) {
        tree.add('/library/ジャンル別の整理用フォルダその${i + 1}（長い名前のテスト）');
      }

      await pumpPanel(
        tester,
        overrides: [
          fileSystemServiceProvider.overrideWithValue(
            _FakeFileSystemService(tree),
          ),
        ],
      );
      await openFromMenu(tester, _novelTitle, l10n.fileBrowser_moveMenuItem);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.fileBrowser_moveLibraryRoot), findsOneWidget);
      expectReachable(tester, _dialogButton(l10n.common_cancelButton));
    });

    group('reference sources', () {
      const parents = [
        ('part1', '転生したら辺境の村の薬師だったので、のんびり暮らしたいと思います 第一部「旅立ちの章」'),
        ('part2', '転生したら辺境の村の薬師だったので、のんびり暮らしたいと思います 第二部「王都動乱の章」'),
        ('wiki', '辺境の薬師 設定資料集・用語辞典・登場人物一覧（ファンWiki収録記事）'),
      ];
      const grandparent = ('prequel', '前日譚：宮廷魔術師エルヴィンが追放されるまでの物語');
      const children = [
        ('gaiden', '外伝：薬師見習いリーナの一日〜辺境の村の小さな事件簿〜'),
        ('sequel', '続編：辺境の薬師、ついに王国筆頭薬師に任命される'),
      ];

      List<NovelMetadata> novels() => [
        _novel(_novelFolder, _novelTitle),
        for (final (folder, title) in [...parents, grandparent, ...children])
          _novel(folder, title, site: folder == 'wiki' ? 'web' : 'narou'),
        for (var i = 0; i < 15; i++)
          _novel('other$i', '別作品その${i + 1}：悪役令嬢に転生したけど破滅フラグを全力で回避します'),
      ];

      final relations = [
        for (final (folder, _) in parents)
          ReferenceRelation(child: _novelFolder, parent: folder),
        ReferenceRelation(child: 'part1', parent: grandparent.$1),
        for (final (folder, _) in children)
          ReferenceRelation(child: folder, parent: _novelFolder),
      ];

      Future<void> openReferenceSources(WidgetTester tester) async {
        await pumpPanel(
          tester,
          novels: novels(),
          overrides: [
            llmSummarySupportedProvider.overrideWithValue(true),
            novelReferenceRelationsProvider.overrideWith(
              (ref) async => relations,
            ),
          ],
        );
        await openFromMenu(
          tester,
          _novelTitle,
          l10n.fileBrowser_referenceSourcesMenuItem,
        );
      }

      testWidgets('the reference-sources dialog fits', (tester) async {
        await openReferenceSources(tester);

        expect(find.byType(ReferenceSourcesDialog), findsOneWidget);
        expectReachable(tester, _dialogButton(l10n.common_cancelButton));
        expectReachable(tester, _dialogButton(l10n.common_saveButton));
      });

      testWidgets('the reference-source picker fits', (tester) async {
        await openReferenceSources(tester);
        await tester.tap(find.text(l10n.referenceSources_addButton));
        await tester.pumpAndSettle();

        expect(find.byType(ReferenceSourcePickerDialog), findsOneWidget);
        final cancel = find.descendant(
          of: find.byType(ReferenceSourcePickerDialog),
          matching: find.widgetWithText(TextButton, l10n.common_cancelButton),
        );
        expectReachable(tester, cancel);
      });

      testWidgets('the reference-source picker keeps its search field and '
          'actions above the keyboard', (tester) async {
        await openReferenceSources(tester);
        await tester.tap(find.text(l10n.referenceSources_addButton));
        await tester.pumpAndSettle();
        showPhoneKeyboard(tester);
        await tester.pumpAndSettle();

        expectReachable(
          tester,
          find.byKey(const Key('reference_source_picker_search')),
          bottomObscured: _phoneKeyboardHeight,
        );
        final cancel = find.descendant(
          of: find.byType(ReferenceSourcePickerDialog),
          matching: find.widgetWithText(TextButton, l10n.common_cancelButton),
        );
        expectReachable(tester, cancel, bottomObscured: _phoneKeyboardHeight);
      });
    });

    group('refresh progress', () {
      late _ControlledDownloadNotifier notifier;

      Future<void> startRefresh(WidgetTester tester) async {
        notifier = _ControlledDownloadNotifier();
        await pumpPanel(
          tester,
          overrides: [downloadProvider.overrideWith(() => notifier)],
        );
        await tester.longPress(find.text(_novelTitle));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.fileBrowser_refreshMenuItem));
        // The progress indicator never settles.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      testWidgets('fits while downloading', (tester) async {
        await startRefresh(tester);
        notifier.emit(
          const DownloadState(
            status: DownloadStatus.downloading,
            currentEpisode: 1234,
            totalEpisodes: 2345,
            skippedEpisodes: 1000,
            failedEpisodes: 12,
          ),
        );
        await tester.pump();

        expect(
          find.text(l10n.fileBrowser_refreshProgressTitle(_novelTitle)),
          findsOneWidget,
        );
        expectReachable(tester, find.byKey(const Key('refresh_cancel_button')));
      });

      testWidgets('fits when completed with a truncated index', (tester) async {
        await startRefresh(tester);
        notifier.emit(
          const DownloadState(
            status: DownloadStatus.completed,
            currentEpisode: 2345,
            totalEpisodes: 2345,
            skippedEpisodes: 2000,
            failedEpisodes: 3,
            indexTruncated: true,
          ),
        );
        await tester.pumpAndSettle();

        expectReachable(tester, find.byKey(const Key('refresh_close_button')));
        expectShownWhole(tester, find.byType(AlertDialog));
      });

      testWidgets('fits a long error message', (tester) async {
        await startRefresh(tester);
        notifier.emit(
          DownloadState(
            status: DownloadStatus.error,
            errorMessage: List.filled(
              8,
              'HTTP 503 Service Unavailable: https://ncode.syosetu.com/'
              'n1234ab/?p=12 の取得に失敗しました。サーバーが混雑しているか、'
              'メンテナンス中の可能性があります。',
            ).join(),
          ),
        );
        await tester.pumpAndSettle();

        expectReachable(tester, find.byKey(const Key('refresh_close_button')));
        expectShownWhole(tester, find.textContaining('HTTP 503'));
      });
    });
  });

  group('home screen create-collection dialog', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Future<void> openCreateCollection(WidgetTester tester) async {
      usePhoneDisplay(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
            readingProgressStartupProvider.overrideWith(
              (ref) => Completer<void>().future,
            ),
            selectedFileProgressTitleProvider.overrideWithValue('NovelViewer'),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new_collection_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('create_collection_name_field')),
        'なろう・カクヨムで連載中の追放ざまぁ系作品をまとめたコレクション',
      );
      await tester.pumpAndSettle();
    }

    testWidgets('fits', (tester) async {
      await openCreateCollection(tester);

      expect(find.text(l10n.download_createCollectionTitle), findsOneWidget);
      expectReachable(tester, _dialogButton(l10n.common_cancelButton));
      expectReachable(
        tester,
        _dialogButton(l10n.download_createCollectionButton),
      );
    });

    testWidgets('keeps its actions above the keyboard', (tester) async {
      await openCreateCollection(tester);
      showPhoneKeyboard(tester);
      await tester.pumpAndSettle();

      expectReachable(
        tester,
        _dialogButton(l10n.download_createCollectionButton),
        bottomObscured: _phoneKeyboardHeight,
      );
    });
  });
}
