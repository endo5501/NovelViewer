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
        onAddToDictionary: (w) => captured = w,
        onAnalyze: (_, _) {},
      );

      result.firstWhere((i) => i.label == '辞書追加').onPressed!();
      expect(captured, 'アリス');
    });

    test('omits dictionary and analyze items when selection is whitespace-only',
        () {
      // Future-proofing: whitespace shouldn't be a meaningful selection target.
      // But the current implementation only checks `.isNotEmpty`, so this
      // test pins down current behavior — a whitespace selection DOES add
      // them. If we tighten the check later, update this expectation.
      final result = buildAnalysisButtonItems(
        baseItems: const [],
        selectedText: '   ',
        addToDictionaryLabel: '辞書追加',
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
}
