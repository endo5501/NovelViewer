import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/swipe_detection.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';

Widget _buildTestWidget({
  required List<TextSegment> segments,
  String? query,
  int? selectionStart,
  int? selectionEnd,
  ValueChanged<String?>? onSelectionChanged,
  ValueChanged<SwipeDirection>? onSwipe,
  double? columnSpacing,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: SizedBox(
        width: 200,
        height: 300,
        child: VerticalTextPage(
          segments: segments,
          baseStyle: const TextStyle(fontSize: 14.0),
          query: query,
          selectionStart: selectionStart,
          selectionEnd: selectionEnd,
          onSelectionChanged: onSelectionChanged,
          onSwipe: onSwipe,
          columnSpacing: columnSpacing ?? 8.0,
        ),
      ),
    ),
  );
}

void main() {
  group('VerticalTextPage selection highlight', () {
    testWidgets('selected characters have blue background', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいう')],
        selectionStart: 0,
        selectionEnd: 2,
      ));

      final aText = tester.widget<Text>(find.text('あ'));
      final iText = tester.widget<Text>(find.text('い'));
      final uText = tester.widget<Text>(find.text('う'));

      final expectedColor = Colors.blue.withValues(alpha: 0.3);
      expect(aText.style?.backgroundColor, expectedColor);
      expect(iText.style?.backgroundColor, expectedColor);
      expect(uText.style?.backgroundColor, isNull);
    });

    testWidgets('no selection highlight when selection params are null',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいう')],
      ));

      final aText = tester.widget<Text>(find.text('あ'));
      expect(aText.style?.backgroundColor, isNull);
    });

    testWidgets('search highlight takes precedence over selection',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいう')],
        query: 'い',
        selectionStart: 0,
        selectionEnd: 3,
      ));

      final aText = tester.widget<Text>(find.text('あ'));
      final iText = tester.widget<Text>(find.text('い'));
      final uText = tester.widget<Text>(find.text('う'));

      final selectionColor = Colors.blue.withValues(alpha: 0.3);
      // 'あ': selected only → blue
      expect(aText.style?.backgroundColor, selectionColor);
      // 'い': search highlighted + selected → yellow wins
      expect(iText.style?.backgroundColor, Colors.yellow);
      // 'う': selected only → blue
      expect(uText.style?.backgroundColor, selectionColor);
    });
  });

  group('VerticalTextPage dark mode search highlight', () {
    testWidgets('search highlight uses amber background in dark mode',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいう')],
        query: 'い',
        theme: ThemeData(brightness: Brightness.dark),
      ));

      final iText = tester.widget<Text>(find.text('い'));
      expect(iText.style?.backgroundColor, Colors.amber.shade700);
    });

    testWidgets('search highlight uses black foreground in dark mode',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいう')],
        query: 'い',
        theme: ThemeData(brightness: Brightness.dark),
      ));

      final iText = tester.widget<Text>(find.text('い'));
      expect(iText.style?.color, Colors.black);
    });
  });

  group('VerticalTextPage gesture interaction', () {
    testWidgets('GestureDetector is present in widget tree', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいう')],
      ));
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('tap calls onSelectionChanged with null', (tester) async {
      bool callbackCalled = false;
      String? notifiedText = 'initial';

      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいう')],
        onSelectionChanged: (text) {
          callbackCalled = true;
          notifiedText = text;
        },
      ));

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(callbackCalled, isTrue);
      expect(notifiedText, isNull);
    });

    testWidgets('onSelectionChanged parameter is accepted', (tester) async {
      // Verify the widget accepts the callback without error
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいう')],
        onSelectionChanged: (text) {},
      ));

      expect(find.byType(VerticalTextPage), findsOneWidget);
    });
  });

  group('VerticalTextPage character centering', () {
    testWidgets(
        'each character is wrapped in fixed-width SizedBox with center alignment',
        (tester) async {
      const fontSize = 14.0;
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あい')],
      ));

      for (final char in ['あ', 'い']) {
        final textFinder = find.text(char);
        expect(textFinder, findsOneWidget);

        // Text should use textAlign: TextAlign.center
        final textWidget = tester.widget<Text>(textFinder);
        expect(
          textWidget.textAlign,
          TextAlign.center,
          reason: '"$char" should have textAlign: TextAlign.center',
        );

        // Text should have a SizedBox ancestor with width = fontSize
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
              '"$char" should be wrapped in a SizedBox with width=$fontSize',
        );
      }
    });

    testWidgets(
        'blank line sentinel has full column width, separator sentinel has zero width',
        (tester) async {
      const fontSize = 14.0;
      // 'あ\n\nい' produces: column 'あ', empty column (blank line), column 'い'
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あ\n\nい')],
      ));

      // Both characters should still render
      expect(find.text('あ'), findsOneWidget);
      expect(find.text('い'), findsOneWidget);

      // The blank line sentinel should have width=fontSize (visible empty column)
      final blankLineSentinel = find.byWidgetPredicate(
        (w) =>
            w is SizedBox && w.width == fontSize && w.height == double.infinity,
      );
      expect(blankLineSentinel, findsOneWidget,
          reason:
              'Blank line sentinel should have width equal to fontSize ($fontSize)');

      // The column separator sentinel should have width=0
      final separatorSentinel = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 0 && w.height == double.infinity,
      );
      expect(separatorSentinel, findsOneWidget,
          reason: 'Column separator sentinel should have width 0');
    });
  });

  group('VerticalTextPage columnSpacing parameter', () {
    testWidgets('Wrap uses provided columnSpacing as runSpacing',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あい')],
        columnSpacing: 12.0,
      ));

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.runSpacing, 12.0);
    });

    testWidgets('default columnSpacing is 8.0', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あい')],
      ));

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.runSpacing, 8.0);
    });
  });

  group('VerticalTextPage gesture mode classification', () {
    testWidgets(
        'horizontal drag does not notify selection (enters swiping mode)',
        (tester) async {
      final selectionNotifications = <String?>[];
      final swipeNotifications = <SwipeDirection>[];

      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいうえおかきくけこ')],
        onSelectionChanged: (text) => selectionNotifications.add(text),
        onSwipe: (dir) => swipeNotifications.add(dir),
      ));

      // Start drag ON a character, then move primarily horizontally.
      // Use timedDragFrom for realistic gesture simulation.
      final charCenter = tester.getCenter(find.text('あ'));
      await tester.timedDragFrom(
        charCenter,
        const Offset(-90, 5), // primarily horizontal
        const Duration(milliseconds: 200),
      );

      // Swiping mode should trigger onSwipe, NOT onSelectionChanged with text
      expect(swipeNotifications, isNotEmpty,
          reason: 'Horizontal drag should trigger swipe');
      // onSelectionChanged should NOT have been called with non-null text
      expect(selectionNotifications.where((t) => t != null), isEmpty,
          reason:
              'Horizontal drag should not produce text selection notifications');
    });

    testWidgets('vertical drag triggers text selection (enters selecting mode)',
        (tester) async {
      final selectionNotifications = <String?>[];
      final swipeNotifications = <SwipeDirection>[];

      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいうえおかきくけこ')],
        onSelectionChanged: (text) => selectionNotifications.add(text),
        onSwipe: (dir) => swipeNotifications.add(dir),
      ));

      // Drag vertically between characters (within a column)
      final firstChar = tester.getCenter(find.text('あ'));
      final thirdChar = tester.getCenter(find.text('う'));
      await tester.timedDragFrom(
        firstChar,
        thirdChar - firstChar, // primarily vertical (within same column)
        const Duration(milliseconds: 300),
      );

      // Should NOT trigger swipe
      expect(swipeNotifications, isEmpty,
          reason: 'Vertical drag should not trigger swipe');
    });

    testWidgets(
        'drag that starts vertically does not trigger swipe even with horizontal endpoint',
        (tester) async {
      final swipeNotifications = <SwipeDirection>[];

      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいうえおかきくけこ')],
        onSelectionChanged: (_) {},
        onSwipe: (dir) => swipeNotifications.add(dir),
      ));

      // Start on a character, first move primarily vertical (should enter
      // selecting mode), then move horizontally. Total displacement has
      // |dx| > |dy| but initial direction was vertical.
      final charCenter = tester.getCenter(find.text('あ'));
      final gesture = await tester.startGesture(charCenter);
      // First move: primarily vertical → enters selecting mode
      await gesture.moveBy(const Offset(2, 20));
      // Second move: primarily horizontal → but mode is already selecting
      // Use large enough displacement to exceed kSwipeMinDistanceWithoutFling
      await gesture.moveBy(const Offset(-100, 5));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Should NOT trigger swipe because mode was classified as selecting
      expect(swipeNotifications, isEmpty,
          reason:
              'Drag that started vertically should not trigger swipe even if endpoint is far horizontal');
    });

    testWidgets('very short drag does not trigger swipe or selection',
        (tester) async {
      final selectionNotifications = <String?>[];
      SwipeDirection? swipeDir;

      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいうえお')],
        onSelectionChanged: (text) => selectionNotifications.add(text),
        onSwipe: (dir) {
          swipeDir = dir;
        },
      ));

      // Perform a very short drag (below pan slop, won't trigger pan)
      final center = tester.getCenter(find.byType(VerticalTextPage));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(3, 2));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Should not trigger swipe (distance too short)
      expect(swipeDir, isNull);
    });
  });
}
