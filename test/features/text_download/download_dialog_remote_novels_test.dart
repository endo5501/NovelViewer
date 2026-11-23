import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/progress_sync_auth.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_progress_record.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_config_providers.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_providers.dart';
import 'package:novel_viewer/features/progress_sync/providers/remote_novel_candidates_provider.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

import '../../helpers/phone_display.dart';

class _FakeDownloadNotifier extends DownloadNotifier {
  final starts = <Uri>[];
  Completer<void>? hold;

  @override
  Future<void> startDownload({
    required Uri url,
    required String outputPath,
  }) async {
    starts.add(url);
    state = DownloadState(
      status: DownloadStatus.downloading,
      outputPath: outputPath,
    );
    await hold?.future;
  }
}

RemoteProgress _candidate(
  String ncode, {
  required DateTime readAt,
  String device = 'iPad',
  int episode = 42,
  String? title,
}) {
  return RemoteProgress(
    deviceId: device,
    deviceName: device,
    record: SyncProgressRecord(
      novelId: 'narou_$ncode',
      episode: episode,
      fileName: '$episode.txt',
      bodyOffset: 0,
      bodyHash: null,
      readAt: readAt,
      url: 'https://ncode.syosetu.com/$ncode/',
      title: title ?? 'title $ncode',
    ),
  );
}

/// [count] candidates, `n0` read most recently.
List<RemoteProgress> _candidates(int count) => [
  for (var i = 0; i < count; i++)
    _candidate(
      'n$i',
      readAt: DateTime.utc(2026, 11, 20).subtract(Duration(hours: i)),
    ),
];

