import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_history_menu.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

WordSummary _snap(int episode, {DateTime? updatedAt}) => WordSummary(
      word: 'アリス',
      coveredUpToEpisode: episode,
      summary: '要約#$episode',
      sourceFile: '${episode.toString().padLeft(3, '0')}.txt',
      createdAt: updatedAt ?? DateTime.utc(2026, 5, 21),
      updatedAt: updatedAt ?? DateTime.utc(2026, 5, 21),
    );

HistoryEntry _entry(List<WordSummary> snapshots) =>
    HistoryEntry.mergeRows(snapshots).single;

Future<AppLocalizations> _loadL10n() async {
  return await AppLocalizations.delegate.load(const Locale('ja'));
}

void main() {
  group('pickTopSnapshotsForCopyMenu', () {
    test('returns snapshots sorted ascending when below the cap', () {
      final picked = pickTopSnapshotsForCopyMenu([
        _snap(30),
        _snap(10),
        _snap(20),
      ]);
      expect(picked.map((s) => s.coveredUpToEpisode).toList(), [10, 20, 30]);
    });

    test('caps to the most recently updated entries, sorted by episode asc',
        () {
      final now = DateTime.utc(2026, 5, 21, 12);
      final older = now.subtract(const Duration(hours: 1));
      final oldest = now.subtract(const Duration(hours: 2));
      // 9 entries: index 0 is oldest, 8 is newest by updatedAt
      final snapshots = [
        for (var i = 0; i < 9; i++)
          _snap(
            i + 1,
            updatedAt: now.subtract(Duration(minutes: (8 - i) * 10)),
          ),
      ];
      // Append two old ones to push count past 8, ensuring they're dropped.
      snapshots.add(_snap(100, updatedAt: oldest));
      snapshots.add(_snap(101, updatedAt: older));

      final picked = pickTopSnapshotsForCopyMenu(snapshots, max: 8);

      expect(picked, hasLength(8));
      // Lowest-recency entries (100, 101) should not appear.
      expect(picked.any((s) => s.coveredUpToEpisode == 100), isFalse);
      // Result should be sorted ascending by episode for display.
      for (var i = 1; i < picked.length; i++) {
        expect(
          picked[i].coveredUpToEpisode >= picked[i - 1].coveredUpToEpisode,
          isTrue,
        );
      }
    });
  });

  group('buildHistoryContextMenuItems', () {
    testWidgets(
        'builds one CopySnapshotAction per snapshot + a trailing delete entry',
        (tester) async {
      // pumpWidget so AppLocalizations can load via the delegate.
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(),
      ));
      await tester.pumpAndSettle();

      final l10n = await _loadL10n();
      final entry = _entry([_snap(10), _snap(30), _snap(60)]);

      final items =
          buildHistoryContextMenuItems(entry: entry, l10n: l10n);

      final copyActions = items
          .whereType<PopupMenuItem<HistoryContextAction>>()
          .where((i) => i.value is CopySnapshotAction)
          .map((i) => (i.value as CopySnapshotAction).episode)
          .toList();
      expect(copyActions, [10, 30, 60]);

      final hasDelete = items
          .whereType<PopupMenuItem<HistoryContextAction>>()
          .any((i) => i.value is DeleteEntryAction);
      expect(hasDelete, isTrue);
    });
  });

  group('dispatchHistoryContextAction', () {
    test('CopySnapshotAction invokes onCopy with the matching snapshot summary',
        () {
      final entry = _entry([_snap(10), _snap(30)]);
      String? captured;
      dispatchHistoryContextAction(
        const CopySnapshotAction(30),
        entry: entry,
        onCopy: (t) => captured = t,
        onDelete: () => fail('delete should not fire'),
      );
      expect(captured, '要約#30');
    });

    test('DeleteEntryAction invokes onDelete', () {
      var deleted = false;
      dispatchHistoryContextAction(
        const DeleteEntryAction(),
        entry: _entry([_snap(10)]),
        onCopy: (_) => fail('copy should not fire'),
        onDelete: () => deleted = true,
      );
      expect(deleted, isTrue);
    });

    test('CopySnapshotAction with no matching episode is a no-op', () {
      final entry = _entry([_snap(10)]);
      var copied = false;
      dispatchHistoryContextAction(
        const CopySnapshotAction(999),
        entry: entry,
        onCopy: (_) => copied = true,
        onDelete: () => fail('delete should not fire'),
      );
      expect(copied, isFalse);
    });
  });
}
