import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_widget.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Minimal-coverage replacement for the v5 snapshot model. Detailed
// scenarios (toggle behavior, reanalysis menu overwrite suffixes, theme
// boundary rendering) are tracked as a follow-up in the change's tasks.md
// and will be reintroduced when the widget API stabilizes.

ProviderScope _scopedWith({
  required Widget child,
  required List<WordSummary> snapshots,
}) {
  return ProviderScope(
    overrides: [
      hoverPopupCacheProvider(
        (folder: 'novel_a', word: 'アリス'),
      ).overrideWith((_) async => snapshots),
      llmSummaryRepositoryProvider.overrideWith(
        (_) async => throw UnsupportedError('not needed in this test'),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Material(child: child),
    ),
  );
}

WordSummary _snap(int episode, String text) => WordSummary(
      folderName: 'novel_a',
      word: 'アリス',
      coveredUpToEpisode: episode,
      summary: text,
      sourceFile: '${episode.toString().padLeft(3, '0')}.txt',
      createdAt: DateTime.utc(2026, 5, 21),
      updatedAt: DateTime.utc(2026, 5, 21),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('HoverPopupWidget', () {
    testWidgets('hidden when there are no snapshots', (tester) async {
      await tester.pumpWidget(_scopedWith(
        snapshots: const [],
        child: const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentEpisode: 5,
          currentFileName: '005.txt',
          maxEpisodeInFolder: 10,
          maxEpisodeFileName: '010.txt',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hover_popup_card')), findsNothing);
    });

    testWidgets('renders the default snapshot label and summary text',
        (tester) async {
      await tester.pumpWidget(_scopedWith(
        snapshots: [_snap(3, '序盤要約'), _snap(9, '中盤要約')],
        child: const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentEpisode: 6,
          currentFileName: '006.txt',
          maxEpisodeInFolder: 9,
          maxEpisodeFileName: '009.txt',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hover_popup_card')), findsOneWidget);
      expect(find.text('序盤要約'), findsOneWidget,
          reason: 'default = max{Sᵢ | Sᵢ ≤ 6} = 3');
      expect(find.text('3ファイル時点の要約'), findsOneWidget);
    });

    testWidgets('shows the future warning icon when only future snapshots exist',
        (tester) async {
      await tester.pumpWidget(_scopedWith(
        snapshots: [_snap(9, '先の要約')],
        child: const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentEpisode: 6,
          currentFileName: '006.txt',
          maxEpisodeInFolder: 9,
          maxEpisodeFileName: '009.txt',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hover_popup_future_warning')),
          findsOneWidget);
      expect(find.text('先の要約'), findsOneWidget);
    });

    testWidgets('arrow buttons are disabled when only one snapshot exists',
        (tester) async {
      await tester.pumpWidget(_scopedWith(
        snapshots: [_snap(5, 'only')],
        child: const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentEpisode: 5,
          currentFileName: '005.txt',
          maxEpisodeInFolder: 5,
          maxEpisodeFileName: '005.txt',
        ),
      ));
      await tester.pumpAndSettle();

      final prev = tester.widget<IconButton>(
          find.byKey(const Key('hover_popup_snapshot_prev')));
      final next = tester.widget<IconButton>(
          find.byKey(const Key('hover_popup_snapshot_next')));
      expect(prev.onPressed, isNull);
      expect(next.onPressed, isNull);
    });
  });

  group('shouldAppendOverwriteSuffix', () {
    test('returns true when an existing snapshot matches the candidate', () {
      expect(
        shouldAppendOverwriteSuffix(
          [_snap(3, ''), _snap(9, '')],
          3,
        ),
        isTrue,
      );
    });

    test('returns false when no snapshot matches the candidate', () {
      expect(
        shouldAppendOverwriteSuffix([_snap(3, ''), _snap(9, '')], 10),
        isFalse,
      );
    });

    test('returns false on empty snapshot list', () {
      expect(shouldAppendOverwriteSuffix(const [], 1), isFalse);
    });
  });
}
