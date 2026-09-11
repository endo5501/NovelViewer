import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_download/data/incoming_link_source.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_download/providers/download_request_providers.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what it is asked to download instead of downloading anything.
class _RecordingDownloadNotifier extends DownloadNotifier {
  _RecordingDownloadNotifier(this.started);

  final List<Uri> started;

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

  late SharedPreferences prefs;
  late StreamController<Uri> platform;
  late List<Uri> started;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    platform = StreamController<Uri>();
    started = [];
  });

  tearDown(() async {
    if (!platform.isClosed) await platform.close();
  });

  /// Advances far enough for a stream event to be delivered and a dialog
  /// transition to finish. The home screen never reaches a quiescent state
  /// under a library path that does not exist, so `pumpAndSettle` cannot be
  /// used here.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/library'),
          incomingLinkSourceProvider.overrideWithValue(
            IncomingLinkSource(
              initialLink: Future.value(null),
              platformLinks: platform.stream,
            ),
          ),
          downloadProvider.overrideWith(
            () => _RecordingDownloadNotifier(started),
          ),
        ],
        child: const NovelViewerApp(),
      ),
    );
    await settle(tester);
  }

  String urlFieldText(WidgetTester tester) {
    final field = tester.widget<TextField>(find.byType(TextField).first);
    return field.controller!.text;
  }

  group('HomeScreen receiving a download request', () {
    testWidgets('opens the dialog with the shared URL', (tester) async {
      await pumpHome(tester);
      expect(find.byType(DownloadDialog), findsNothing);

      platform.add(sharedLink);
      await settle(tester);

      expect(find.byType(DownloadDialog), findsOneWidget);
      expect(urlFieldText(tester), shared.toString());
    });

    testWidgets('does not start the download by itself', (tester) async {
      // The scheme can be opened by any page the reader happens to visit, so
      // reaching the dialog must never be enough on its own.
      await pumpHome(tester);

      platform.add(sharedLink);
      await settle(tester);

      expect(started, isEmpty);
    });

    testWidgets('does not open a second dialog over the first', (tester) async {
      await pumpHome(tester);

      platform.add(sharedLink);
      await settle(tester);
      platform.add(
        Uri.parse('novelviewer://download?url=https%3A%2F%2Fa.test'),
      );
      await settle(tester);

      expect(find.byType(DownloadDialog), findsOneWidget);
      expect(urlFieldText(tester), 'https://a.test');
    });

    testWidgets('shows the later of two requests arriving together', (
      tester,
    ) async {
      // The second one lands after the dialog is pushed but before it builds,
      // which is the window where a request is easiest to lose.
      await pumpHome(tester);

      platform.add(sharedLink);
      platform.add(
        Uri.parse('novelviewer://download?url=https%3A%2F%2Fa.test'),
      );
      await settle(tester);

      expect(find.byType(DownloadDialog), findsOneWidget);
      expect(urlFieldText(tester), 'https://a.test');
      expect(started, isEmpty);
    });

    testWidgets('opens the dialog again after it was closed', (tester) async {
      await pumpHome(tester);

      platform.add(sharedLink);
      await settle(tester);
      await tester.tap(find.text('キャンセル'));
      await settle(tester);
      expect(find.byType(DownloadDialog), findsNothing);

      platform.add(sharedLink);
      await settle(tester);

      expect(find.byType(DownloadDialog), findsOneWidget);
      expect(urlFieldText(tester), shared.toString());
    });

    testWidgets('ignores a link that is not a download request', (
      tester,
    ) async {
      await pumpHome(tester);

      platform.add(Uri.parse('novelviewer://download?url=file%3A%2F%2F%2Fx'));
      platform.add(Uri.parse('https://ncode.syosetu.com/n1234ab/'));
      await settle(tester);

      expect(find.byType(DownloadDialog), findsNothing);
      expect(started, isEmpty);
    });
  });
}
