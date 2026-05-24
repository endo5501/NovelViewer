import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_history_menu.dart';

void main() {
  group('buildHistoryContextMenuItems', () {
    test('noSpoilerOnly type: shows [copy(なし), delete]', () {
      final items = buildHistoryContextMenuItems(
        type: HistoryEntryType.noSpoilerOnly,
        deleteLabel: '削除',
        copyNoSpoilerLabel: '要約をコピー(ネタバレなし)',
        copySpoilerLabel: '要約をコピー(ネタバレあり)',
      );
      final values = items
          .whereType<PopupMenuItem<HistoryContextAction>>()
          .map((i) => i.value)
          .toList();
      expect(values, [
        HistoryContextAction.copyNoSpoiler,
        HistoryContextAction.delete,
      ]);
    });

    test('spoilerOnly type: shows [copy(あり), delete]', () {
      final items = buildHistoryContextMenuItems(
        type: HistoryEntryType.spoilerOnly,
        deleteLabel: '削除',
        copyNoSpoilerLabel: '要約をコピー(ネタバレなし)',
        copySpoilerLabel: '要約をコピー(ネタバレあり)',
      );
      final values = items
          .whereType<PopupMenuItem<HistoryContextAction>>()
          .map((i) => i.value)
          .toList();
      expect(values, [
        HistoryContextAction.copySpoiler,
        HistoryContextAction.delete,
      ]);
    });

    test('both type: shows [copy(なし), copy(あり), delete]', () {
      final items = buildHistoryContextMenuItems(
        type: HistoryEntryType.both,
        deleteLabel: '削除',
        copyNoSpoilerLabel: '要約をコピー(ネタバレなし)',
        copySpoilerLabel: '要約をコピー(ネタバレあり)',
      );
      final values = items
          .whereType<PopupMenuItem<HistoryContextAction>>()
          .map((i) => i.value)
          .toList();
      expect(values, [
        HistoryContextAction.copyNoSpoiler,
        HistoryContextAction.copySpoiler,
        HistoryContextAction.delete,
      ]);
    });
  });

  group('dispatchHistoryContextAction', () {
    test('copyNoSpoiler routes to onCopy with the no-spoiler text', () {
      String? captured;
      dispatchHistoryContextAction(
        HistoryContextAction.copyNoSpoiler,
        noSpoilerSummary: 'なし本文',
        spoilerSummary: 'あり本文',
        onCopy: (t) => captured = t,
        onDelete: () => fail('delete should not fire'),
      );
      expect(captured, 'なし本文');
    });

    test('copySpoiler routes to onCopy with the spoiler text', () {
      String? captured;
      dispatchHistoryContextAction(
        HistoryContextAction.copySpoiler,
        noSpoilerSummary: 'なし本文',
        spoilerSummary: 'あり本文',
        onCopy: (t) => captured = t,
        onDelete: () => fail('delete should not fire'),
      );
      expect(captured, 'あり本文');
    });

    test('delete routes to onDelete', () {
      var deleted = false;
      dispatchHistoryContextAction(
        HistoryContextAction.delete,
        noSpoilerSummary: 'a',
        spoilerSummary: 'b',
        onCopy: (_) => fail('copy should not fire'),
        onDelete: () => deleted = true,
      );
      expect(deleted, isTrue);
    });

    test('copy actions are no-ops when the corresponding text is null', () {
      // Defensive: the menu items will only be shown when the corresponding
      // text exists, but the dispatcher must not crash if invoked anyway.
      var called = false;
      dispatchHistoryContextAction(
        HistoryContextAction.copyNoSpoiler,
        noSpoilerSummary: null,
        spoilerSummary: 'b',
        onCopy: (_) => called = true,
        onDelete: () => fail('delete should not fire'),
      );
      expect(called, isFalse);
    });
  });
}
