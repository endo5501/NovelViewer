import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_history_panel.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Counts the builds so a test can assert the panel never asked the history
/// provider for anything — asking is what opens (and therefore creates) a
/// `novel_data.db`.
class _RecordingHistoryNotifier extends LlmSummaryHistoryNotifier {
  static int builds = 0;

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

Future<void> _pumpAt(WidgetTester tester, String directory) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryPathProvider.overrideWithValue('/library'),
        allNovelsProvider.overrideWith(
          (ref) async => [_novel('narou_n1234ab')],
        ),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier(directory),
        ),
        llmSummaryHistoryProvider.overrideWith(_RecordingHistoryNotifier.new),
      ],
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

void main() {
  setUp(() => _RecordingHistoryNotifier.builds = 0);

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

    testWidgets('小説フォルダ内のサブフォルダでも履歴を表示する', (tester) async {
      await _pumpAt(tester, '/library/narou_n1234ab/第二部');

      expect(find.text('アリス'), findsOneWidget);
      expect(_RecordingHistoryNotifier.builds, 1);
    });
  });
}
