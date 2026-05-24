import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_history_panel.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);

  @override
  String? build() => _initialValue;
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
    testWidgets('shows placeholder when no novel is active',
        (tester) async {
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

    testWidgets('displays entries in updated_at descending order',
        (tester) async {
      final entries = [
        HistoryEntry(
          folderName: 'my_novel',
          word: '新しい単語',
          type: HistoryEntryType.spoilerOnly,
          summaryPreview: 'n',
          sourceFile: 'a.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 14),
        ),
        HistoryEntry(
          folderName: 'my_novel',
          word: '中間単語',
          type: HistoryEntryType.spoilerOnly,
          summaryPreview: 'm',
          sourceFile: 'b.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 12),
        ),
        HistoryEntry(
          folderName: 'my_novel',
          word: '古い単語',
          type: HistoryEntryType.spoilerOnly,
          summaryPreview: 'o',
          sourceFile: 'c.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
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

      final wordFinders = [
        find.text('新しい単語'),
        find.text('中間単語'),
        find.text('古い単語'),
      ];
      // Verify all three are present and in top-down order.
      final dys = wordFinders
          .map((f) => tester.getCenter(f).dy)
          .toList();
      expect(dys[0] < dys[1], isTrue,
          reason: '新しい should appear above 中間');
      expect(dys[1] < dys[2], isTrue,
          reason: '中間 should appear above 古い');
    });

    testWidgets('displays word, type badge, preview, and updated_at',
        (tester) async {
      final entries = [
        HistoryEntry(
          folderName: 'my_novel',
          word: 'アリス',
          type: HistoryEntryType.both,
          summaryPreview: 'アリスは王国の少女',
          sourceFile: '040.txt',
          updatedAt: DateTime.utc(2026, 5, 21, 14, 30),
        ),
        HistoryEntry(
          folderName: 'my_novel',
          word: 'ボブ',
          type: HistoryEntryType.noSpoilerOnly,
          summaryPreview: 'ボブは友人',
          sourceFile: '041.txt',
          updatedAt: DateTime.utc(2026, 5, 21, 12),
        ),
        HistoryEntry(
          folderName: 'my_novel',
          word: '聖印',
          type: HistoryEntryType.spoilerOnly,
          summaryPreview: '神聖な刻印',
          sourceFile: '042.txt',
          updatedAt: DateTime.utc(2026, 5, 21, 10),
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

      // Word
      expect(find.text('アリス'), findsOneWidget);
      expect(find.text('ボブ'), findsOneWidget);
      expect(find.text('聖印'), findsOneWidget);

      // Type badge (each label appears for one entry)
      expect(find.text('両'), findsOneWidget);
      expect(find.text('なし'), findsOneWidget);
      expect(find.text('あり'), findsOneWidget);

      // Preview
      expect(find.text('アリスは王国の少女'), findsOneWidget);
      expect(find.text('ボブは友人'), findsOneWidget);
      expect(find.text('神聖な刻印'), findsOneWidget);

      // Updated_at displayed in some form (we render YYYY-MM-DD as minimum)
      expect(find.textContaining('2026-05-21'), findsWidgets);
    });

    testWidgets('long summary preview is truncated with ellipsis',
        (tester) async {
      final longSummary = 'これは非常に長い要約テキストで、'
          '通常のリスト幅には収まらないため省略されます。' * 5;
      final entries = [
        HistoryEntry(
          folderName: 'my_novel',
          word: '長文',
          type: HistoryEntryType.spoilerOnly,
          summaryPreview: longSummary,
          sourceFile: 'a.txt',
          updatedAt: DateTime.utc(2026, 5, 21, 14),
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

      // The preview Text widget should have maxLines=1 and ellipsis overflow.
      final previewText = tester.widgetList<Text>(find.byType(Text)).firstWhere(
            (w) => w.data != null && w.data!.startsWith('これは非常に長い要約'),
            orElse: () => throw StateError('preview text not found'),
          );
      expect(previewText.maxLines, 1);
      expect(previewText.overflow, TextOverflow.ellipsis);
    });

    testWidgets(
        'untrackable entry (no sourceFile) is shown with an untracked badge '
        'and reduced opacity', (tester) async {
      final entries = [
        HistoryEntry(
          folderName: 'my_novel',
          word: '未追跡単語',
          type: HistoryEntryType.spoilerOnly,
          summaryPreview: '古いネタバレ要約',
          sourceFile: null,
          updatedAt: DateTime.utc(2026, 5, 21, 14),
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

      expect(find.text('未追跡'), findsOneWidget,
          reason: '未追跡 badge should appear for entries with null sourceFile');

      // The tile (or a wrapping widget) should reduce opacity. We look for an
      // Opacity widget below the entry tile.
      expect(
        find.descendant(
          of: find.byType(LlmSummaryHistoryPanel),
          matching: find.byType(Opacity),
        ),
        findsWidgets,
        reason: 'untracked entry should be wrapped in an Opacity widget',
      );
    });

    testWidgets('right-click shows context menu with delete option',
        (tester) async {
      final entries = [
        HistoryEntry(
          folderName: 'my_novel',
          word: 'アリス',
          type: HistoryEntryType.both,
          summaryPreview: 'アリスは少女',
          sourceFile: '040.txt',
          updatedAt: DateTime.utc(2026, 5, 21, 14),
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

      final wordItem = find.text('アリス');
      final center = tester.getCenter(wordItem);
      await tester.tapAt(center, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('削除'), findsOneWidget);
    });

    testWidgets(
        'right-click on a 両 entry shows both copy items + delete',
        (tester) async {
      final entries = [
        HistoryEntry(
          folderName: 'my_novel',
          word: 'アリス',
          type: HistoryEntryType.both,
          summaryPreview: 'プレビュー',
          noSpoilerSummary: 'なし本文',
          spoilerSummary: 'あり本文',
          sourceFile: '040.txt',
          updatedAt: DateTime.utc(2026, 5, 21, 14),
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

      await tester.tapAt(tester.getCenter(find.text('アリス')),
          buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('要約をコピー(ネタバレなし)'), findsOneWidget);
      expect(find.text('要約をコピー(ネタバレあり)'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);
    });

    testWidgets(
        'right-click on a noSpoilerOnly entry shows only copy(なし) + delete',
        (tester) async {
      final entries = [
        HistoryEntry(
          folderName: 'my_novel',
          word: 'ボブ',
          type: HistoryEntryType.noSpoilerOnly,
          summaryPreview: 'プレビュー',
          noSpoilerSummary: 'ボブ本文',
          sourceFile: '040.txt',
          updatedAt: DateTime.utc(2026, 5, 21, 14),
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

      await tester.tapAt(tester.getCenter(find.text('ボブ')),
          buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('要約をコピー(ネタバレなし)'), findsOneWidget);
      expect(find.text('要約をコピー(ネタバレあり)'), findsNothing);
      expect(find.text('削除'), findsOneWidget);
    });

    testWidgets(
        'right-click on a spoilerOnly entry shows only copy(あり) + delete',
        (tester) async {
      final entries = [
        HistoryEntry(
          folderName: 'my_novel',
          word: '聖印',
          type: HistoryEntryType.spoilerOnly,
          summaryPreview: 'プレビュー',
          spoilerSummary: '聖印本文',
          sourceFile: '040.txt',
          updatedAt: DateTime.utc(2026, 5, 21, 14),
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

      await tester.tapAt(tester.getCenter(find.text('聖印')),
          buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('要約をコピー(ネタバレなし)'), findsNothing);
      expect(find.text('要約をコピー(ネタバレあり)'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);
    });

    testWidgets(
        'selecting copy(なし) writes the no-spoiler text to the clipboard '
        'and shows a confirmation SnackBar', (tester) async {
      String? clipboardText;
      final binding = TestDefaultBinaryMessengerBinding.instance;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final entries = [
        HistoryEntry(
          folderName: 'my_novel',
          word: 'アリス',
          type: HistoryEntryType.both,
          summaryPreview: 'プレビュー',
          noSpoilerSummary: 'なし本文',
          spoilerSummary: 'あり本文',
          sourceFile: '040.txt',
          updatedAt: DateTime.utc(2026, 5, 21, 14),
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

      await tester.tapAt(tester.getCenter(find.text('アリス')),
          buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('要約をコピー(ネタバレなし)'));
      await tester.pumpAndSettle();

      expect(clipboardText, 'なし本文');
      expect(find.text('クリップボードにコピーしました'), findsOneWidget);
    });

    testWidgets('selecting copy(あり) writes the spoiler text to the clipboard',
        (tester) async {
      String? clipboardText;
      final binding = TestDefaultBinaryMessengerBinding.instance;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final entries = [
        HistoryEntry(
          folderName: 'my_novel',
          word: 'アリス',
          type: HistoryEntryType.both,
          summaryPreview: 'プレビュー',
          noSpoilerSummary: 'なし本文',
          spoilerSummary: 'あり本文',
          sourceFile: '040.txt',
          updatedAt: DateTime.utc(2026, 5, 21, 14),
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

      await tester.tapAt(tester.getCenter(find.text('アリス')),
          buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('要約をコピー(ネタバレあり)'));
      await tester.pumpAndSettle();

      expect(clipboardText, 'あり本文');
    });
  });
}

class _StubHistoryNotifier extends LlmSummaryHistoryNotifier {
  final List<HistoryEntry> _entries;
  _StubHistoryNotifier(this._entries);

  @override
  Future<List<HistoryEntry>> build() async => _entries;
}
