import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/vertical_context_menu.dart';

void main() {
  group('buildVerticalContextMenuItems', () {
    test('produces 4 entries: copy, addToDictionary, analyze(なし), analyze(あり)',
        () {
      final items = buildVerticalContextMenuItems(
        copyLabel: 'コピー',
        addToDictionaryLabel: '辞書追加',
        analyzeNoSpoilerLabel: '解析開始(ネタバレなし)',
        analyzeSpoilerLabel: '解析開始(ネタバレあり)',
      );
      expect(items, hasLength(4));
      final values = items
          .whereType<PopupMenuItem<VerticalContextAction>>()
          .map((i) => i.value)
          .toList();
      expect(values, [
        VerticalContextAction.copy,
        VerticalContextAction.addToDictionary,
        VerticalContextAction.analyzeNoSpoiler,
        VerticalContextAction.analyzeSpoiler,
      ]);
    });

    testWidgets('items display their labels', (tester) async {
      final items = buildVerticalContextMenuItems(
        copyLabel: 'コピー',
        addToDictionaryLabel: '辞書追加',
        analyzeNoSpoilerLabel: '解析開始(ネタバレなし)',
        analyzeSpoilerLabel: '解析開始(ネタバレあり)',
      );
      // Wrap items in a Material/MediaQuery so Text widgets can render.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: items
                  .whereType<PopupMenuItem<VerticalContextAction>>()
                  .map((e) => e.child ?? const SizedBox())
                  .toList(),
            ),
          ),
        ),
      );

      expect(find.text('コピー'), findsOneWidget);
      expect(find.text('辞書追加'), findsOneWidget);
      expect(find.text('解析開始(ネタバレなし)'), findsOneWidget);
      expect(find.text('解析開始(ネタバレあり)'), findsOneWidget);
    });
  });

  group('dispatchVerticalContextAction', () {
    test('copy → onCopy(selectedText)', () {
      String? captured;
      dispatchVerticalContextAction(
        VerticalContextAction.copy,
        selectedText: 'アリス',
        onCopy: (t) => captured = t,
        onAddToDictionary: (_) => fail('addToDictionary should not fire'),
        onAnalyze: (_, _) => fail('analyze should not fire'),
      );
      expect(captured, 'アリス');
    });

    test('addToDictionary → onAddToDictionary(selectedText)', () {
      String? captured;
      dispatchVerticalContextAction(
        VerticalContextAction.addToDictionary,
        selectedText: 'アリス',
        onCopy: (_) => fail('copy should not fire'),
        onAddToDictionary: (t) => captured = t,
        onAnalyze: (_, _) => fail('analyze should not fire'),
      );
      expect(captured, 'アリス');
    });

    test('analyzeNoSpoiler → onAnalyze(selectedText, noSpoiler)', () {
      String? capturedWord;
      SummaryType? capturedType;
      dispatchVerticalContextAction(
        VerticalContextAction.analyzeNoSpoiler,
        selectedText: 'アリス',
        onCopy: (_) => fail('copy should not fire'),
        onAddToDictionary: (_) => fail('addToDictionary should not fire'),
        onAnalyze: (w, t) {
          capturedWord = w;
          capturedType = t;
        },
      );
      expect(capturedWord, 'アリス');
      expect(capturedType, SummaryType.noSpoiler);
    });

    test('analyzeSpoiler → onAnalyze(selectedText, spoiler)', () {
      String? capturedWord;
      SummaryType? capturedType;
      dispatchVerticalContextAction(
        VerticalContextAction.analyzeSpoiler,
        selectedText: 'アリス',
        onCopy: (_) => fail('copy should not fire'),
        onAddToDictionary: (_) => fail('addToDictionary should not fire'),
        onAnalyze: (w, t) {
          capturedWord = w;
          capturedType = t;
        },
      );
      expect(capturedWord, 'アリス');
      expect(capturedType, SummaryType.spoiler);
    });
  });
}
