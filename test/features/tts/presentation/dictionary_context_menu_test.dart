import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/tts/presentation/dictionary_context_menu.dart';

void main() {
  group('buildAnalysisButtonItems', () {
    test('returns only the base items when the selection is empty', () {
      final base = [
        ContextMenuButtonItem(label: 'Copy', onPressed: () {}),
        ContextMenuButtonItem(label: 'Paste', onPressed: () {}),
      ];
      final result = buildAnalysisButtonItems(
        baseItems: base,
        selectedText: '',
        addToDictionaryLabel: '辞書追加',
        analyzeNoSpoilerLabel: '解析開始(ネタバレなし)',
        analyzeSpoilerLabel: '解析開始(ネタバレあり)',
        onAddToDictionary: (_) {},
        onAnalyze: (_, _) {},
      );
      expect(
        result.map((i) => i.label).toList(),
        equals(['Copy', 'Paste']),
      );
    });

    test(
        'appends dictionary + two analyze items when the selection is non-empty',
        () {
      final base = [
        ContextMenuButtonItem(label: 'Copy', onPressed: () {}),
      ];
      final result = buildAnalysisButtonItems(
        baseItems: base,
        selectedText: 'アリス',
        addToDictionaryLabel: '辞書追加',
        analyzeNoSpoilerLabel: '解析開始(ネタバレなし)',
        analyzeSpoilerLabel: '解析開始(ネタバレあり)',
        onAddToDictionary: (_) {},
        onAnalyze: (_, _) {},
      );
      expect(
        result.map((i) => i.label).toList(),
        equals([
          'Copy',
          '辞書追加',
          '解析開始(ネタバレなし)',
          '解析開始(ネタバレあり)',
        ]),
      );
    });

    test('the two analyze items pass the correct word + SummaryType', () {
      String? capturedWord;
      SummaryType? capturedType;
      final result = buildAnalysisButtonItems(
        baseItems: const [],
        selectedText: 'アリス',
        addToDictionaryLabel: '辞書追加',
        analyzeNoSpoilerLabel: '解析開始(ネタバレなし)',
        analyzeSpoilerLabel: '解析開始(ネタバレあり)',
        onAddToDictionary: (_) {},
        onAnalyze: (word, type) {
          capturedWord = word;
          capturedType = type;
        },
      );

      result
          .firstWhere((i) => i.label == '解析開始(ネタバレなし)')
          .onPressed!();
      expect(capturedWord, 'アリス');
      expect(capturedType, SummaryType.noSpoiler);

      result
          .firstWhere((i) => i.label == '解析開始(ネタバレあり)')
          .onPressed!();
      expect(capturedWord, 'アリス');
      expect(capturedType, SummaryType.spoiler);
    });

    test('the dictionary item invokes onAddToDictionary with the selection',
        () {
      String? captured;
      final result = buildAnalysisButtonItems(
        baseItems: const [],
        selectedText: 'アリス',
        addToDictionaryLabel: '辞書追加',
        analyzeNoSpoilerLabel: '解析開始(ネタバレなし)',
        analyzeSpoilerLabel: '解析開始(ネタバレあり)',
        onAddToDictionary: (w) => captured = w,
        onAnalyze: (_, _) {},
      );

      result.firstWhere((i) => i.label == '辞書追加').onPressed!();
      expect(captured, 'アリス');
    });

    test('a whitespace-only selection still produces all menu items', () {
      // Pins current behavior — the helper checks `.isNotEmpty`, not whether
      // the selection has non-whitespace content. Update if that ever changes.
      final result = buildAnalysisButtonItems(
        baseItems: const [],
        selectedText: '   ',
        addToDictionaryLabel: '辞書追加',
        analyzeNoSpoilerLabel: '解析開始(ネタバレなし)',
        analyzeSpoilerLabel: '解析開始(ネタバレあり)',
        onAddToDictionary: (_) {},
        onAnalyze: (_, _) {},
      );
      expect(result.map((i) => i.label).toList(), equals([
        '辞書追加',
        '解析開始(ネタバレなし)',
        '解析開始(ネタバレあり)',
      ]));
    });
  });

  group('buildDictionaryContextMenu (explicit selectedText)', () {
    // Reproduces the horizontal-mode bug: when ruby is selected,
    // `EditableTextState.textEditingValue.text` contains U+FFFC (the
    // WidgetSpan placeholder). The fixed API takes `selectedText` explicitly
    // so the caller can pass `extractSelectedText`-resolved text.

    testWidgets(
        'forwards the explicit selectedText to analyze handlers, ignoring U+FFFC in editableTextState',
        (tester) async {
      String? capturedWord;
      SummaryType? capturedType;

      // We render the toolbar inside a Material widget tree so it can resolve
      // theme/icon defaults. The TextField gives us a real `EditableTextState`
      // whose textEditingValue contains the U+FFFC placeholder, exactly as
      // SelectableText.rich does for ruby WidgetSpans.
      final controller = TextEditingController(text: '￼');
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 1);

      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                );
              },
            ),
          ),
        ),
      );

      // Focus the TextField so its EditableTextState becomes available.
      focusNode.requestFocus();
      await tester.pump();

      final editableState =
          tester.state<EditableTextState>(find.byType(EditableText));
      final menuContext = tester.element(find.byType(EditableText));

      final menu = buildDictionaryContextMenu(
        menuContext,
        editableState,
        selectedText: '宇宙',
        onAddToDictionary: (_) {},
        onAnalyze: (word, type) {
          capturedWord = word;
          capturedType = type;
        },
      );

      // Mount the returned menu so the buttons are tappable.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: menu)),
        ),
      );
      await tester.pump();

      expect(find.text('解析開始(ネタバレなし)'), findsOneWidget);
      await tester.tap(find.text('解析開始(ネタバレなし)'));
      await tester.pump();

      expect(capturedWord, '宇宙');
      expect(capturedWord, isNot(contains('￼')));
      expect(capturedType, SummaryType.noSpoiler);
    });

    testWidgets(
        'forwards the explicit selectedText to dictionary handler, ignoring U+FFFC',
        (tester) async {
      String? captured;

      final controller = TextEditingController(text: '￼');
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 1);

      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller, focusNode: focusNode),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final editableState =
          tester.state<EditableTextState>(find.byType(EditableText));
      final menuContext = tester.element(find.byType(EditableText));

      final menu = buildDictionaryContextMenu(
        menuContext,
        editableState,
        selectedText: '宇宙',
        onAddToDictionary: (word) => captured = word,
        onAnalyze: (_, _) {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: menu)),
        ),
      );
      await tester.pump();

      expect(find.text('辞書追加'), findsOneWidget);
      await tester.tap(find.text('辞書追加'));
      await tester.pump();

      expect(captured, '宇宙');
      expect(captured, isNot(contains('￼')));
    });

    testWidgets(
        'omits analyze + dictionary items when explicit selectedText is empty',
        (tester) async {
      // Even if editableTextState has a non-empty (U+FFFC) selection, the
      // explicit empty selectedText (e.g., caller decided extraction yielded
      // nothing) should suppress the menu items.
      final controller = TextEditingController(text: '￼');
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 1);
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller, focusNode: focusNode),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      final editableState =
          tester.state<EditableTextState>(find.byType(EditableText));
      final menuContext = tester.element(find.byType(EditableText));

      final menu = buildDictionaryContextMenu(
        menuContext,
        editableState,
        selectedText: '',
        onAddToDictionary: (_) {},
        onAnalyze: (_, _) {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: menu)),
        ),
      );
      await tester.pump();

      expect(find.text('辞書追加'), findsNothing);
      expect(find.text('解析開始(ネタバレなし)'), findsNothing);
      expect(find.text('解析開始(ネタバレあり)'), findsNothing);
    });
  });
}
