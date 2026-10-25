import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/data/incoming_link_source.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_download/providers/download_request_providers.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

import '../helpers/phone_display.dart';

/// A download notifier parked in a given state, which downloads nothing.
class _ParkedDownloadNotifier extends DownloadNotifier {
  _ParkedDownloadNotifier(this._initial);

  final DownloadState _initial;

  @override
  DownloadState build() => _initial;

  @override
  Future<void> startDownload({
    required Uri url,
    required String outputPath,
  }) async {}

  @override
  Future<void> startCollectionDownload({
    required Uri url,
    required String libraryPath,
    String? existingCollectionPath,
    String? newCollectionName,
  }) async {}
}

/// The download dialog on the portrait display of an iPhone 16 (spec
/// adaptive-shell-layout: every dialog fits, and its actions are reachable).
void main() {
  const library = '/library';

  // A narou episode URL and a long article URL with a percent-encoded
  // Japanese path and query, as a share from Safari hands them over.
  const narouUrl = 'https://ncode.syosetu.com/n9876zy/123/';
  const longWebUrl =
      'https://www.example-novel-blog.jp/articles/2026/10/'
      '%E8%BB%A2%E7%94%9F%E3%81%97%E3%81%9F%E3%82%89%E8%BE%BA%E5%A2%83%E3%81%AE'
      '%E6%9D%91%E3%81%AE%E8%96%AC%E5%B8%AB%E3%81%A0%E3%81%A3%E3%81%9F'
      '?utm_source=share&utm_medium=ios&ref=reading-list-entry-0042';
  const longFolder = '異世界ファンタジー/長編/転生したら辺境の村の薬師だったので、のんびり暮らしたいと思います';
  const longCollection = '気になったWeb記事のまとめ — 小説の書き方・プロット構成・キャラクター造形についての参考資料集';
  const longError =
      'サーバーからの応答がありませんでした: SocketException: Connection timed out '
      '(OS Error: Operation timed out, errno = 60), '
      'address = ncode.syosetu.com, port = 443, uri = $narouUrl';

  late AppLocalizations ja;
  late StreamController<Uri> platformLinks;

  setUpAll(() async {
    ja = await AppLocalizations.delegate.load(const Locale('ja'));
  });

  setUp(() => platformLinks = StreamController<Uri>());
  tearDown(() async {
    if (!platformLinks.isClosed) await platformLinks.close();
  });

  const reachable = Rect.fromLTRB(
    0,
    kPhoneTopInset,
    393,
    852 - kPhoneBottomInset,
  );

  /// The dialog's card. The [AlertDialog] spans the whole route, inset padding
  /// included, so its own rect says nothing about where it shows.
  Finder dialogCard() => find
      .descendant(of: find.byType(AlertDialog), matching: find.byType(Material))
      .first;

  void expectInside(
    WidgetTester tester,
    Finder finder,
    Rect area,
    String what,
  ) {
    expect(finder, findsWidgets, reason: what);
    for (final element in finder.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(
        area.contains(rect.topLeft) &&
            area.contains(rect.bottomRight - const Offset(0.01, 0.01)),
        isTrue,
        reason: '$what at $rect is outside $area',
      );
    }
  }

  void expectActionsReachable(WidgetTester tester, {Rect area = reachable}) {
    expectInside(tester, dialogCard(), area, 'the dialog');
    expectInside(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
      area,
      'an action',
    );
  }

  Future<void> openDialog(
    WidgetTester tester, {
    DownloadState state = const DownloadState(),
    Uri? initialUrl,
    List<DirectoryEntry> destinations = const [],
    List<NovelMetadata> novels = const [],
  }) async {
    usePhoneDisplay(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryPathProvider.overrideWithValue(library),
          currentDirectoryProvider.overrideWith(
            () => CurrentDirectoryNotifier(library),
          ),
          downloadDestinationFoldersProvider.overrideWith(
            (ref) async => destinations,
          ),
          allNovelsProvider.overrideWith((ref) async => novels),
          incomingLinkSourceProvider.overrideWithValue(
            IncomingLinkSource(
              initialLink: Future.value(null),
              platformLinks: platformLinks.stream,
            ),
          ),
          downloadProvider.overrideWith(() => _ParkedDownloadNotifier(state)),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      DownloadDialog.show(context, initialUrl: initialUrl),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Finder urlField() => find
      .descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      )
      .first;

  group('download dialog on an iPhone', () {
    testWidgets('fits when idle', (tester) async {
      await openDialog(tester);

      expect(find.text(ja.download_title), findsOneWidget);
      expectActionsReachable(tester);
    });

    testWidgets('fits with a narou URL typed', (tester) async {
      await openDialog(tester);
      await tester.enterText(urlField(), narouUrl);
      await tester.pumpAndSettle();

      expectActionsReachable(tester);
    });

    testWidgets('fits with a long article URL typed', (tester) async {
      await openDialog(tester);
      await tester.enterText(urlField(), longWebUrl);
      await tester.pumpAndSettle();

      // A generic web page is filed into a collection.
      expect(find.byKey(const Key('collection_mode_create')), findsOneWidget);
      expectActionsReachable(tester);
    });

    testWidgets('fits with a long article URL and an existing collection '
        'chosen', (tester) async {
      await openDialog(
        tester,
        novels: [
          NovelMetadata(
            siteType: 'web',
            novelId: 'web-collection-1',
            title: longCollection,
            url: '',
            folderName: 'web-collection-1',
            episodeCount: 12,
            downloadedAt: DateTime(2026, 10, 1),
          ),
        ],
      );
      await tester.enterText(urlField(), longWebUrl);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection_mode_existing')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection_existing_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(longCollection).last);
      await tester.pumpAndSettle();

      expect(find.text(longCollection), findsOneWidget);
      expectActionsReachable(tester);
    });

    testWidgets('fits with a long destination folder chosen', (tester) async {
      await openDialog(
        tester,
        destinations: const [
          DirectoryEntry(
            name: 'のんびり暮らしたいと思います',
            path: '$library/$longFolder',
            displayName: longFolder,
          ),
        ],
      );
      await tester.enterText(urlField(), narouUrl);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download_destination_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(longFolder).last);
      await tester.pumpAndSettle();

      expect(find.text(longFolder), findsOneWidget);
      expectActionsReachable(tester);
    });

    const aboveKeyboard = Rect.fromLTRB(
      0,
      kPhoneTopInset,
      393,
      852 - kPhoneKeyboardHeight,
    );

    testWidgets('fits with the keyboard up while typing a narou URL', (
      tester,
    ) async {
      await openDialog(tester);
      await tester.enterText(urlField(), narouUrl);
      showPhoneKeyboard(tester);
      await tester.pumpAndSettle();

      expectActionsReachable(tester, area: aboveKeyboard);
    });

    testWidgets('fits with the keyboard up while typing an article URL', (
      tester,
    ) async {
      await openDialog(tester);
      await tester.enterText(urlField(), longWebUrl);
      showPhoneKeyboard(tester);
      await tester.pumpAndSettle();

      expectActionsReachable(tester, area: aboveKeyboard);
    });

    testWidgets('fits with the keyboard up retyping a URL after an error', (
      tester,
    ) async {
      await openDialog(
        tester,
        initialUrl: Uri.parse(narouUrl),
        state: const DownloadState(
          status: DownloadStatus.error,
          errorMessage: longError,
        ),
      );
      await tester.enterText(urlField(), narouUrl);
      showPhoneKeyboard(tester);
      await tester.pumpAndSettle();

      expectActionsReachable(tester, area: aboveKeyboard);
    });

    testWidgets('fits while downloading, with skipped and failed episodes', (
      tester,
    ) async {
      await openDialog(
        tester,
        initialUrl: Uri.parse(narouUrl),
        state: const DownloadState(
          status: DownloadStatus.downloading,
          currentEpisode: 1234,
          totalEpisodes: 2345,
          skippedEpisodes: 1100,
          failedEpisodes: 12,
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expectActionsReachable(tester);
    });

    testWidgets('fits while downloading with a shared URL turned away', (
      tester,
    ) async {
      await openDialog(
        tester,
        initialUrl: Uri.parse(narouUrl),
        state: const DownloadState(
          status: DownloadStatus.downloading,
          currentEpisode: 12,
          totalEpisodes: 345,
        ),
      );
      platformLinks.add(
        Uri.parse(
          'novelviewer://download?url=${Uri.encodeComponent(longWebUrl)}',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('download_incoming_request_ignored')),
        findsOneWidget,
      );
      expectActionsReachable(tester);
    });

    testWidgets('fits when completed with a truncated index', (tester) async {
      await openDialog(
        tester,
        initialUrl: Uri.parse(narouUrl),
        state: const DownloadState(
          status: DownloadStatus.completed,
          totalEpisodes: 2345,
          skippedEpisodes: 1100,
          failedEpisodes: 12,
          indexTruncated: true,
        ),
      );

      expectActionsReachable(tester);
    });

    testWidgets('fits when cancelled', (tester) async {
      await openDialog(
        tester,
        initialUrl: Uri.parse(narouUrl),
        state: const DownloadState(status: DownloadStatus.cancelled),
      );

      expectActionsReachable(tester);
    });

    testWidgets('fits with a long error message', (tester) async {
      await openDialog(
        tester,
        initialUrl: Uri.parse(narouUrl),
        state: const DownloadState(
          status: DownloadStatus.error,
          errorMessage: longError,
        ),
      );

      expect(find.textContaining('SocketException'), findsOneWidget);
      expectActionsReachable(tester);
    });

    testWidgets('fits with an invalid URL error under the field', (
      tester,
    ) async {
      await openDialog(tester);
      await tester.enterText(urlField(), 'ncode.syosetu.com/n9876zy/');
      await tester.pumpAndSettle();

      expectActionsReachable(tester);
    });
  });
}
