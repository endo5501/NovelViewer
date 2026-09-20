import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_refresh/domain/refresh_target.dart';
import 'package:novel_viewer/features/novel_refresh/presentation/refresh_progress_dialog.dart';
import 'package:novel_viewer/features/novel_refresh/providers/refresh_target_provider.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the refreshes it is asked for, and can start out busy so the
/// concurrency guard has something to refuse.
class _RecordingDownloadNotifier extends DownloadNotifier {
  _RecordingDownloadNotifier({this.busy = false});

  final bool busy;
  final List<({String folderName, String parentPath})> refreshCalls = [];

  @override
  DownloadState build() => busy
      ? const DownloadState(status: DownloadStatus.downloading)
      : const DownloadState();

  @override
  Future<void> refreshNovel(
    String folderName, {
    required String parentPath,
  }) async {
    refreshCalls.add((folderName: folderName, parentPath: parentPath));
    state = const DownloadState(status: DownloadStatus.downloading);
  }

  void emit(DownloadState next) => state = next;
}

void main() {
  const target = RefreshTarget(
    folderName: 'narou_n1234ab',
    parentPath: '/library/完結済み',
    title: '異世界転生物語',
  );

  late SharedPreferences prefs;
  late _RecordingDownloadNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// The home screen never reaches a quiescent state under a library path that
  /// does not exist, so `pumpAndSettle` cannot be used here.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    RefreshTarget? refreshTarget,
    bool busy = false,
  }) async {
    notifier = _RecordingDownloadNotifier(busy: busy);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/library'),
          // The resolution itself is covered by
          // refresh_target_provider_test.dart; here only the two outcomes of
          // it matter.
          refreshTargetProvider.overrideWithValue(refreshTarget),
          downloadProvider.overrideWith(() => notifier),
        ],
        child: const NovelViewerApp(),
      ),
    );
    await settle(tester);
    // The drawer opens over the app bar at startup, so put it away first.
    if (find.byType(Drawer).evaluate().isNotEmpty) {
      Navigator.of(tester.element(find.byType(Drawer))).pop();
      await settle(tester);
    }
  }

  Finder downloadButton() => find.byKey(const Key('appbar_download_button'));

  IconData buttonIcon(WidgetTester tester) {
    final icon = find.descendant(
      of: downloadButton(),
      matching: find.byType(Icon),
    );
    return tester.widget<Icon>(icon).icon!;
  }

  group('HomeScreen のダウンロードボタン', () {
    testWidgets('更新対象があるとき更新ボタンとして表示される', (tester) async {
      await pumpHome(tester, refreshTarget: target);

      expect(buttonIcon(tester), Icons.sync);
      expect(find.byTooltip('小説を更新'), findsOneWidget);
      expect(tester.widget<IconButton>(downloadButton()).onPressed, isNotNull);
    });

    testWidgets('更新対象がないときダウンロードボタンとして表示される', (tester) async {
      await pumpHome(tester);

      expect(buttonIcon(tester), Icons.download);
      expect(find.byTooltip('小説ダウンロード'), findsOneWidget);
      expect(tester.widget<IconButton>(downloadButton()).onPressed, isNotNull);
    });

    testWidgets('更新対象があるとき押下で更新が始まり進捗ダイアログが出る', (tester) async {
      await pumpHome(tester, refreshTarget: target);

      await tester.tap(downloadButton());
      await settle(tester);

      expect(notifier.refreshCalls, hasLength(1));
      expect(notifier.refreshCalls.single.folderName, 'narou_n1234ab');
      expect(notifier.refreshCalls.single.parentPath, '/library/完結済み');
      expect(find.byType(RefreshProgressDialog), findsOneWidget);
      expect(find.byType(DownloadDialog), findsNothing);
    });

    testWidgets('更新対象がないとき押下でダウンロードダイアログが出る', (tester) async {
      await pumpHome(tester);

      await tester.tap(downloadButton());
      await settle(tester);

      expect(find.byType(DownloadDialog), findsOneWidget);
      expect(find.byType(RefreshProgressDialog), findsNothing);
      expect(notifier.refreshCalls, isEmpty);
    });

    testWidgets('更新の完了後も更新ボタンのままである', (tester) async {
      await pumpHome(tester, refreshTarget: target);

      await tester.tap(downloadButton());
      await settle(tester);
      notifier.emit(
        const DownloadState(status: DownloadStatus.completed, totalEpisodes: 3),
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('refresh_close_button')));
      await settle(tester);

      expect(find.byType(RefreshProgressDialog), findsNothing);
      expect(buttonIcon(tester), Icons.sync);
    });

    testWidgets('ダウンロード実行中の押下は警告のみで更新を始めない', (tester) async {
      await pumpHome(tester, refreshTarget: target, busy: true);

      await tester.tap(downloadButton());
      await settle(tester);

      expect(notifier.refreshCalls, isEmpty);
      expect(find.byType(RefreshProgressDialog), findsNothing);
      expect(find.text('ダウンロード中です。完了後に再度お試しください'), findsOneWidget);
    });
  });
}
