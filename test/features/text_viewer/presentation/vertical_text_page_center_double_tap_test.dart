import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

const _pageWidth = 300.0;
const _pageHeight = 300.0;

// Each line break starts a new column to the left, so "アリス" lands in the
// fourth column from the right — inside the middle third of a 300-wide page.
const _segments = [PlainTextSegment('一\n二\n三\nアリス')];

Widget _build({
  VoidCallback? onCenterDoubleTap,
  int? selectionStart,
  int? selectionEnd,
  void Function(String word, Offset position, HoverToken token)? onMarkTap,
  void Function(Offset position, String selectedText)? onContextMenu,
}) {
  return MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: _pageWidth,
          height: _pageHeight,
          child: VerticalTextPage(
            segments: _segments,
            baseStyle: const TextStyle(fontSize: 14.0),
            markedWords: const {'アリス': MarkStyle.solid},
            selectionStart: selectionStart,
            selectionEnd: selectionEnd,
            onMarkTap: onMarkTap,
            onContextMenu: onContextMenu,
            onCenterDoubleTap: onCenterDoubleTap,
          ),
        ),
      ),
    ),
  );
}

/// A point in the page, as a fraction of its width, near the bottom where no
/// character is laid out.
Offset _emptyAt(WidgetTester tester, double fractionOfWidth) {
  final origin = tester.getTopLeft(find.byType(VerticalTextPage));
  return origin + Offset(_pageWidth * fractionOfWidth, _pageHeight - 40);
}

Future<void> _tapWith(
  WidgetTester tester,
  Offset position,
  PointerDeviceKind kind,
) async {
  final gesture = await tester.createGesture(
    kind: kind,
    buttons: kind == PointerDeviceKind.mouse
        ? kPrimaryMouseButton
        : kPrimaryButton,
  );
  if (kind == PointerDeviceKind.mouse) {
    await gesture.addPointer(location: position);
  }
  await gesture.down(position);
  await gesture.up();
  if (kind == PointerDeviceKind.mouse) {
    await gesture.removePointer();
  }
  await tester.pump();
}

