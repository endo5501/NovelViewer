import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_detail_dialog.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_detail_provider.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

FactCacheEntry _fact(
  String file,
  String facts, {
  String hash = 'h',
}) =>
    FactCacheEntry(
      word: 'アリス',
      fileName: file,
      facts: facts,
      contentHash: hash,
      promptVersion: 1,
      updatedAt: DateTime.utc(2026, 5, 21),
    );

WordSummary _snap(int episode, String text) => WordSummary(
      word: 'アリス',
      coveredUpToEpisode: episode,
      summary: text,
      sourceFile: '${episode.toString().padLeft(3, '0')}.txt',
      createdAt: DateTime.utc(2026, 5, 21),
      updatedAt: DateTime.utc(2026, 5, 21),
    );

Widget _harness({
  required List<FactCacheEntry> facts,
  required List<WordSummary> snapshots,
}) {
  return ProviderScope(
    overrides: [
      historyDetailFactsProvider(
        (folderPath: 'novel_a', word: 'アリス'),
      ).overrideWith((_) async => facts),
      hoverPopupCacheProvider(
        (folderPath: 'novel_a', word: 'アリス'),
      ).overrideWith((_) async => snapshots),
    ],
    child: const MaterialApp(
      locale: Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: LlmSummaryDetailDialog(folderPath: 'novel_a', word: 'アリス'),
      ),
    ),
  );
}

void main() {
  group('dialog scaffold', () {
    testWidgets(
        'shows two tabs with the facts tab initially selected and the word '
        'in the title', (tester) async {
      await tester.pumpWidget(_harness(
        facts: [_fact('001.txt', '・髪は金色')],
        snapshots: [_snap(10, '要約#10')],
      ));
      await tester.pumpAndSettle();

      expect(find.text('「アリス」の詳細'), findsOneWidget);
      expect(find.text('事実'), findsOneWidget);
      expect(find.text('解析結果'), findsOneWidget);
      expect(find.text('・髪は金色'), findsOneWidget);

      final controller = DefaultTabController.of(
        tester.element(find.byType(TabBar)),
      );
      expect(controller.index, 0);
    });
  });

  group('facts tab', () {
    testWidgets('lists files in ascending order with their facts',
        (tester) async {
      await tester.pumpWidget(_harness(
        facts: [
          _fact('002.txt', '・王国出身'),
          _fact('001.txt', '・髪は金色'),
        ],
        snapshots: [_snap(10, '要約#10')],
      ));
      await tester.pumpAndSettle();

      expect(find.text('・髪は金色'), findsOneWidget);
      expect(find.text('・王国出身'), findsOneWidget);

      // Ascending by file name: 001.txt header sits above 002.txt header.
      final y001 = tester.getTopLeft(find.text('001.txt')).dy;
      final y002 = tester.getTopLeft(find.text('002.txt')).dy;
      expect(y001, lessThan(y002));
    });

    testWidgets('shows empty message when no facts exist', (tester) async {
      await tester.pumpWidget(_harness(
        facts: const [],
        snapshots: [_snap(10, '要約#10')],
      ));
      await tester.pumpAndSettle();

      expect(find.text('事実がありません'), findsOneWidget);
    });

    testWidgets('keeps invalidated facts in the list, greyed with a badge',
        (tester) async {
      await tester.pumpWidget(_harness(
        facts: [
          _fact('001.txt', '・有効な事実'),
          _fact('002.txt', '・無効な事実',
              hash: FactCacheRepository.sentinelHash),
        ],
        snapshots: [_snap(10, '要約#10')],
      ));
      await tester.pumpAndSettle();

      // Invalid row is NOT dropped.
      expect(find.text('・無効な事実'), findsOneWidget);
      // Invalid badge present exactly once.
      expect(find.text('無効'), findsOneWidget);

      // Invalid section is greyed (wrapped in a low-opacity Opacity).
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('・無効な事実'),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, lessThan(1.0));

      // Valid section is NOT greyed (no low-opacity Opacity ancestor).
      expect(
        find.ancestor(
          of: find.text('・有効な事実'),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });
  });

  group('result tab', () {
    testWidgets('shows the latest snapshot and navigates between snapshots',
        (tester) async {
      await tester.pumpWidget(_harness(
        facts: const [],
        snapshots: [_snap(10, '要約#10'), _snap(20, '要約#20')],
      ));
      await tester.pumpAndSettle();

      // Switch to the analysis-result tab.
      await tester.tap(find.text('解析結果'));
      await tester.pumpAndSettle();

      // Latest snapshot shown by default.
      expect(find.text('要約#20'), findsOneWidget);

      // Navigate to the previous snapshot.
      await tester.tap(
        find.byKey(const Key('history_detail_snapshot_prev')),
      );
      await tester.pumpAndSettle();
      expect(find.text('要約#10'), findsOneWidget);
    });

    testWidgets('shows empty message when no snapshots exist', (tester) async {
      await tester.pumpWidget(_harness(
        facts: const [],
        snapshots: const [],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('解析結果'));
      await tester.pumpAndSettle();

      expect(find.text('解析結果がありません'), findsOneWidget);
    });
  });

  group('read-only invariants', () {
    testWidgets('offers no re-analyze or delete affordances', (tester) async {
      await tester.pumpWidget(_harness(
        facts: [_fact('001.txt', '・髪は金色')],
        snapshots: [_snap(10, '要約#10'), _snap(20, '要約#20')],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('解析結果'));
      await tester.pumpAndSettle();

      // The hover popup's re-analyze button must not be reused here.
      expect(find.byKey(const Key('hover_popup_reanalyze_button')),
          findsNothing);
      // No re-analyze (refresh) or delete icons anywhere in the dialog.
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);

      // Navigating snapshots does not throw and stays read-only.
      await tester.tap(
        find.byKey(const Key('history_detail_snapshot_prev')),
      );
      await tester.pumpAndSettle();
      expect(find.text('要約#10'), findsOneWidget);
    });
  });
}
