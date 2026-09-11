import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_download/data/incoming_link_source.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_download/providers/download_request_providers.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// A download notifier parked in a given state, which records what it is asked
/// to download instead of downloading anything.
class _RecordingDownloadNotifier extends DownloadNotifier {
  _RecordingDownloadNotifier(this._initial, this.started);

  final DownloadState _initial;
  final List<Uri> started;

  @override
  DownloadState build() => _initial;

  /// Lets a test move the dialog out of the state it was opened in.
  void fail() => state = const DownloadState(
    status: DownloadStatus.error,
    errorMessage: 'boom',
  );

  @override
  Future<void> startDownload({
    required Uri url,
    required String outputPath,
  }) async {
    started.add(url);
  }

  @override
  Future<void> startCollectionDownload({
    required Uri url,
    required String libraryPath,
    String? existingCollectionPath,
    String? newCollectionName,
  }) async {
    started.add(url);
  }
}

void main() {
  final shared = Uri.parse('https://ncode.syosetu.com/n1234ab/');
  final sharedLink = Uri.parse(
    'novelviewer://download?url=https%3A%2F%2Fncode.syosetu.com%2Fn1234ab%2F',
  );
  final opened = Uri.parse('https://kakuyomu.jp/works/1');

  const ignoredNotice = Key('download_incoming_request_ignored');

  late StreamController<Uri> platform;
  late List<Uri> started;

  setUp(() {
    platform = StreamController<Uri>();
    started = [];
  });

  tearDown(() async {
    if (!platform.isClosed) await platform.close();
  });

  Widget createApp({
    Uri? initialUrl,
    DownloadState state = const DownloadState(),
  }) {
    return ProviderScope(
      overrides: [
        libraryPathProvider.overrideWithValue('/tmp/test_novels'),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier('/tmp/test_novels'),
        ),
        incomingLinkSourceProvider.overrideWithValue(
          IncomingLinkSource(
            initialLink: Future.value(null),
            platformLinks: platform.stream,
          ),
        ),
        downloadProvider.overrideWith(
          () => _RecordingDownloadNotifier(state, started),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () =>
                  DownloadDialog.show(context, initialUrl: initialUrl),
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

  String urlFieldText(WidgetTester tester) {
    final field = tester.widget<TextField>(find.byType(TextField).first);
    return field.controller!.text;
  }

  _RecordingDownloadNotifier notifier(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    return container.read(downloadProvider.notifier)
        as _RecordingDownloadNotifier;
  }

  group('DownloadDialog opened with a URL', () {
    testWidgets('shows the URL it was opened with', (tester) async {
      await tester.pumpWidget(createApp(initialUrl: opened));
      await openDialog(tester);

      expect(urlFieldText(tester), opened.toString());
      expect(find.byKey(ignoredNotice), findsNothing);
    });

    testWidgets('does not download on its own', (tester) async {
      // Anything can open the app's URL scheme, so arriving at the dialog must
      // never be enough to start a download.
      await tester.pumpWidget(createApp(initialUrl: opened));
      await openDialog(tester);

      expect(started, isEmpty);
    });
  });

  group('DownloadDialog opened with a request already pending', () {
    testWidgets('takes the request that arrived before it was built', (
      tester,
    ) async {
      // A second share can land between the dialog being pushed and its first
      // build. The home screen sees a dialog already opening and leaves it
      // alone, so the dialog has to pick the request up itself.
      await tester.pumpWidget(createApp(initialUrl: opened));
      ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(pendingDownloadRequestProvider);
      platform.add(sharedLink);
      await tester.pump();

      await openDialog(tester);

      expect(urlFieldText(tester), shared.toString());
      expect(started, isEmpty);
    });

    testWidgets('leaves a handled request alone when opened again', (
      tester,
    ) async {
      await tester.pumpWidget(createApp(initialUrl: opened));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(pendingDownloadRequestProvider);
      platform.add(sharedLink);
      await tester.pump();

      await openDialog(tester);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      await openDialog(tester);

      expect(urlFieldText(tester), opened.toString());
    });
  });

  group('DownloadDialog receiving a request while open', () {
    testWidgets('replaces the URL while waiting for input', (tester) async {
      await tester.pumpWidget(createApp(initialUrl: opened));
      await openDialog(tester);

      platform.add(sharedLink);
      await tester.pumpAndSettle();

      expect(urlFieldText(tester), shared.toString());
      expect(find.byKey(ignoredNotice), findsNothing);
      expect(started, isEmpty);
    });

    testWidgets('replaces the URL after a failed download', (tester) async {
      // A failed download leaves the dialog editable with its start button
      // available, so it is waiting for a URL just as much as a fresh one is.
      await tester.pumpWidget(
        createApp(
          initialUrl: opened,
          state: const DownloadState(
            status: DownloadStatus.error,
            errorMessage: 'boom',
          ),
        ),
      );
      await openDialog(tester);

      platform.add(sharedLink);
      await tester.pumpAndSettle();

      expect(urlFieldText(tester), shared.toString());
      expect(find.byKey(ignoredNotice), findsNothing);
      expect(started, isEmpty);
    });

    testWidgets('keeps the URL and reports it while downloading', (
      tester,
    ) async {
      await tester.pumpWidget(
        createApp(
          initialUrl: opened,
          state: const DownloadState(
            status: DownloadStatus.downloading,
            currentEpisode: 1,
            totalEpisodes: 3,
          ),
        ),
      );
      await openDialog(tester);

      platform.add(sharedLink);
      await tester.pumpAndSettle();

      expect(urlFieldText(tester), opened.toString());
      expect(find.byKey(ignoredNotice), findsOneWidget);
      expect(started, isEmpty);
    });

    testWidgets('reports it while a finished download is still shown', (
      tester,
    ) async {
      // The dialog stays on screen showing the result until it is closed, so
      // "not downloading" is not the same as "ready for another URL".
      await tester.pumpWidget(
        createApp(
          initialUrl: opened,
          state: const DownloadState(
            status: DownloadStatus.completed,
            totalEpisodes: 3,
          ),
        ),
      );
      await openDialog(tester);

      platform.add(sharedLink);
      await tester.pumpAndSettle();

      expect(urlFieldText(tester), opened.toString());
      expect(find.byKey(ignoredNotice), findsOneWidget);
      expect(started, isEmpty);
    });

    testWidgets('reports it while a cancelled download is still shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        createApp(
          initialUrl: opened,
          state: const DownloadState(status: DownloadStatus.cancelled),
        ),
      );
      await openDialog(tester);

      platform.add(sharedLink);
      await tester.pumpAndSettle();

      expect(urlFieldText(tester), opened.toString());
      expect(find.byKey(ignoredNotice), findsOneWidget);
      expect(started, isEmpty);
    });

    testWidgets('stops reporting once a later request is taken', (
      tester,
    ) async {
      await tester.pumpWidget(
        createApp(
          initialUrl: opened,
          state: const DownloadState(
            status: DownloadStatus.downloading,
            totalEpisodes: 3,
          ),
        ),
      );
      await openDialog(tester);

      platform.add(sharedLink);
      await tester.pumpAndSettle();
      expect(find.byKey(ignoredNotice), findsOneWidget);

      notifier(tester).fail();
      await tester.pumpAndSettle();
      platform.add(
        Uri.parse('novelviewer://download?url=https%3A%2F%2Fa.test'),
      );
      await tester.pumpAndSettle();

      expect(urlFieldText(tester), 'https://a.test');
      expect(find.byKey(ignoredNotice), findsNothing);
      expect(started, isEmpty);
    });
  });
}
