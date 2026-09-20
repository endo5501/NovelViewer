import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_refresh/domain/refresh_target.dart';
import 'package:novel_viewer/features/novel_refresh/presentation/refresh_progress_dialog.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';

import '../../helpers/localized_material_app.dart';

/// Records the refresh it is asked for instead of touching the network, and
/// lets the test put the pipeline into the busy state the guard looks at.
class _RecordingDownloadNotifier extends DownloadNotifier {
  final List<({String folderName, String parentPath})> refreshCalls = [];

  @override
  Future<void> refreshNovel(
    String folderName, {
    required String parentPath,
  }) async {
    refreshCalls.add((folderName: folderName, parentPath: parentPath));
    state = const DownloadState(status: DownloadStatus.downloading);
  }

  void markDownloading() =>
      state = const DownloadState(status: DownloadStatus.downloading);
}

void main() {
  const target = RefreshTarget(
    folderName: 'narou_n1234ab',
    parentPath: '/library/完結済み',
    title: '異世界転生物語',
  );

  late _RecordingDownloadNotifier notifier;

  /// Pumps a screen whose only button starts a refresh for [target], so the
  /// test presses it the way the app bar and the context menu both will.
  Future<void> pumpStarter(WidgetTester tester) async {
    notifier = _RecordingDownloadNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [downloadProvider.overrideWith(() => notifier)],
        child: LocalizedMaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => startNovelRefresh(context, ref, target),
                child: const Text('start'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('startNovelRefresh', () {
    testWidgets('待機中は対象のフォルダ名と親ディレクトリで更新を開始し、進捗ダイアログを出す', (tester) async {
      await pumpStarter(tester);

      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      expect(notifier.refreshCalls, hasLength(1));
      expect(notifier.refreshCalls.single.folderName, 'narou_n1234ab');
      expect(notifier.refreshCalls.single.parentPath, '/library/完結済み');
      expect(find.byType(RefreshProgressDialog), findsOneWidget);
      expect(find.textContaining('異世界転生物語'), findsOneWidget);
    });

    testWidgets('ダウンロード実行中は警告のみで更新を開始しない', (tester) async {
      await pumpStarter(tester);
      notifier.markDownloading();
      await tester.pump();

      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      expect(notifier.refreshCalls, isEmpty);
      expect(find.byType(RefreshProgressDialog), findsNothing);
      expect(find.text('ダウンロード中です。完了後に再度お試しください'), findsOneWidget);
    });
  });
}
