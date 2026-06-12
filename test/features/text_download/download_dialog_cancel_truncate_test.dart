import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class _StateNotifier extends DownloadNotifier {
  final DownloadState _initial;
  bool cancelCalled = false;
  _StateNotifier(this._initial);

  @override
  DownloadState build() => _initial;

  @override
  void cancel() {
    cancelCalled = true;
  }
}

void main() {
  Widget app(DownloadNotifier notifier) {
    return ProviderScope(
      overrides: [
        libraryPathProvider.overrideWithValue('/tmp/test_novels'),
        currentDirectoryProvider
            .overrideWith(() => CurrentDirectoryNotifier('/tmp/test_novels')),
        downloadProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => DownloadDialog.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  group('DownloadDialog cancellation & truncation UI', () {
    testWidgets('shows an enabled cancel button while downloading and calls '
        'cancel() when tapped', (tester) async {
      final notifier = _StateNotifier(const DownloadState(
        status: DownloadStatus.downloading,
        currentEpisode: 2,
        totalEpisodes: 5,
      ));
      await tester.pumpWidget(app(notifier));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final cancelButton = find.widgetWithText(TextButton, 'キャンセル');
      expect(cancelButton, findsOneWidget);
      expect(
        tester.widget<TextButton>(cancelButton).onPressed,
        isNotNull,
      );

      await tester.tap(cancelButton);
      await tester.pumpAndSettle();
      expect(notifier.cancelCalled, isTrue);
    });

    testWidgets('shows the index-truncation warning on completion',
        (tester) async {
      final notifier = _StateNotifier(const DownloadState(
        status: DownloadStatus.completed,
        totalEpisodes: 3,
        indexTruncated: true,
      ));
      await tester.pumpWidget(app(notifier));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.text('目次の取得が途中で失敗しました（一部のエピソードが取得できていない可能性があります）'),
        findsOneWidget,
      );
    });

    testWidgets('does not show the warning when not truncated', (tester) async {
      final notifier = _StateNotifier(const DownloadState(
        status: DownloadStatus.completed,
        totalEpisodes: 3,
      ));
      await tester.pumpWidget(app(notifier));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.text('目次の取得が途中で失敗しました（一部のエピソードが取得できていない可能性があります）'),
        findsNothing,
      );
    });

    testWidgets('shows the cancelled message in the cancelled state',
        (tester) async {
      final notifier = _StateNotifier(const DownloadState(
        status: DownloadStatus.cancelled,
        currentEpisode: 2,
        totalEpisodes: 5,
      ));
      await tester.pumpWidget(app(notifier));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('ダウンロードを中断しました'), findsOneWidget);
      // A close button should be available to dismiss the dialog.
      expect(find.widgetWithText(TextButton, '閉じる'), findsOneWidget);
    });
  });
}
