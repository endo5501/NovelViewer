import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_detail_dialog.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_history_panel.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_detail_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Counts the builds so a test can assert the panel never asked the history
/// provider for anything — asking is what opens (and therefore creates) a
/// `novel_data.db`.
class _RecordingHistoryNotifier extends LlmSummaryHistoryNotifier {
  static int builds = 0;

  /// Every folder a delete was aimed at, so a test can assert which novel the
  /// panel handed over rather than trusting that it handed over anything.
  static final List<String> deleteFolders = [];

  @override
  Future<void> deleteEntry(String word, {required String novelFolder}) async {
    deleteFolders.add(novelFolder);
  }

  @override
  Future<List<HistoryEntry>> build() async {
    builds++;
    return [
      HistoryEntry.mergeRows([
        WordSummary(
          word: 'アリス',
          coveredUpToEpisode: 10,
          summary: 'アリスの要約',
          sourceFile: '010.txt',
          createdAt: DateTime.utc(2026, 5, 21),
          updatedAt: DateTime.utc(2026, 5, 21),
        ),
      ]).single,
    ];
  }
}

NovelMetadata _novel(String folderName) => NovelMetadata(
  siteType: 'narou',
  novelId: folderName,
  title: 'Title $folderName',
  url: 'https://ncode.syosetu.com/$folderName/',
  folderName: folderName,
  episodeCount: 3,
  downloadedAt: DateTime(2024, 1, 1),
);

ProviderContainer _containerAt(String directory) {
  return ProviderContainer(
    overrides: [
      libraryPathProvider.overrideWithValue('/library'),
      allNovelsProvider.overrideWith(
        (ref) => [_novel('narou_n1234ab'), _novel('narou_n5678cd')],
      ),
      currentDirectoryProvider.overrideWith(
        () => CurrentDirectoryNotifier(directory),
      ),
      llmSummaryHistoryProvider.overrideWith(_RecordingHistoryNotifier.new),
      // Keeps the detail dialog off the filesystem whichever folder it is
      // handed; the test asserts on the folder it was handed, not on rows.
      historyDetailFactsProvider.overrideWith((ref, key) async => const []),
    ],
  );
}

Future<void> _pumpContainer(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LlmSummaryHistoryPanel()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpAt(WidgetTester tester, String directory) async {
  final container = _containerAt(directory);
  addTearDown(container.dispose);
  await _pumpContainer(tester, container);
}

Future<void> _openContextMenu(WidgetTester tester) async {
  final target = tester.getCenter(find.text('アリス'));
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await gesture.addPointer(location: target);
  await tester.pump();
  await gesture.down(target);
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    _RecordingHistoryNotifier.builds = 0;
    _RecordingHistoryNotifier.deleteFolders.clear();
  });

  group('LlmSummaryHistoryPanel の対象フォルダ', () {
    testWidgets('整理フォルダでは案内を出し、履歴を要求しない', (tester) async {
      await _pumpAt(tester, '/library/完結済み');

      expect(find.text('作品フォルダを選択してください'), findsOneWidget);
      expect(find.text('アリス'), findsNothing);
      expect(_RecordingHistoryNotifier.builds, 0);
    });

    testWidgets('ライブラリルートでは案内を出し、履歴を要求しない', (tester) async {
      await _pumpAt(tester, '/library');

      expect(find.text('作品フォルダを選択してください'), findsOneWidget);
      expect(_RecordingHistoryNotifier.builds, 0);
    });

    testWidgets('入れ子の小説フォルダでは履歴を表示する', (tester) async {
      await _pumpAt(tester, '/library/完結済み/narou_n1234ab');

      expect(find.text('アリス'), findsOneWidget);
      expect(_RecordingHistoryNotifier.builds, 1);
    });

    testWidgets('小説フォルダ内のサブフォルダでは案内を出し、履歴を要求しない', (tester) async {
      await _pumpAt(tester, '/library/narou_n1234ab/第二部');

      expect(find.text('作品フォルダを選択してください'), findsOneWidget);
      expect(find.text('アリス'), findsNothing);
      expect(_RecordingHistoryNotifier.builds, 0);
    });

    testWidgets('メニューを開いた後にブラウザが動いても、削除は一覧の小説に向く', (tester) async {
      // The folder reaches the notifier as a parameter, and what makes that
      // the list's own folder is that the callback holds the widget the list
      // was drawn with. A rebuild under the open menu produces a new widget
      // carrying the new folder; the callback must not be looking at it.
      final container = _containerAt('/library/narou_n1234ab');
      addTearDown(container.dispose);
      await _pumpContainer(tester, container);

      await _openContextMenu(tester);

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory('/library/narou_n5678cd');
      await tester.pumpAndSettle();

      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();

      expect(_RecordingHistoryNotifier.deleteFolders, [
        '/library/narou_n1234ab',
      ]);
    });

    testWidgets('詳細ダイアログには小説フォルダが渡される', (tester) async {
      await _pumpAt(tester, '/library/narou_n1234ab');

      await _openContextMenu(tester);

      await tester.tap(find.text('詳細を表示'));
      await tester.pumpAndSettle();

      final dialog = tester.widget<LlmSummaryDetailDialog>(
        find.byType(LlmSummaryDetailDialog),
      );
      expect(dialog.folderPath, '/library/narou_n1234ab');
    });
  });
}
