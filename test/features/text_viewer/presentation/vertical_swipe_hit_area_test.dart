import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/swipe_detection.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/data/viewer_selection.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Marks the area handed to [VerticalTextPage] so a test can aim a gesture at
/// the part of it where no character is painted.
final _areaKey = GlobalKey();

const _kAreaWidth = 400.0;
const _kAreaHeight = 300.0;

/// The page is given loose constraints and a top-right alignment, which is how
/// `VerticalTextViewer` hands it its area. With only two characters of content
/// the text occupies one narrow column at the right, so most of the area has
/// nothing painted on it.
Widget _pageHarness({
  required List<TextSegment> segments,
  ValueChanged<SwipeDirection>? onSwipe,
  ValueChanged<ViewerSelection?>? onSelectionChanged,
  int? selectionStart,
  int? selectionEnd,
}) {
  return MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          key: _areaKey,
          width: _kAreaWidth,
          height: _kAreaHeight,
          child: Align(
            alignment: Alignment.topRight,
            child: VerticalTextPage(
              segments: segments,
              baseStyle: const TextStyle(fontSize: 14.0),
              columnSpacing: 8.0,
              selectionStart: selectionStart,
              selectionEnd: selectionEnd,
              onSwipe: onSwipe,
              onSelectionChanged: onSelectionChanged,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A document whose last page holds only two short lines, so its text stops
/// well short of the left edge — the case the reader hits at the end of an
/// episode.
List<TextSegment> _shortLastPageSegments() => [
  PlainTextSegment('${'あ' * 900}\n${'い' * 20}\n${'う' * 10}'),
];

Widget _viewerHarness({
  required List<TextSegment> segments,
  double width = 800,
  double height = 600,
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints.tightFor(width: width, height: height),
          child: VerticalTextViewer(
            segments: segments,
            baseStyle: const TextStyle(fontSize: 16.0),
          ),
        ),
      ),
    ),
  );
}

String? _indicatorText(WidgetTester tester) {
  final finder = find.textContaining('/');
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Text>(finder).data;
}

void main() {
  group('VerticalTextPage hit area', () {
    testWidgets('the render box fills the area it is given', (tester) async {
      await tester.pumpWidget(
        _pageHarness(segments: const [PlainTextSegment('あい')]),
      );

      expect(
        tester.getRect(find.byType(VerticalTextPage)),
        tester.getRect(find.byKey(_areaKey)),
      );
    });

    testWidgets('the text stays aligned to the top-right of that area', (
      tester,
    ) async {
      await tester.pumpWidget(
        _pageHarness(segments: const [PlainTextSegment('あい')]),
      );

      final area = tester.getRect(find.byKey(_areaKey));
      final firstChar = tester.getRect(find.text('あ'));

      expect(firstChar.right, moreOrLessEquals(area.right, epsilon: 0.01));
      expect(firstChar.top, moreOrLessEquals(area.top, epsilon: 0.01));
    });

    testWidgets('a right drag over the empty area is a right swipe', (
      tester,
    ) async {
      SwipeDirection? direction;
      await tester.pumpWidget(
        _pageHarness(
          segments: const [PlainTextSegment('あい')],
          onSwipe: (value) => direction = value,
        ),
      );

      final area = tester.getRect(find.byKey(_areaKey));
      await tester.dragFrom(
        Offset(area.left + 40, area.center.dy),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();

      expect(direction, SwipeDirection.right);
    });

    testWidgets('a left drag over the empty area is a left swipe', (
      tester,
    ) async {
      SwipeDirection? direction;
      await tester.pumpWidget(
        _pageHarness(
          segments: const [PlainTextSegment('あい')],
          onSwipe: (value) => direction = value,
        ),
      );

      final area = tester.getRect(find.byKey(_areaKey));
      await tester.dragFrom(
        Offset(area.left + 200, area.center.dy),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();

      expect(direction, SwipeDirection.left);
    });

    testWidgets('a vertical drag over the empty area starts no selection', (
      tester,
    ) async {
      ViewerSelection? selection;
      await tester.pumpWidget(
        _pageHarness(
          segments: const [PlainTextSegment('あい')],
          onSelectionChanged: (value) => selection = value,
        ),
      );

      final area = tester.getRect(find.byKey(_areaKey));
      await tester.dragFrom(
        Offset(area.left + 40, area.top + 20),
        const Offset(0, 150),
      );
      await tester.pumpAndSettle();

      expect(selection, isNull);
      expect(
        tester.widget<Text>(find.text('あ')).style?.backgroundColor,
        isNull,
      );
    });

    testWidgets('a tap on the empty area clears the selection', (tester) async {
      var cleared = false;
      await tester.pumpWidget(
        _pageHarness(
          segments: const [PlainTextSegment('あい')],
          selectionStart: 0,
          selectionEnd: 2,
          onSelectionChanged: (value) => cleared = value == null,
        ),
      );

      final area = tester.getRect(find.byKey(_areaKey));
      await tester.tapAt(Offset(area.left + 40, area.center.dy));
      await tester.pumpAndSettle();

      expect(cleared, isTrue);
    });
  });

  group('VerticalTextViewer swipe over an area with no text', () {
    testWidgets('the page covers the padded content area on a short page', (
      tester,
    ) async {
      await tester.pumpWidget(
        _viewerHarness(segments: _shortLastPageSegments()),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(VerticalTextPage), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(_indicatorText(tester), '2 / 2');

      final viewer = tester.getRect(find.byType(VerticalTextViewer));
      final page = tester.getRect(find.byType(VerticalTextPage));

      // 16px of padding on each side is the only horizontal inset.
      expect(page.left, moreOrLessEquals(viewer.left + 16, epsilon: 0.01));
      expect(page.right, moreOrLessEquals(viewer.right - 16, epsilon: 0.01));
    });

    testWidgets('a left swipe on the empty left region returns to the previous '
        'page', (tester) async {
      await tester.pumpWidget(
        _viewerHarness(segments: _shortLastPageSegments()),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(VerticalTextPage), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(_indicatorText(tester), '2 / 2');

      // x = 200 is inside the empty left region of the short last page: with
      // this content the text starts around x = 480.
      await tester.dragFrom(const Offset(200, 300), const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(_indicatorText(tester), '1 / 2');
    });
  });
}
