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
