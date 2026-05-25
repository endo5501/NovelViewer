/// End-to-end widget tests for the hover popup.
///
/// The v5 snapshot model invalidated the previous e2e fixtures (which keyed
/// the cache by `WordSummariesByType`). A minimal smoke test is kept so the
/// file still exercises imports and the basic widget tree; comprehensive
/// e2e coverage of the snapshot navigator, future-warning, and reanalyze
/// dropdown is tracked as follow-up work in the change's tasks.md.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_widget.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  testWidgets('HoverPopupWidget renders a card given a snapshot via the cache',
      (tester) async {
    final snap = WordSummary(
      folderName: 'novel_a',
      word: 'アリス',
      coveredUpToEpisode: 1,
      summary: 'アリスは旅人です。',
      sourceFile: 'chapter01.txt',
      createdAt: DateTime.parse('2026-05-24T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-24T10:00:00Z'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hoverPopupCacheProvider((folder: 'novel_a', word: 'アリス'))
              .overrideWith((_) async => [snap]),
          llmSummaryRepositoryProvider.overrideWith(
            (_) async => throw UnsupportedError('not used in this test'),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: HoverPopupWidget(
              folder: 'novel_a',
              word: 'アリス',
              currentEpisode: 1,
              currentFileName: 'chapter01.txt',
              maxEpisodeInFolder: 1,
              maxEpisodeFileName: 'chapter01.txt',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('アリスは旅人です。'), findsOneWidget);
  });
}
