import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_ruby_text_widget.dart';

Widget _buildTestWidget({
  required String base,
  required String rubyText,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 200,
        height: 300,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            VerticalRubyTextWidget(
              base: base,
              rubyText: rubyText,
              baseStyle: const TextStyle(fontSize: 14.0),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('VerticalRubyTextWidget character centering', () {
    testWidgets(
        'base characters are wrapped in fixed-width SizedBox with center alignment',
        (tester) async {
      const fontSize = 14.0;
      await tester.pumpWidget(_buildTestWidget(
        base: '漢字',
        rubyText: 'かんじ',
      ));

      for (final char in ['漢', '字']) {
        final textFinder = find.text(char);
        expect(textFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(textFinder);
        expect(
          textWidget.textAlign,
          TextAlign.center,
          reason:
              'Base char "$char" should have textAlign: TextAlign.center',
        );

        final sizedBoxFinder = find.ancestor(
          of: textFinder,
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == fontSize,
          ),
        );
        expect(
          sizedBoxFinder,
          findsWidgets,
          reason:
              'Base char "$char" should be wrapped in a SizedBox with width=$fontSize',
        );
      }
    });

    testWidgets(
        'ruby characters are wrapped in fixed-width SizedBox with center alignment',
        (tester) async {
      const fontSize = 14.0;
      const rubyFontSize = fontSize * 0.5;
      await tester.pumpWidget(_buildTestWidget(
        base: '漢字',
        rubyText: 'かんじ',
      ));

      for (final char in ['か', 'ん', 'じ']) {
        final textFinder = find.text(char);
        expect(textFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(textFinder);
        expect(
          textWidget.textAlign,
          TextAlign.center,
          reason:
              'Ruby char "$char" should have textAlign: TextAlign.center',
        );

        final sizedBoxFinder = find.ancestor(
          of: textFinder,
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == rubyFontSize,
          ),
        );
        expect(
          sizedBoxFinder,
          findsWidgets,
          reason:
              'Ruby char "$char" should be wrapped in a SizedBox with width=$rubyFontSize',
        );
      }
    });
  });

  group('VerticalRubyTextWidget vertical character mapping for ruby text', () {
    testWidgets('ruby text with brackets is mapped to vertical equivalents',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        base: '漢字',
        rubyText: '（かんじ）',
      ));

      // Brackets should be mapped: （ → ︵, ） → ︶
      expect(find.text('︵'), findsOneWidget);
      expect(find.text('︶'), findsOneWidget);
      // Original brackets should not appear
      expect(find.text('（'), findsNothing);
      expect(find.text('）'), findsNothing);
    });

    testWidgets('ruby text with dash is mapped to vertical equivalent',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        base: '漢字',
        rubyText: 'ーかー',
      ));

      // ー should be mapped to 丨
      expect(find.text('丨'), findsNWidgets(2));
    });

    testWidgets('ruby text with punctuation is mapped to vertical equivalent',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        base: '漢字',
        rubyText: '。、',
      ));

      // 。 → ︒, 、 → ︑
      expect(find.text('︒'), findsOneWidget);
      expect(find.text('︑'), findsOneWidget);
    });

    testWidgets(
        'ruby text with only hiragana remains unchanged in vertical mode',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        base: '漢字',
        rubyText: 'かんじ',
      ));

      // Hiragana has no vertical mapping, should remain as-is
      expect(find.text('か'), findsOneWidget);
      expect(find.text('ん'), findsOneWidget);
      expect(find.text('じ'), findsOneWidget);
    });

    testWidgets(
        'ruby text with only katakana remains unchanged in vertical mode',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        base: '漢字',
        rubyText: 'カンジ',
      ));

      // Katakana (except ー) has no vertical mapping, should remain as-is
      expect(find.text('カ'), findsOneWidget);
      expect(find.text('ン'), findsOneWidget);
      expect(find.text('ジ'), findsOneWidget);
    });
  });
}
