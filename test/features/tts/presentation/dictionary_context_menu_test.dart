import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/tts/presentation/dictionary_context_menu.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

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

    testWidgets(
        'rewrites the system Copy item to copy the explicit selectedText to the clipboard, ignoring the base onPressed (which would leak U+FFFC)',
        (tester) async {
      // Repro: in horizontal mode, the base "Copy" item from Flutter's
      // toolbar resolves text via EditableText.copySelection ->
      // value.text.textInside(...), which leaks U+FFFC for ruby
      // WidgetSpans. After the fix, the base Copy item must be remapped
      // so its onPressed copies the explicit ruby-base-expanded
      // selectedText to the clipboard.

      String? clipboardText;
      var baseCopyPressed = false;

      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          clipboardText = args['text'] as String?;
        }
        return null;
      });
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final base = [
        ContextMenuButtonItem(
          type: ContextMenuButtonType.copy,
          onPressed: () => baseCopyPressed = true,
        ),
      ];

      final result = buildAnalysisButtonItems(
        baseItems: base,
        selectedText: '宇宙',
        addToDictionaryLabel: '辞書追加',
        analyzeNoSpoilerLabel: '解析開始(ネタバレなし)',
        analyzeSpoilerLabel: '解析開始(ネタバレあり)',
        onAddToDictionary: (_) {},
        onAnalyze: (_, _) {},
      );

      final copy = result.firstWhere(
        (i) => i.type == ContextMenuButtonType.copy,
      );
      copy.onPressed!();
      // Give the platform channel a microtask to flush the Clipboard call.
      await tester.pump();

      expect(clipboardText, '宇宙');
      expect(clipboardText, isNot(contains('￼')));
      expect(baseCopyPressed, isFalse,
          reason:
              'The base Copy onPressed must be replaced, not chained — '
              'invoking it would re-trigger the U+FFFC-leaking copy path.');
    });

    testWidgets(
        'leaves non-Copy base items untouched (Paste/SelectAll keep their original onPressed)',
        (tester) async {
      var pasteInvoked = false;
      var selectAllInvoked = false;

      final base = [
        ContextMenuButtonItem(
          type: ContextMenuButtonType.paste,
          onPressed: () => pasteInvoked = true,
        ),
        ContextMenuButtonItem(
          type: ContextMenuButtonType.selectAll,
          onPressed: () => selectAllInvoked = true,
        ),
      ];

      final result = buildAnalysisButtonItems(
        baseItems: base,
        selectedText: '宇宙',
        addToDictionaryLabel: '辞書追加',
        analyzeNoSpoilerLabel: '解析開始(ネタバレなし)',
        analyzeSpoilerLabel: '解析開始(ネタバレあり)',
        onAddToDictionary: (_) {},
        onAnalyze: (_, _) {},
      );

      result
          .firstWhere((i) => i.type == ContextMenuButtonType.paste)
          .onPressed!();
      result
          .firstWhere((i) => i.type == ContextMenuButtonType.selectAll)
          .onPressed!();

      expect(pasteInvoked, isTrue);
      expect(selectAllInvoked, isTrue);
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
    // so the caller can pass `extractSelectedText`-resolved text and the
    // toolbar's buttonItems carry that resolved value into the handlers,
    // regardless of what `editableTextState.value.text` contains.

    Future<List<ContextMenuButtonItem>> buildToolbarButtonItemsFor(
      WidgetTester tester, {
      required String selectedText,
      required void Function(String) onAddToDictionary,
      required void Function(String, SummaryType)? onAnalyze,
    }) async {
      // A TextField gives us a real EditableTextState whose
      // textEditingValue.text is the U+FFFC placeholder — exactly the
      // pre-fix corruption path.
      final controller = TextEditingController(text: '￼');
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 1);
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

      final widget = buildDictionaryContextMenu(
        menuContext,
        editableState,
        selectedText: selectedText,
        onAddToDictionary: onAddToDictionary,
        onAnalyze: onAnalyze,
      ) as AdaptiveTextSelectionToolbar;

      return widget.buttonItems?.toList() ?? const [];
    }

    testWidgets(
        'analyze items invoke onAnalyze with the explicit selectedText, not U+FFFC',
        (tester) async {
      String? capturedWord;
      SummaryType? capturedType;

      final buttonItems = await buildToolbarButtonItemsFor(
        tester,
        selectedText: '宇宙',
        onAddToDictionary: (_) {},
        onAnalyze: (word, type) {
          capturedWord = word;
          capturedType = type;
        },
      );

      final noSpoiler =
          buttonItems.firstWhere((b) => b.label == '解析開始(ネタバレなし)');
      noSpoiler.onPressed!();
      expect(capturedWord, '宇宙');
      expect(capturedWord, isNot(contains('￼')));
      expect(capturedType, SummaryType.noSpoiler);

      final spoiler =
          buttonItems.firstWhere((b) => b.label == '解析開始(ネタバレあり)');
      spoiler.onPressed!();
      expect(capturedWord, '宇宙');
      expect(capturedType, SummaryType.spoiler);
    });

    testWidgets(
        'dictionary item invokes onAddToDictionary with the explicit selectedText',
        (tester) async {
      String? captured;

      final buttonItems = await buildToolbarButtonItemsFor(
        tester,
        selectedText: '宇宙',
        onAddToDictionary: (word) => captured = word,
        onAnalyze: (_, _) {},
      );

      final dict = buttonItems.firstWhere((b) => b.label == '辞書追加');
      dict.onPressed!();
      expect(captured, '宇宙');
      expect(captured, isNot(contains('￼')));
    });

    testWidgets(
        'omits analyze + dictionary items when explicit selectedText is empty (even with a non-empty editableTextState)',
        (tester) async {
      final buttonItems = await buildToolbarButtonItemsFor(
        tester,
        selectedText: '',
        onAddToDictionary: (_) {},
        onAnalyze: (_, _) {},
      );

      final labels = buttonItems.map((b) => b.label).toList();
      expect(labels, isNot(contains('辞書追加')));
      expect(labels, isNot(contains('解析開始(ネタバレなし)')));
      expect(labels, isNot(contains('解析開始(ネタバレあり)')));
    });
  });
}
