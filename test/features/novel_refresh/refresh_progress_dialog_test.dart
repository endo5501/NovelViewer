import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_refresh/presentation/refresh_progress_dialog.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';

import '../../helpers/localized_material_app.dart';

/// A notifier whose state the test drives directly, and which records the
/// cancellation the dialog's button is supposed to request.
class _ControlledDownloadNotifier extends DownloadNotifier {
  int cancelCount = 0;

  @override
  void cancel() => cancelCount++;

  void emit(DownloadState next) => state = next;
}

void main() {
  late _ControlledDownloadNotifier notifier;
  var novelsBuilds = 0;
  var listingBuilds = 0;

  Future<void> pumpDialog(WidgetTester tester, DownloadState initial) async {
    notifier = _ControlledDownloadNotifier();
    novelsBuilds = 0;
    listingBuilds = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadProvider.overrideWith(() => notifier),
          allNovelsProvider.overrideWith((ref) async {
            novelsBuilds++;
            return const [];
          }),
          directoryContentsProvider.overrideWith((ref) async {
            listingBuilds++;
            return DirectoryContents.empty();
          }),
        ],
        child: LocalizedMaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Stands in for the file browser: something has to be
                // listening for an invalidation to recompute anything.
                Consumer(
                  builder: (context, ref, _) {
                    ref.watch(allNovelsProvider);
                    ref.watch(directoryContentsProvider);
                    return const SizedBox.shrink();
                  },
                ),
                const RefreshProgressDialog(novelTitle: '異世界転生物語'),
              ],
            ),
          ),
        ),
      ),
    );
    notifier.emit(initial);
    await tester.pump();
  }

  group('RefreshProgressDialog', () {
    testWidgets('ダウンロード中はキャンセルボタンを表示し、閉じるボタンは出さない', (tester) async {
      await pumpDialog(
        tester,
        const DownloadState(
          status: DownloadStatus.downloading,
          currentEpisode: 3,
          totalEpisodes: 10,
        ),
      );

      final cancel = find.widgetWithText(TextButton, 'キャンセル');
      expect(cancel, findsOneWidget);
      expect(tester.widget<TextButton>(cancel).onPressed, isNotNull);
      expect(find.widgetWithText(TextButton, '閉じる'), findsNothing);
      expect(find.text('3 / 10 エピソード'), findsOneWidget);
    });

    testWidgets('キャンセル押下でDownloadNotifier.cancelが呼ばれる', (tester) async {
      await pumpDialog(
        tester,
        const DownloadState(status: DownloadStatus.downloading),
      );

      await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
      await tester.pump();

      expect(notifier.cancelCount, 1);
    });

    testWidgets('キャンセル済みの状態はエラーではなく中断メッセージを表示する', (tester) async {
      await pumpDialog(
        tester,
        const DownloadState(status: DownloadStatus.cancelled),
      );

      expect(find.text('ダウンロードを中断しました'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '閉じる'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'キャンセル'), findsNothing);
      // A user-initiated stop is not a failure, so it is not painted as one.
      final message = tester.widget<Text>(find.text('ダウンロードを中断しました'));
      expect(message.style?.color, isNot(Colors.red));
    });

    testWidgets('完了時は完了メッセージと閉じるボタンを表示する', (tester) async {
      await pumpDialog(
        tester,
        const DownloadState(
          status: DownloadStatus.completed,
          totalEpisodes: 12,
          skippedEpisodes: 2,
        ),
      );

      expect(find.textContaining('更新が完了しました'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '閉じる'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'キャンセル'), findsNothing);
    });

    testWidgets('エラー時はエラーメッセージと閉じるボタンを表示する', (tester) async {
      await pumpDialog(
        tester,
        const DownloadState(
          status: DownloadStatus.error,
          errorMessage: '小説のメタデータが見つかりません',
        ),
      );

      expect(find.textContaining('小説のメタデータが見つかりません'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '閉じる'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'キャンセル'), findsNothing);
    });

    testWidgets('キャンセル後に閉じるとファイル一覧を読み直す', (tester) async {
      // Episodes saved before the cancel stay on disk, so a listing that is
      // not reloaded hides them until the reader navigates away and back.
      await pumpDialog(
        tester,
        const DownloadState(status: DownloadStatus.cancelled),
      );
      await tester.pumpAndSettle();
      final before = (novelsBuilds, listingBuilds);

      await tester.tap(find.byKey(const Key('refresh_close_button')));
      await tester.pumpAndSettle();

      expect(novelsBuilds, greaterThan(before.$1));
      expect(listingBuilds, greaterThan(before.$2));
    });

    testWidgets('エラー後に閉じてもファイル一覧を読み直す', (tester) async {
      await pumpDialog(
        tester,
        const DownloadState(
          status: DownloadStatus.error,
          errorMessage: '通信に失敗しました',
        ),
      );
      await tester.pumpAndSettle();
      final before = (novelsBuilds, listingBuilds);

      await tester.tap(find.byKey(const Key('refresh_close_button')));
      await tester.pumpAndSettle();

      expect(novelsBuilds, greaterThan(before.$1));
      expect(listingBuilds, greaterThan(before.$2));
    });

    testWidgets('タイトルに小説名を表示する', (tester) async {
      await pumpDialog(
        tester,
        const DownloadState(status: DownloadStatus.downloading),
      );

      expect(find.textContaining('異世界転生物語'), findsOneWidget);
    });
  });
}
