import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class _FakeDownloadNotifier extends DownloadNotifier {
  @override
  Future<void> startDownload(
      {required Uri url, required String outputPath}) async {
    state = DownloadState(
      status: DownloadStatus.completed,
      outputPath: outputPath,
      totalEpisodes: 1,
    );
  }
}

void main() {
  const root = '/tmp/test_novels';

  Widget createApp({required List<DirectoryEntry> destinations}) {
    return ProviderScope(
      overrides: [
        libraryPathProvider.overrideWithValue(root),
        currentDirectoryProvider
            .overrideWith(() => CurrentDirectoryNotifier(root)),
        downloadProvider.overrideWith(() => _FakeDownloadNotifier()),
        downloadDestinationFoldersProvider
            .overrideWith((ref) async => destinations),
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

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('DownloadDialog destination selector', () {
    testWidgets('shows a destination dropdown listing root and subfolders',
        (tester) async {
      await tester.pumpWidget(createApp(destinations: const [
        DirectoryEntry(
            name: '完結済み', path: '$root/完結済み', displayName: '完結済み'),
      ]));
      await openDialog(tester);

      expect(find.byKey(const Key('download_destination_dropdown')),
          findsOneWidget);
      // The currently-selected value (root, the default) is visible.
      expect(find.text('ライブラリルート（既定）'), findsWidgets);
    });

    testWidgets('defaults to library root when nothing is selected',
        (tester) async {
      await tester.pumpWidget(createApp(destinations: const [
        DirectoryEntry(
            name: '完結済み', path: '$root/完結済み', displayName: '完結済み'),
      ]));
      await openDialog(tester);

      await tester.enterText(
        find.byType(TextField),
        'https://ncode.syosetu.com/n9669bk/',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'ダウンロード開始'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
          tester.element(find.byType(AlertDialog)));
      expect(container.read(downloadProvider).outputPath, root);
    });

    testWidgets('passes the selected subfolder as the download outputPath',
        (tester) async {
      await tester.pumpWidget(createApp(destinations: const [
        DirectoryEntry(
            name: '完結済み', path: '$root/完結済み', displayName: '完結済み'),
      ]));
      await openDialog(tester);

      await tester.enterText(
        find.byType(TextField),
        'https://ncode.syosetu.com/n9669bk/',
      );
      await tester.pumpAndSettle();

      // Open the dropdown and pick the subfolder.
      await tester.tap(find.byKey(const Key('download_destination_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完結済み').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'ダウンロード開始'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
          tester.element(find.byType(AlertDialog)));
      expect(container.read(downloadProvider).outputPath, '$root/完結済み');
    });

    testWidgets('shows only the root option when there are no subfolders',
        (tester) async {
      await tester.pumpWidget(createApp(destinations: const []));
      await openDialog(tester);

      await tester.tap(find.byKey(const Key('download_destination_dropdown')));
      await tester.pumpAndSettle();

      // The dropdown menu shows just the root entry (selected item + menu item).
      expect(find.text('ライブラリルート（既定）'), findsWidgets);
      expect(find.text('完結済み'), findsNothing);
    });
  });
}