void main() {
  const root = '/tmp/test_novels';
  late _FakeDownloadNotifier download;

  setUp(() {
    download = _FakeDownloadNotifier();
  });

  Widget createApp({
    List<RemoteProgress>? candidates,
    bool available = true,
    SyncAccountState account = const SyncAccountState.signedIn('a@b.c'),
    Locale locale = const Locale('ja'),
  }) {
    return ProviderScope(
      overrides: [
        libraryPathProvider.overrideWithValue(root),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier(root),
        ),
        downloadProvider.overrideWith(() => download),
        downloadDestinationFoldersProvider.overrideWith(
          (ref) async => const <DirectoryEntry>[],
        ),
        progressSyncAvailableProvider.overrideWithValue(available),
        syncAccountStateProvider.overrideWithValue(account),
        progressSyncPulledProvider.overrideWithValue(const Stream.empty()),
        if (candidates != null)
          remoteNovelCandidatesProvider.overrideWith((ref) async => candidates),
      ],
      child: MaterialApp(
        locale: locale,
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

  final section = find.byKey(const Key('download_remote_novels'));
  final showAll = find.byKey(const Key('download_remote_novels_show_all'));
  Finder row(String ncode) =>
      find.byKey(Key('download_remote_novel_narou_$ncode'));

  String urlFieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first).controller!.text;

  group('the section is absent', () {
    testWidgets('with nothing to offer', (tester) async {
      await tester.pumpWidget(createApp(candidates: const []));
      await openDialog(tester);

      expect(section, findsNothing);
    });

    testWidgets('while signed out', (tester) async {
      await tester.pumpWidget(
        createApp(account: const SyncAccountState.signedOut()),
      );
      await openDialog(tester);

      expect(section, findsNothing);
    });

    testWidgets('in a build without sync', (tester) async {
      await tester.pumpWidget(createApp(available: false));
      await openDialog(tester);

      expect(section, findsNothing);
    });
  });

  testWidgets('shows the newest five and offers the rest', (tester) async {
    await tester.pumpWidget(createApp(candidates: _candidates(8)));
    await openDialog(tester);

    expect(section, findsOneWidget);
    expect(find.text('他の端末で読んでいる小説'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      expect(row('n$i'), findsOneWidget, reason: 'n$i');
    }
    expect(row('n5'), findsNothing);
    expect(find.text('すべて表示（8）'), findsOneWidget);

    // Newest first, top to bottom.
    final tops = [for (var i = 0; i < 5; i++) tester.getTopLeft(row('n$i')).dy];
    expect(tops, [...tops]..sort());
  });

  testWidgets('show all lists every novel', (tester) async {
    await tester.pumpWidget(createApp(candidates: _candidates(8)));
    await openDialog(tester);

    await tester.ensureVisible(showAll);
    await tester.tap(showAll);
    await tester.pumpAndSettle();

    expect(showAll, findsNothing);
    for (var i = 0; i < 8; i++) {
      await tester.scrollUntilVisible(
        row('n$i'),
        50,
        scrollable: find.descendant(
          of: section,
          matching: find.byType(Scrollable),
        ),
      );
      expect(row('n$i'), findsOneWidget, reason: 'n$i');
    }
  });

  testWidgets('five or fewer have no show all', (tester) async {
    await tester.pumpWidget(createApp(candidates: _candidates(3)));
    await openDialog(tester);

    expect(row('n2'), findsOneWidget);
    expect(showAll, findsNothing);
  });

  testWidgets('a row shows the title, device, episode and when', (
    tester,
  ) async {
    await tester.pumpWidget(
      createApp(
        candidates: [
          _candidate(
            'n1',
            readAt: DateTime(2026, 11, 22, 21, 10),
            title: 'ある物語',
          ),
        ],
      ),
    );
    await openDialog(tester);

    expect(
      find.descendant(of: row('n1'), matching: find.text('ある物語')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('n1'), matching: find.textContaining('iPad')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('n1'), matching: find.textContaining('42')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('n1'), matching: find.textContaining('21:10')),
      findsOneWidget,
    );
  });

  testWidgets('a row without a title shows the url', (tester) async {
    final untitled = RemoteProgress(
      deviceId: 'pad',
      deviceName: 'iPad',
      record: SyncProgressRecord(
        novelId: 'narou_n1',
        episode: 1,
        fileName: '1.txt',
        bodyOffset: 0,
        bodyHash: null,
        readAt: DateTime.utc(2026, 11, 1),
        url: 'https://ncode.syosetu.com/n1/',
      ),
    );
    await tester.pumpWidget(createApp(candidates: [untitled]));
    await openDialog(tester);

    expect(
      find.descendant(
        of: row('n1'),
        matching: find.text('https://ncode.syosetu.com/n1/'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a row with an empty title shows the url', (tester) async {
    final untitled = RemoteProgress(
      deviceId: 'pad',
      deviceName: 'iPad',
      record: SyncProgressRecord(
        novelId: 'narou_n1',
        episode: 1,
        fileName: '1.txt',
        bodyOffset: 0,
        bodyHash: null,
        readAt: DateTime.utc(2026, 11, 1),
        url: 'https://ncode.syosetu.com/n1/',
        title: '',
      ),
    );
    await tester.pumpWidget(createApp(candidates: [untitled]));
    await openDialog(tester);

    expect(
      find.descendant(
        of: row('n1'),
        matching: find.text('https://ncode.syosetu.com/n1/'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('choosing a row fills the url without downloading', (
    tester,
  ) async {
    await tester.pumpWidget(createApp(candidates: _candidates(2)));
    await openDialog(tester);

    await tester.tap(row('n1'));
    await tester.pumpAndSettle();

    expect(urlFieldText(tester), 'https://ncode.syosetu.com/n1/');
    expect(download.starts, isEmpty);
    final start = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'ダウンロード開始'),
    );
    expect(start.onPressed, isNotNull);
  });

  testWidgets('a row cannot be chosen while downloading', (tester) async {
    download.hold = Completer<void>();
    addTearDown(() => download.hold!.complete());
    await tester.pumpWidget(createApp(candidates: _candidates(2)));
    await openDialog(tester);
    await tester.tap(row('n0'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'ダウンロード開始'));
    await tester.pump();
    expect(download.state.status, DownloadStatus.downloading);

    await tester.tap(row('n1'), warnIfMissed: false);
    await tester.pump();

    expect(urlFieldText(tester), 'https://ncode.syosetu.com/n0/');
    expect(download.starts, [Uri.parse('https://ncode.syosetu.com/n0/')]);
  });

  testWidgets('many novels keep the dialog on a phone screen', (tester) async {
    usePhoneDisplay(tester);
    await tester.pumpWidget(createApp(candidates: _candidates(40)));
    await openDialog(tester);
    await tester.ensureVisible(showAll);
    await tester.tap(showAll);
    await tester.pumpAndSettle();

    final screen = Offset.zero & kPhoneDisplaySize;
    final dialog = tester.getRect(find.byType(AlertDialog));
    expect(screen.contains(dialog.topLeft), isTrue);
    expect(screen.contains(dialog.bottomRight - const Offset(1, 1)), isTrue);
    // The list scrolls inside its cap rather than pushing the field and the
    // start button away.
    expect(
      tester.getSize(section).height,
      lessThan(kPhoneDisplaySize.height / 2),
    );
    expect(find.byType(TextField), findsWidgets);
    expect(
      find.widgetWithText(ElevatedButton, 'ダウンロード開始').hitTestable(),
      findsOneWidget,
    );
  });

  for (final (locale, heading, showAllText) in [
    (const Locale('en'), 'Novels read on other devices', 'Show all (8)'),
    (const Locale('zh'), '在其他设备上阅读的小说', '显示全部（8）'),
  ]) {
    testWidgets('is localized in ${locale.languageCode}', (tester) async {
      await tester.pumpWidget(
        createApp(candidates: _candidates(8), locale: locale),
      );
      await openDialog(tester);

      expect(find.text(heading), findsOneWidget);
      expect(find.text(showAllText), findsOneWidget);
    });
  }
}
