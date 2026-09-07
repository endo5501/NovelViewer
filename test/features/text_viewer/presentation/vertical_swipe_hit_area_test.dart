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

/// The `Align` is here only to hand the page the bounded, loose constraints it
/// gets from `Padding` in the viewer, which the keyed `SizedBox` would
/// otherwise make tight — the viewer itself no longer wraps the page in one,
/// because the page aligns its own text. `topRight` rather than `topLeft` so
/// that a page which went back to shrink-wrapping would leave the empty region
/// on the left, where these tests aim, instead of silently moving under them.
///
/// With only two characters of content the text occupies one narrow column at
/// the right, so most of the area has nothing painted on it.
Widget _pageHarness({
  required List<TextSegment> segments,
  ValueChanged<SwipeDirection>? onSwipe,
  ValueChanged<ViewerSelection?>? onSelectionChanged,
  int? selectionStart,
  int? selectionEnd,
  double width = _kAreaWidth,
}) {
  return MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          key: _areaKey,
          width: width,
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
  ValueChanged<ViewerSelection?>? onSelectionChanged,
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
            onSelectionChanged: onSelectionChanged,
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
      final reported = <ViewerSelection?>[];
      await tester.pumpWidget(
        _pageHarness(
          segments: const [PlainTextSegment('あいうえお')],
          onSelectionChanged: reported.add,
        ),
      );

      // Select by dragging, the way the viewer's reader does — the viewer
      // never supplies selectionStart/selectionEnd itself.
      await tester.dragFrom(
        tester.getCenter(find.text('あ')),
        const Offset(0, 40),
      );
      await tester.pumpAndSettle();
      expect(reported.last, isNotNull);

      final area = tester.getRect(find.byKey(_areaKey));
      await tester.tapAt(Offset(area.left + 40, area.center.dy));
      await tester.pumpAndSettle();

      expect(reported.last, isNull);
    });

    testWidgets('a swipe reports the selection it clears', (tester) async {
      final reported = <ViewerSelection?>[];
      await tester.pumpWidget(
        _pageHarness(
          segments: const [PlainTextSegment('あいうえお')],
          onSelectionChanged: reported.add,
          onSwipe: (_) {},
        ),
      );

      // Select by dragging down the column, then swipe across it. The page
      // clears its own highlight on a swipe, so it has to say so: on the first
      // or last page the swipe is routed to the boundary handler and the
      // viewer's own "selection cleared" report is never reached.
      final firstChar = tester.getCenter(find.text('あ'));
      await tester.dragFrom(firstChar, const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(reported.last, isNotNull);

      await tester.dragFrom(firstChar, const Offset(120, 0));
      await tester.pumpAndSettle();

      expect(reported.last, isNull);
    });

    testWidgets('a swipe clears a selection the owner supplied', (
      tester,
    ) async {
      // The page cannot clear the owner's props itself, so the report IS the
      // clearing: a swipe clears any active selection, the same contract a tap
      // already follows.
      final reported = <ViewerSelection?>[];
      await tester.pumpWidget(
        _pageHarness(
          segments: const [PlainTextSegment('あいうえお')],
          selectionStart: 0,
          selectionEnd: 3,
          onSelectionChanged: reported.add,
          onSwipe: (_) {},
        ),
      );

      await tester.dragFrom(
        tester.getCenter(find.text('あ')),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();

      expect(reported.last, isNull);
    });

    testWidgets('hit testing follows the text after a width-only rebuild', (
      tester,
    ) async {
      // Same const segments, style and spacing: nothing didUpdateWidget looks
      // at changes, but the top-right alignment moves every character when the
      // area narrows, so the cached rectangles have to be rebuilt anyway.
      //
      // Nothing is selected before the resize on purpose. With a selection
      // left over from an earlier drag, a drag onto stale rectangles resolves
      // no anchor, updates nothing, and re-reports that earlier selection at
      // pan end — which would read as success while proving nothing.
      const segments = [PlainTextSegment('あいうえお')];
      ViewerSelection? selection;
      await tester.pumpWidget(
        _pageHarness(
          segments: segments,
          width: 400,
          onSelectionChanged: (value) => selection = value,
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _pageHarness(
          segments: segments,
          width: 300,
          onSelectionChanged: (value) => selection = value,
        ),
      );
      await tester.pumpAndSettle();

      await tester.dragFrom(
        tester.getCenter(find.text('あ')),
        const Offset(0, 40),
      );
      await tester.pumpAndSettle();

      expect(selection, isNotNull);
    });
  });

  group('VerticalTextPage selection anchor', () {
    testWidgets(
      'a selection starts at the character the pointer went down on',
      (tester) async {
        ViewerSelection? selection;
        await tester.pumpWidget(
          _pageHarness(
            segments: const [PlainTextSegment('あいうえお')],
            onSelectionChanged: (value) => selection = value,
          ),
        );

        // A touch pan is accepted only after the slop distance, which on a
        // touchscreen is worth a character or two of vertical text. Anchoring
        // there instead of at the press drops the characters the reader
        // actually started on.
        await tester.dragFrom(
          tester.getCenter(find.text('あ')),
          const Offset(0, 40),
        );
        await tester.pumpAndSettle();

        expect(selection?.text, startsWith('あ'));
        expect(selection?.plainTextOffset, 0);
      },
    );

    testWidgets('a selection covers the move that got the pan accepted', (
      tester,
    ) async {
      ViewerSelection? selection;
      await tester.pumpWidget(
        _pageHarness(
          segments: const [PlainTextSegment('あいうえおかきく')],
          onSelectionChanged: (value) => selection = value,
        ),
      );

      // One move far enough to be accepted, then release. No onPanUpdate
      // follows the accepting move, so the range has to be set from that
      // move's position too — otherwise only the pressed character is
      // selected and everything the pointer crossed is dropped.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('あ')),
      );
      await gesture.moveTo(tester.getCenter(find.text('お')));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(selection?.text, 'あいうえお');
    });

    testWidgets('a press in the gap between columns still selects', (
      tester,
    ) async {
      ViewerSelection? selection;
      await tester.pumpWidget(
        _pageHarness(
          segments: const [PlainTextSegment('あいうえお\nかきくけこ')],
          onSelectionChanged: (value) => selection = value,
        ),
      );

      // Nothing is painted between two columns, but a finger aimed at a
      // character lands there often enough — the same reason the tap path
      // snaps within a column gap.
      final rightColumn = tester.getRect(find.text('あ'));
      final leftColumn = tester.getRect(find.text('か'));
      final gapCentre = Offset(
        (leftColumn.right + rightColumn.left) / 2,
        rightColumn.center.dy,
      );

      await tester.dragFrom(gapCentre, const Offset(0, 60));
      await tester.pumpAndSettle();

      expect(selection, isNotNull);
    });

    testWidgets('a drag that starts beside the text starts no selection', (
      tester,
    ) async {
      ViewerSelection? selection;
      await tester.pumpWidget(
        _pageHarness(
          segments: const [PlainTextSegment('あいうえお')],
          onSelectionChanged: (value) => selection = value,
        ),
      );

      // Down in the empty area a slop's width from the column, then onto it:
      // the anchor is decided by where the pointer went down, so this starts
      // no selection even though the pointer ends up over characters.
      final firstChar = tester.getRect(find.text('あ'));
      await tester.dragFrom(
        Offset(firstChar.left - 20, firstChar.center.dy),
        const Offset(24, 60),
      );
      await tester.pumpAndSettle();

      expect(selection, isNull);
    });
  });

  group('VerticalTextViewer swipe at a file boundary', () {
    testWidgets('a swipe on the last page clears the reported selection', (
      tester,
    ) async {
      // The page index cannot move, so _changePage hands off to the boundary
      // handler and returns before the viewer's own "selection cleared"
      // report. The highlight goes either way, so the report has to come from
      // the page — otherwise the search and LLM panels keep acting on text
      // that is no longer shown as selected.
      final reported = <ViewerSelection?>[];
      await tester.pumpWidget(
        _viewerHarness(
          segments: _shortLastPageSegments(),
          onSelectionChanged: reported.add,
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(VerticalTextPage), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(_indicatorText(tester), '2 / 2');

      await tester.dragFrom(
        tester.getCenter(find.text('う').first),
        const Offset(0, 60),
      );
      await tester.pumpAndSettle();
      expect(reported.last, isNotNull);

      await tester.dragFrom(
        tester.getCenter(find.text('う').first),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();

      expect(reported.last, isNull);
    });
  });

  group('VerticalTextViewer swipe during the slide animation', () {
    testWidgets('a swipe mid-animation still turns the page', (tester) async {
      // The outgoing page fills the content area and sits under the incoming
      // one, which starts fully off-screen. Every pointer-down during the
      // slide therefore lands on the outgoing page, so it has to route swipes
      // too — otherwise a reader flipping quickly loses the second swipe.
      await tester.pumpWidget(
        _viewerHarness(segments: [PlainTextSegment('あ' * 4000)]),
      );
      await tester.pumpAndSettle();
      expect(_indicatorText(tester), startsWith('1 /'));

      await tester.drag(find.byType(VerticalTextPage), const Offset(200, 0));
      await tester.pump(const Duration(milliseconds: 80));
      expect(_indicatorText(tester), startsWith('2 /'));

      await tester.dragFrom(const Offset(400, 300), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(_indicatorText(tester), startsWith('3 /'));
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

      // Aim halfway between the viewer's left edge and the leftmost painted
      // column, derived rather than hardcoded: if pagination or the font ever
      // let the text reach further left, this asserts instead of quietly
      // starting the drag on a character and testing nothing.
      final viewer = tester.getRect(find.byType(VerticalTextViewer));
      final leftmostChar = tester.getRect(find.text('う').first);
      final emptyX = (viewer.left + leftmostChar.left) / 2;
      expect(
        emptyX,
        lessThan(leftmostChar.left),
        reason: 'the drag must start where no character is painted',
      );

      await tester.dragFrom(
        Offset(emptyX, viewer.center.dy),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();

      expect(_indicatorText(tester), '1 / 2');
    });
  });
}
