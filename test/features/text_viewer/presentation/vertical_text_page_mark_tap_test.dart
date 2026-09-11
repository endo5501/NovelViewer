import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/data/viewer_selection.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

typedef MarkTapCall = ({String word, Offset position, HoverToken token});

Widget _build({
  List<TextSegment>? segments,
  int? selectionStart,
  int? selectionEnd,
  void Function(String word, Offset position, HoverToken token)? onMarkTap,
  ValueChanged<ViewerSelection?>? onSelectionChanged,
  void Function(Offset position, String selectedText)? onContextMenu,
  double columnSpacing = 8.0,
}) {
  return MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 200,
        height: 300,
        child: VerticalTextPage(
          segments: segments ?? const [PlainTextSegment('昨日アリスが来た')],
          baseStyle: const TextStyle(fontSize: 14.0),
          markedWords: const {'アリス': MarkStyle.solid},
          selectionStart: selectionStart,
          selectionEnd: selectionEnd,
          onMarkTap: onMarkTap,
          onSelectionChanged: onSelectionChanged,
          onContextMenu: onContextMenu,
          columnSpacing: columnSpacing,
        ),
      ),
    ),
  );
}

void main() {
  group('VerticalTextPage mark tap', () {
    testWidgets('a touch tap on a marked character reports the word', (
      tester,
    ) async {
      final taps = <MarkTapCall>[];

      await tester.pumpWidget(
        _build(
          onMarkTap: (word, position, token) {
            taps.add((word: word, position: position, token: token));
          },
        ),
      );
      await tester.pump();

      await tester.tapAt(tester.getCenter(find.text('リ')));
      await tester.pump();

      expect(taps, hasLength(1));
      expect(taps.single.word, 'アリス');
      expect(taps.single.position, isNot(Offset.zero));
    });

    testWidgets('every character of the mark reports the same token', (
      tester,
    ) async {
      final taps = <MarkTapCall>[];

      await tester.pumpWidget(
        _build(
          onMarkTap: (word, position, token) {
            taps.add((word: word, position: position, token: token));
          },
        ),
      );
      await tester.pump();

      for (final char in ['ア', 'リ', 'ス']) {
        await tester.tapAt(tester.getCenter(find.text(char)));
        await tester.pump();
      }

      expect(taps, hasLength(3));
      expect(taps.map((t) => t.token).toSet(), hasLength(1));
    });

    testWidgets('a touch tap on unmarked text reports nothing', (tester) async {
      final taps = <MarkTapCall>[];

      await tester.pumpWidget(
        _build(
          onMarkTap: (word, position, token) {
            taps.add((word: word, position: position, token: token));
          },
        ),
      );
      await tester.pump();

      await tester.tapAt(tester.getCenter(find.text('昨')));
      await tester.pump();

      expect(taps, isEmpty);
    });

    testWidgets('a tap on a marked character leaves the selection alone', (
      tester,
    ) async {
      // The reader is opening a summary, not dismissing what they selected.
      final selectionNotifications = <ViewerSelection?>[];

      await tester.pumpWidget(
        _build(
          selectionStart: 0,
          selectionEnd: 2,
          onMarkTap: (_, _, _) {},
          onSelectionChanged: selectionNotifications.add,
        ),
      );
      await tester.pump();

      await tester.tapAt(tester.getCenter(find.text('リ')));
      await tester.pump();

      expect(selectionNotifications, isEmpty);
    });

    testWidgets('the selection menu wins over the mark', (tester) async {
      // "アリス" is inside the selection here, so the tap means "act on what
      // I just selected", not "tell me about this word".
      final taps = <MarkTapCall>[];
      String? menuText;

      await tester.pumpWidget(
        _build(
          selectionStart: 0,
          selectionEnd: 5,
          onMarkTap: (word, position, token) {
            taps.add((word: word, position: position, token: token));
          },
          onContextMenu: (position, text) => menuText = text,
        ),
      );
      await tester.pump();

      await tester.tapAt(tester.getCenter(find.text('リ')));
      await tester.pump();

      expect(menuText, isNotNull);
      expect(taps, isEmpty);
    });

    testWidgets('a mouse click on a marked character reports nothing', (
      tester,
    ) async {
      // A mouse reaches the popup by hovering, and its click already means
      // "clear the selection".
      final taps = <MarkTapCall>[];
      final selectionNotifications = <ViewerSelection?>[];

      await tester.pumpWidget(
        _build(
          selectionStart: 0,
          selectionEnd: 2,
          onMarkTap: (word, position, token) {
            taps.add((word: word, position: position, token: token));
          },
          onSelectionChanged: selectionNotifications.add,
        ),
      );
      await tester.pump();

      final target = tester.getCenter(find.text('リ'));
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await mouse.addPointer(location: target);
      addTearDown(mouse.removePointer);
      await tester.pump();
      await mouse.down(target);
      await mouse.up();
      await tester.pump();

      expect(taps, isEmpty);
      expect(selectionNotifications, [null]);
    });

    testWidgets('a stylus tap on a marked character reports the word', (
      tester,
    ) async {
      final taps = <MarkTapCall>[];

      await tester.pumpWidget(
        _build(
          onMarkTap: (word, position, token) {
            taps.add((word: word, position: position, token: token));
          },
        ),
      );
      await tester.pump();

      final target = tester.getCenter(find.text('リ'));
      final stylus = await tester.createGesture(kind: PointerDeviceKind.stylus);
      await stylus.down(target);
      await stylus.up();
      await tester.pump();

      expect(taps, hasLength(1));
      expect(taps.single.word, 'アリス');
    });

    testWidgets('a tap in the gap beside a marked character reports it', (
      tester,
    ) async {
      // A finger aimed at a character in a wrapped column lands in the
      // unpainted gap often; the menu path already snaps there for the same
      // reason, and the mark test uses the same resolved character.
      final taps = <MarkTapCall>[];

      await tester.pumpWidget(
        _build(
          // Long enough to wrap at height 300, with the mark in the second
          // column.
          segments: const [
            PlainTextSegment(
              'あいうえおかきくけこさしすせそたちつてと'
              'なにぬねのアリスはひふへほまみむめもやゆ',
            ),
          ],
          onMarkTap: (word, position, token) {
            taps.add((word: word, position: position, token: token));
          },
        ),
      );
      await tester.pump();

      final firstColumn = tester.getRect(find.text('あ'));
      final marked = tester.getRect(find.text('リ'));
      expect(
        marked.right,
        lessThan(firstColumn.left),
        reason: 'the mark must be in a column left of the first',
      );
      // Inside the gap, but on the marked column's side of it: the midpoint
      // is equidistant from both columns and either is a legitimate answer.
      final inGap = Offset(
        marked.right + (firstColumn.left - marked.right) * 0.25,
        marked.center.dy,
      );
      expect(inGap.dx, greaterThan(marked.right));

      await tester.tapAt(inGap);
      await tester.pump();

      expect(taps, hasLength(1));
      expect(taps.single.word, 'アリス');
    });
  });
}