void main() {
  group('VerticalTextPage center double tap', () {
    testWidgets('a finger double tap in the middle third reports it', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(_build(onCenterDoubleTap: () => calls++));
      await tester.pump();

      final center = _emptyAt(tester, 0.5);
      await tester.tapAt(center);
      await tester.pump();
      expect(calls, 0, reason: 'a single tap is not a double tap');

      await tester.tapAt(center);
      await tester.pump();

      expect(calls, 1);
    });

    testWidgets('a stylus double tap in the middle third reports it', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(_build(onCenterDoubleTap: () => calls++));
      await tester.pump();

      final center = _emptyAt(tester, 0.5);
      await _tapWith(tester, center, PointerDeviceKind.stylus);
      await _tapWith(tester, center, PointerDeviceKind.stylus);

      expect(calls, 1);
    });

    testWidgets('a double tap in the left third reports nothing', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(_build(onCenterDoubleTap: () => calls++));
      await tester.pump();

      final left = _emptyAt(tester, 0.2);
      await tester.tapAt(left);
      await tester.pump();
      await tester.tapAt(left);
      await tester.pump();

      expect(calls, 0);
    });

    testWidgets('a double tap in the right third reports nothing', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(_build(onCenterDoubleTap: () => calls++));
      await tester.pump();

      final right = _emptyAt(tester, 0.8);
      await tester.tapAt(right);
      await tester.pump();
      await tester.tapAt(right);
      await tester.pump();

      expect(calls, 0);
    });

    testWidgets('a mouse double click in the middle third reports nothing', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(_build(onCenterDoubleTap: () => calls++));
      await tester.pump();

      final center = _emptyAt(tester, 0.5);
      await _tapWith(tester, center, PointerDeviceKind.mouse);
      await _tapWith(tester, center, PointerDeviceKind.mouse);

      expect(calls, 0);
    });

    testWidgets('a second tap after the double-tap interval reports nothing', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(_build(onCenterDoubleTap: () => calls++));
      await tester.pump();

      final center = _emptyAt(tester, 0.5);
      await tester.tapAt(center);
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 20));
      await tester.tapAt(center);
      await tester.pump();

      expect(calls, 0);
    });

    testWidgets('a second tap beyond the double-tap slop reports nothing', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(_build(onCenterDoubleTap: () => calls++));
      await tester.pump();

      final center = _emptyAt(tester, 0.5);
      await tester.tapAt(center);
      await tester.pump();
      // Still in the middle third, but further than the slop from the first.
      await tester.tapAt(center - const Offset(0, kDoubleTapSlop + 20));
      await tester.pump();

      expect(calls, 0);
    });

    testWidgets('a swipe between the two taps discards the first', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(_build(onCenterDoubleTap: () => calls++));
      await tester.pump();

      final center = _emptyAt(tester, 0.5);
      await tester.tapAt(center);
      await tester.pump();
      await tester.dragFrom(center, const Offset(-120, 0));
      await tester.pump();
      await tester.tapAt(center);
      await tester.pump();

      expect(calls, 0);
    });

    testWidgets('a tap that clears a selection does not start a double tap', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _build(
          onCenterDoubleTap: () => calls++,
          // "一" and its line break, well away from the middle third.
          selectionStart: 0,
          selectionEnd: 2,
        ),
      );
      await tester.pump();

      final center = _emptyAt(tester, 0.5);
      await tester.tapAt(center);
      await tester.pump();
      await tester.tapAt(center);
      await tester.pump();

      expect(calls, 0);
    });

    testWidgets('a tap that opens a summary does not start a double tap', (
      tester,
    ) async {
      var calls = 0;
      var markTaps = 0;
      await tester.pumpWidget(
        _build(
          onCenterDoubleTap: () => calls++,
          onMarkTap: (_, _, _) {
            markTaps++;
          },
        ),
      );
      await tester.pump();

      final marked = tester.getRect(find.text('リ'));
      final pageLeft = tester.getTopLeft(find.byType(VerticalTextPage)).dx;
      expect(
        marked.center.dx - pageLeft,
        inInclusiveRange(_pageWidth / 3, _pageWidth * 2 / 3),
        reason: 'the marked word must sit in the middle third',
      );

      await tester.tapAt(marked.center);
      await tester.pump();
      expect(markTaps, 1, reason: 'the summary opens at once');

      // Unmarked, empty space in the same column, within the slop.
      await tester.tapAt(marked.center + const Offset(0, 60));
      await tester.pump();

      expect(calls, 0);
    });

    testWidgets('a tap inside the selection opens the menu, not the drawer', (
      tester,
    ) async {
      var calls = 0;
      var menus = 0;
      await tester.pumpWidget(
        _build(
          onCenterDoubleTap: () => calls++,
          // "アリス": indices 6..8 after the three characters and line breaks.
          selectionStart: 6,
          selectionEnd: 9,
          onContextMenu: (_, _) => menus++,
        ),
      );
      await tester.pump();

      final selected = tester.getCenter(find.text('リ'));
      await tester.tapAt(selected);
      await tester.pump();
      expect(menus, 1, reason: 'the menu opens at once');
      await tester.tapAt(selected);
      await tester.pump();

      expect(menus, 2);
      expect(calls, 0);
    });

    testWidgets('three quick taps report a single double tap', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_build(onCenterDoubleTap: () => calls++));
      await tester.pump();

      final center = _emptyAt(tester, 0.5);
      for (var i = 0; i < 3; i++) {
        await tester.tapAt(center);
        await tester.pump();
      }

      expect(calls, 1);
    });

    testWidgets('a pending first tap does not outlive the page', (
      tester,
    ) async {
      // The first tap arms a timer; disposing the page with it pending must
      // not leave the timer running.
      await tester.pumpWidget(_build(onCenterDoubleTap: () {}));
      await tester.pump();

      await tester.tapAt(_emptyAt(tester, 0.5));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    });
  });
}
