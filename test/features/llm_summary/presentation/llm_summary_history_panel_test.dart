import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_history_panel.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);

  @override
  String? build() => _initialValue;
}

class _StubHistoryNotifier extends LlmSummaryHistoryNotifier {
  final List<HistoryEntry> _entries;
  _StubHistoryNotifier(this._entries);

  @override
  Future<List<HistoryEntry>> build() async => _entries;
}

HistoryEntry _entry({
  required String word,
  required int episode,
  String? sourceFile,
  int extraSnapshots = 0,
}) {
  final base = WordSummary(
    folderName: 'my_novel',
    word: word,
    coveredUpToEpisode: episode,
    summary: '${word}の要約',
    sourceFile: sourceFile,
    createdAt: DateTime.utc(2026, 5, 21),
    updatedAt: DateTime.utc(2026, 5, 21),
  );
  final all = [
    base,
    for (var i = 1; i <= extraSnapshots; i++)
      WordSummary(
        folderName: 'my_novel',
        word: word,
        coveredUpToEpisode: episode + i * 10,
        summary: '${word}の追加要約 #$i',
        sourceFile: '${(episode + i * 10).toString().padLeft(3, '0')}.txt',
        createdAt: DateTime.utc(2026, 5, 21),
        updatedAt: DateTime.utc(2026, 5, 21),
      ),
  ];
  return HistoryEntry.mergeRows(all).single;
}

Widget _wrap({required List<Object> overrides}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: const MaterialApp(
      locale: Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: LlmSummaryHistoryPanel()),
    ),
  );
}

void main() {
  group('LlmSummaryHistoryPanel', () {
    testWidgets('shows placeholder when no novel is active', (tester) async {
      await tester.pumpWidget(_wrap(
        overrides: [
          libraryPathProvider.overrideWithValue('/library'),
          currentDirectoryProvider
              .overrideWith(() => _TestCurrentDirectoryNotifier('/library')),
          llmSummaryHistoryProvider
              .overrideWith(() => _StubHistoryNotifier(const [])),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('作品フォルダを選択してください'), findsOneWidget);
    });

    testWidgets('shows empty message when no history entries exist',
        (tester) async {
      await tester.pumpWidget(_wrap(
        overrides: [
          libraryPathProvider.overrideWithValue('/library'),
          currentDirectoryProvider.overrideWith(
              () => _TestCurrentDirectoryNotifier('/library/my_novel')),
          llmSummaryHistoryProvider
              .overrideWith(() => _StubHistoryNotifier(const [])),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('解析履歴がありません'), findsOneWidget);
    });

    testWidgets('renders a snapshot-count badge for each entry',
        (tester) async {
      final entries = [
        _entry(word: 'アリス', episode: 30, sourceFile: '030.txt'),
        _entry(
          word: 'ボブ',
          episode: 10,
          sourceFile: '010.txt',
          extraSnapshots: 2, // -> total 3 snapshots
        ),
      ];

      await tester.pumpWidget(_wrap(
        overrides: [
          libraryPathProvider.overrideWithValue('/library'),
          currentDirectoryProvider.overrideWith(
              () => _TestCurrentDirectoryNotifier('/library/my_novel')),
          llmSummaryHistoryProvider
              .overrideWith(() => _StubHistoryNotifier(entries)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('アリス'), findsOneWidget);
      expect(find.text('ボブ'), findsOneWidget);
      expect(find.text('1スナップショット'), findsOneWidget,
          reason: 'アリス has a single snapshot');
      expect(find.text('3スナップショット'), findsOneWidget,
          reason: 'ボブ has 1 base + 2 extra snapshots');
    });
  });
}
