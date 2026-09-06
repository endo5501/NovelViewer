import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/presentation/analysis_runner.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/vertical_context_menu.dart';

void main() {
  group('buildVerticalContextMenuItems', () {
    test(
      'produces 4 entries: copy, addToDictionary, analyze(なし), analyze(あり)',
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
      },
    );

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

    test('omits the dictionary entry when its label is absent', () {
      final items = buildVerticalContextMenuItems(
        copyLabel: 'コピー',
        analyzeNoSpoilerLabel: '解析開始(ネタバレなし)',
        analyzeSpoilerLabel: '解析開始(ネタバレあり)',
      );
      final values = items
          .whereType<PopupMenuItem<VerticalContextAction>>()
          .map((i) => i.value)
          .toList();
      expect(values, [
        VerticalContextAction.copy,
        VerticalContextAction.analyzeNoSpoiler,
        VerticalContextAction.analyzeSpoiler,
      ]);
    });

    test('omits both analysis entries when their labels are absent', () {
      final items = buildVerticalContextMenuItems(
        copyLabel: 'コピー',
        addToDictionaryLabel: '辞書追加',
      );
      final values = items
          .whereType<PopupMenuItem<VerticalContextAction>>()
          .map((i) => i.value)
          .toList();
      expect(values, [
        VerticalContextAction.copy,
        VerticalContextAction.addToDictionary,
      ]);
    });

    test('copy alone remains when every optional label is absent', () {
      final items = buildVerticalContextMenuItems(copyLabel: 'コピー');
      final values = items
          .whereType<PopupMenuItem<VerticalContextAction>>()
          .map((i) => i.value)
          .toList();
      expect(values, [VerticalContextAction.copy]);
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
      AnalysisScope? capturedType;
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
      expect(capturedType, AnalysisScope.upToCurrent);
    });

    test('analyzeSpoiler → onAnalyze(selectedText, spoiler)', () {
      String? capturedWord;
      AnalysisScope? capturedType;
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
      expect(capturedType, AnalysisScope.upToAll);
    });
  });

  group('dispatchVerticalContextAction with withheld handlers', () {
    // The builder already omits an entry whose label is absent, so these
    // actions cannot be chosen through the UI. The dispatcher tolerating a
    // missing handler is the second layer: if a future change ever emits an
    // entry whose handler was withheld, it must do nothing rather than reach
    // the speech engine or an LLM server.
    test('a withheld dictionary handler makes the action a no-op', () {
      var analyzed = false;

      expect(
        () => dispatchVerticalContextAction(
          VerticalContextAction.addToDictionary,
          selectedText: 'アリス',
          onCopy: (_) {},
          onAnalyze: (_, _) => analyzed = true,
        ),
        returnsNormally,
      );
      expect(analyzed, isFalse);
    });

    test('a withheld analysis handler makes both actions no-ops', () {
      var addedToDictionary = false;

      for (final action in [
        VerticalContextAction.analyzeNoSpoiler,
        VerticalContextAction.analyzeSpoiler,
      ]) {
        expect(
          () => dispatchVerticalContextAction(
            action,
            selectedText: 'アリス',
            onCopy: (_) {},
            onAddToDictionary: (_) => addedToDictionary = true,
          ),
          returnsNormally,
        );
      }
      expect(addedToDictionary, isFalse);
    });

    test('copy still works when every optional handler is withheld', () {
      String? copied;

      dispatchVerticalContextAction(
        VerticalContextAction.copy,
        selectedText: 'アリス',
        onCopy: (t) => copied = t,
      );

      expect(copied, 'アリス');
    });
  });
}
