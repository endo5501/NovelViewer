import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_update_check/data/novel_update_checker.dart';
import 'package:novel_viewer/features/novel_update_check/presentation/update_check_progress_dialog.dart';
import 'package:novel_viewer/features/novel_update_check/providers/novel_update_check_providers.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';

import '../../helpers/localized_material_app.dart';

/// Stands in for the real check: records what the UI asks of it, and lets the
/// test put it in any state.
class _FakeUpdateCheckNotifier extends NovelUpdateCheckNotifier {
  int starts = 0;
  int cancels = 0;
  int resets = 0;

  @override
  Future<void> start() async {
    starts++;
    state = const UpdateCheckState(
      status: UpdateCheckStatus.checking,
      done: 5,
      total: 20,
    );
  }

  @override
  void cancel() => cancels++;

  @override
  void reset() {
    resets++;
    state = const UpdateCheckState();
  }

  void set(UpdateCheckState next) => state = next;
}

class _BusyDownloadNotifier extends DownloadNotifier {
  @override
  DownloadState build() =>
      const DownloadState(status: DownloadStatus.downloading);
}

void main() {
  late _FakeUpdateCheckNotifier fake;

  Future<void> pumpPanel(
    WidgetTester tester, {
    bool downloading = false,
  }) async {
    fake = _FakeUpdateCheckNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryPathProvider.overrideWithValue('/library'),
          allNovelsProvider.overrideWith((ref) => []),
          currentDirectoryProvider.overrideWith(
            () => CurrentDirectoryNotifier('/library'),
          ),
          directoryContentsProvider.overrideWith(
            (ref) async =>
                const DirectoryContents(files: [], subdirectories: []),
          ),
          novelUpdateCheckProvider.overrideWith(() => fake),
          if (downloading)
            downloadProvider.overrideWith(_BusyDownloadNotifier.new),
        ],
        child: const LocalizedMaterialApp(
          home: Scaffold(body: FileBrowserPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder button() => find.byKey(const Key('file_browser_update_check_button'));

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(button());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the toolbar offers the check under its own name', (
    tester,
  ) async {
    await pumpPanel(tester);

    expect(button(), findsOneWidget);
    expect(find.byTooltip('新着チェック'), findsOneWidget);
  });

  testWidgets('pressing it starts a check in a modal dialog', (tester) async {
    await pumpPanel(tester);

    await openDialog(tester);

    expect(fake.starts, 1);
    expect(find.byType(UpdateCheckProgressDialog), findsOneWidget);
    // Modal: tapping outside does not dismiss it.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateCheckProgressDialog), findsOneWidget);
  });

  testWidgets('progress and a working cancel show while checking', (
    tester,
  ) async {
    await pumpPanel(tester);
    await openDialog(tester);

    expect(find.text('5 / 20'), findsOneWidget);
    await tester.tap(find.byKey(const Key('update_check_cancel_button')));
    expect(fake.cancels, 1);
    expect(find.byKey(const Key('update_check_close_button')), findsNothing);
  });

  testWidgets('the summary names new and unchecked works', (tester) async {
    await pumpPanel(tester);
    await openDialog(tester);

    fake.set(
      const UpdateCheckState(
        status: UpdateCheckStatus.completed,
        done: 20,
        total: 20,
        summary: UpdateCheckSummary(checked: 19, withNewEpisodes: 3, failed: 1),
      ),
    );
    await tester.pump();

    expect(find.textContaining('新着のある作品: 3作'), findsOneWidget);
    expect(find.textContaining('確認できなかった作品: 1作'), findsOneWidget);
    expect(find.byKey(const Key('update_check_cancel_button')), findsNothing);
  });

  testWidgets('no new episodes is said so', (tester) async {
    await pumpPanel(tester);
    await openDialog(tester);

    fake.set(
      const UpdateCheckState(
        status: UpdateCheckStatus.completed,
        summary: UpdateCheckSummary(checked: 4, withNewEpisodes: 0, failed: 0),
      ),
    );
    await tester.pump();

    expect(find.textContaining('新着はありません'), findsOneWidget);
    expect(find.textContaining('確認できなかった作品'), findsNothing);
  });

  testWidgets('a cancelled check says so and can be closed', (tester) async {
    await pumpPanel(tester);
    await openDialog(tester);

    fake.set(const UpdateCheckState(status: UpdateCheckStatus.cancelled));
    await tester.pump();
    expect(find.text('新着チェックを中断しました'), findsOneWidget);

    await tester.tap(find.byKey(const Key('update_check_close_button')));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateCheckProgressDialog), findsNothing);
    expect(fake.resets, 1);
  });

  testWidgets('a failed check shows an error and can be closed', (
    tester,
  ) async {
    await pumpPanel(tester);
    await openDialog(tester);

    fake.set(const UpdateCheckState(status: UpdateCheckStatus.error));
    await tester.pump();
    expect(find.textContaining('エラー'), findsOneWidget);

    await tester.tap(find.byKey(const Key('update_check_close_button')));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateCheckProgressDialog), findsNothing);
  });

  testWidgets('during a download it warns and does not start', (tester) async {
    await pumpPanel(tester, downloading: true);

    await openDialog(tester);

    expect(fake.starts, 0);
    expect(find.byType(UpdateCheckProgressDialog), findsNothing);
    expect(find.text('ダウンロード中です。完了後に再度お試しください'), findsOneWidget);
  });
}
