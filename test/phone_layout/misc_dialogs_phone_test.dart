import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_progress_record.dart';
import 'package:novel_viewer/features/progress_sync/presentation/sync_prompt_host.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_entry_providers.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_prompt_actions.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/failure/failure_detail_dialog.dart';
import 'package:novel_viewer/shared/failure/failure_report.dart';

import '../helpers/localized_material_app.dart';
import '../helpers/phone_display.dart';

/// The sync prompt and the failure detail dialog on the portrait display of
/// an iPhone 16 (spec adaptive-shell-layout: every dialog fits without
/// overflow and its actions are reachable).
const _safeArea = Rect.fromLTRB(
  0,
  kPhoneTopInset,
  393,
  852 - kPhoneBottomInset,
);

void _expectVisible(WidgetTester tester, Finder finder, String what) {
  expect(finder, findsOneWidget, reason: what);
  final rect = tester.getRect(finder);
  expect(
    rect.left >= _safeArea.left &&
        rect.right <= _safeArea.right &&
        rect.top >= _safeArea.top &&
        rect.bottom <= _safeArea.bottom,
    isTrue,
    reason: '$what at $rect is outside the visible area $_safeArea',
  );
}

class _NoopActions implements SyncPromptActions {
  @override
  Future<void> answer(SyncPromptRequest request, {required bool move}) async {}
}

const _directory = '/library/n9876ab';

final _request = SyncPromptRequest(
  novelId: 'narou_n9876ab',
  directory: _directory,
  fileName: '149_第百四十九話　辺境伯家の三男、王都の魔法学院で旧友と再会する.txt',
  remote: RemoteProgress(
    deviceId: 'win',
    deviceName: 'Windows デスクトップ（書斎のメインマシン・2026年モデル）',
    record: SyncProgressRecord(
      novelId: 'narou_n9876ab',
      episode: 149,
      fileName: '149_第百四十九話　辺境伯家の三男、王都の魔法学院で旧友と再会する.txt',
      bodyOffset: 10,
      bodyHash: 'h',
      readAt: DateTime(2026, 10, 18, 21, 5),
    ),
  ),
);

void main() {
  group('Sync prompt', () {
    testWidgets('fits with a long device name', (tester) async {
      usePhoneDisplay(tester);
      final container = ProviderContainer(
        overrides: [
          syncPromptActionsProvider.overrideWithValue(_NoopActions()),
          currentDirectoryProvider.overrideWith(
            () => CurrentDirectoryNotifier(_directory),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LocalizedMaterialApp(
            home: SyncPromptHost(child: Scaffold(body: Text('reader'))),
          ),
        ),
      );

      container.read(syncPromptProvider.notifier).show(_request);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      _expectVisible(tester, find.text('移動する'), 'move button');
      _expectVisible(tester, find.text('このまま'), 'stay button');
    });
  });

  group('FailureDetailDialog', () {
    final report = FailureReport(
      headline: '「転生したら辺境の村の薬師だったので、のんびり暮らしたいと思います」の更新に失敗しました',
      cause:
          'DioException [connection error]: The connection errored: '
          'Failed host lookup: \'ncode.syosetu.com\' (OS Error: nodename nor '
          'servname provided, or not known, errno = 8) This indicates an error '
          'which most likely cannot be solved by the library. '
          'https://ncode.syosetu.com/n9876ab/149/?p=2&utm_source=novelviewer_ios_app_long_query_parameter_without_spaces_0123456789abcdef',
      stackTrace: StackTrace.fromString(
        List.generate(
          60,
          (i) =>
              '#$i      NovelRefreshService._downloadEpisode '
              '(package:novel_viewer/features/novel_refresh/data/novel_refresh_service.dart:${200 + i}:7)',
        ).join('\n'),
      ),
      diagnostics: const {
        'time': '2026-10-25T10:23:45.123Z',
        'app version': '1.12.0+57 (commit 02ca652b)',
        'platform': 'iOS 26.1 (iPhone17,3)',
        'library':
            '/var/mobile/Containers/Data/Application/0A1B2C3D-4E5F-6789-ABCD-EF0123456789/Documents/NovelViewer/library',
      },
    );

    testWidgets('fits with a long cause and stack trace', (tester) async {
      usePhoneDisplay(tester);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showFailureDetailDialog(context, report),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(FailureDetailDialog), findsOneWidget);
      _expectVisible(
        tester,
        find.widgetWithText(TextButton, 'コピー'),
        'copy button',
      );
      _expectVisible(
        tester,
        find.widgetWithText(TextButton, '閉じる'),
        'close button',
      );
    });
  });
}
