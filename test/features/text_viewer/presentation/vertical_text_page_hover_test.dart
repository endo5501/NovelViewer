import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

typedef MarkEnterCall = ({String word, Offset position, HoverToken token});

Widget _build({
  required Map<String, MarkStyle> markedWords,
  List<TextSegment>? segments,
  void Function(String word, Offset position, HoverToken token)? onMarkEnter,
  void Function(HoverToken token)? onMarkExit,
  VoidCallback? onHoverHideRequest,
  ValueChanged<String?>? onSelectionChanged,
}) {
  return MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 400,
        child: VerticalTextPage(
          segments: segments ?? const [PlainTextSegment('アリスが歩く')],
          baseStyle: const TextStyle(fontSize: 20.0),
          markedWords: markedWords,
          onMarkEnter: onMarkEnter,
          onMarkExit: onMarkExit,
          onHoverHideRequest: onHoverHideRequest,
          onSelectionChanged: onSelectionChanged,
        ),
      ),
    ),
  );
}

Future<TestGesture> _setUpMouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  return mouse;
}

void main() {
  group('VerticalTextPage hover detection — wiring', () {
    testWidgets(
      'accepts onMarkEnter / onMarkExit / onHoverHideRequest callbacks as optional props',
      (tester) async {
        await tester.pumpWidget(_build(
          markedWords: const {'アリス': MarkStyle.solid},
          onMarkEnter: (_, _, _) {},
          onMarkExit: (_) {},
          onHoverHideRequest: () {},
        ));
        expect(find.byType(VerticalTextPage), findsOneWidget);
      },
    );

    testWidgets('all hover callbacks default to null without error',
        (tester) async {
      await tester.pumpWidget(_build(
        markedWords: const {'アリス': MarkStyle.solid},
      ));
      expect(find.byType(VerticalTextPage), findsOneWidget);
    });
  });

  group('VerticalTextPage hover detection — onMarkEnter / onMarkExit', () {
    testWidgets('hovering on a marked char fires onMarkEnter once with word, '
        'global position, and entry-range token', (tester) async {
      final calls = <MarkEnterCall>[];
      await tester.pumpWidget(_build(
        markedWords: const {'アリス': MarkStyle.solid},
        onMarkEnter: (word, pos, token) =>
            calls.add((word: word, position: pos, token: token)),
      ));
      await tester.pumpAndSettle();

      final riCenter = tester.getCenter(find.text('リ'));
      final mouse = await _setUpMouse(tester);
      await mouse.moveTo(riCenter);
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.first.word, 'アリス');
      expect(calls.first.position, riCenter);
      expect(calls.first.token.start, 0);
      expect(calls.first.token.end, 3);
    });

    testWidgets(
      'hovering on different chars within the same mark does NOT re-fire onMarkEnter',
      (tester) async {
        final calls = <MarkEnterCall>[];
        await tester.pumpWidget(_build(
          markedWords: const {'アリス': MarkStyle.solid},
          onMarkEnter: (word, pos, token) =>
              calls.add((word: word, position: pos, token: token)),
        ));
        await tester.pumpAndSettle();

        final mouse = await _setUpMouse(tester);
        await mouse.moveTo(tester.getCenter(find.text('ア')));
        await tester.pumpAndSettle();
        await mouse.moveTo(tester.getCenter(find.text('リ')));
        await tester.pumpAndSettle();
        await mouse.moveTo(tester.getCenter(find.text('ス')));
        await tester.pumpAndSettle();

        // Each char belongs to the same mark "アリス" → entries 0,1,2 (token start=0,end=3).
        // The differential check coalesces these into a single onMarkEnter.
        expect(calls, hasLength(1));
        expect(calls.first.token, (start: 0, end: 3));
      },
    );

    testWidgets('moving hover from marked char to unmarked char fires onMarkExit',
        (tester) async {
      final exits = <HoverToken>[];
      await tester.pumpWidget(_build(
        markedWords: const {'アリス': MarkStyle.solid},
        onMarkExit: exits.add,
      ));
      await tester.pumpAndSettle();

      final mouse = await _setUpMouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('ア')));
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(find.text('が')));
      await tester.pumpAndSettle();

      expect(exits, hasLength(1));
      expect(exits.first, (start: 0, end: 3));
    });

    testWidgets(
      'moving hover from one mark to a different mark fires onMarkExit(old) '
      'then onMarkEnter(new) in that order',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(_build(
          segments: const [PlainTextSegment('アリスとボブが歩く')],
          markedWords: const {
            'アリス': MarkStyle.solid,
            'ボブ': MarkStyle.solid,
          },
          onMarkEnter: (word, _, token) =>
              events.add('enter:$word@${token.start}-${token.end}'),
          onMarkExit: (token) =>
              events.add('exit:${token.start}-${token.end}'),
        ));
        await tester.pumpAndSettle();

        final mouse = await _setUpMouse(tester);
        await mouse.moveTo(tester.getCenter(find.text('リ')));
        await tester.pumpAndSettle();
        await mouse.moveTo(tester.getCenter(find.text('ボ')));
        await tester.pumpAndSettle();

        // Layout: ア(0) リ(1) ス(2) と(3) ボ(4) ブ(5) が(6) 歩(7) く(8)
        expect(events, [
          'enter:アリス@0-3',
          'exit:0-3',
          'enter:ボブ@4-6',
        ]);
      },
    );

    testWidgets('hovering only on unmarked text fires no callbacks',
        (tester) async {
      var entered = 0;
      var exited = 0;
      await tester.pumpWidget(_build(
        markedWords: const {'アリス': MarkStyle.solid},
        onMarkEnter: (_, _, _) => entered++,
        onMarkExit: (_) => exited++,
      ));
      await tester.pumpAndSettle();

      final mouse = await _setUpMouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('が')));
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(find.text('歩')));
      await tester.pumpAndSettle();

      expect(entered, 0);
      expect(exited, 0);
    });
  });

  group('VerticalTextPage hover detection — region exit', () {
    testWidgets(
      'when mouse leaves the page region after entering a mark, onMarkExit fires',
      (tester) async {
        final exits = <HoverToken>[];
        await tester.pumpWidget(_build(
          markedWords: const {'アリス': MarkStyle.solid},
          onMarkExit: exits.add,
        ));
        await tester.pumpAndSettle();

        final mouse = await _setUpMouse(tester);
        await mouse.moveTo(tester.getCenter(find.text('リ')));
        await tester.pumpAndSettle();
        // Move WAY outside the page to trigger MouseRegion.onExit.
        await mouse.moveTo(const Offset(2000, 2000));
        await tester.pumpAndSettle();

        expect(exits, contains((start: 0, end: 3)));
      },
    );
  });

  group('VerticalTextPage hover detection — pan/drag selection start', () {
    testWidgets(
      'starting a primary drag (selection) fires onHoverHideRequest',
      (tester) async {
        var hideRequests = 0;
        await tester.pumpWidget(_build(
          markedWords: const {'アリス': MarkStyle.solid},
          onHoverHideRequest: () => hideRequests++,
          onSelectionChanged: (_) {},
        ));
        await tester.pumpAndSettle();

        // Use a Listener-friendly drag: press, drag, release.
        final start = tester.getCenter(find.text('リ'));
        final drag = await tester.startGesture(start);
        await tester.pump();
        await drag.moveBy(const Offset(0, 30));
        await tester.pump();
        await drag.up();
        await tester.pumpAndSettle();

        expect(hideRequests, greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      'a plain tap (no drag) does NOT fire onHoverHideRequest — only real '
      'drags should dismiss the popup',
      (tester) async {
        var hideRequests = 0;
        await tester.pumpWidget(_build(
          markedWords: const {'アリス': MarkStyle.solid},
          onHoverHideRequest: () => hideRequests++,
          onSelectionChanged: (_) {},
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('リ'));
        await tester.pumpAndSettle();

        expect(hideRequests, 0,
            reason:
                'Pan-down on a tap should not be treated as a drag for popup '
                'lifecycle — pure clicks must leave the popup alone');
      },
    );

    testWidgets(
      'after a drag-induced hide, hovering the same charIndex again restores '
      'the popup (the drag teardown also clears the hover diff state)',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(_build(
          markedWords: const {'アリス': MarkStyle.solid},
          onMarkEnter: (word, _, _) => events.add('enter:$word'),
          onMarkExit: (_) => events.add('exit'),
          onHoverHideRequest: () => events.add('hide'),
          onSelectionChanged: (_) {},
        ));
        await tester.pumpAndSettle();

        // Hover to enter the mark.
        final markCenter = tester.getCenter(find.text('リ'));
        final mouse = await _setUpMouse(tester);
        await mouse.moveTo(markCenter);
        await tester.pumpAndSettle();
        expect(events, ['enter:アリス']);

        // Start a real drag from the same position.
        final drag = await tester.startGesture(markCenter);
        await tester.pump();
        await drag.moveBy(const Offset(0, 30));
        await tester.pump();
        await drag.up();
        await tester.pumpAndSettle();
        expect(events, contains('hide'));

        events.clear();

        // Move the pointer slightly within the same mark glyph. If hover
        // diff state was correctly reset by the drag, this should re-fire
        // onMarkEnter even though the charIndex is unchanged.
        await mouse.moveTo(markCenter + const Offset(0.5, 0.5));
        await tester.pumpAndSettle();
        expect(events, contains('enter:アリス'),
            reason:
                'After the drag-driven hide, the next hover on the same '
                'charIndex must re-fire onMarkEnter');
      },
    );
  });

  group('VerticalTextPage hover detection — markedWords change handling', () {
    testWidgets(
      'when markedWords mutates while the pointer is stationary, the next '
      'hover event reflects the new marks (no stale-charIndex suppression)',
      (tester) async {
        final events = <String>[];

        Future<void> pumpWith(Map<String, MarkStyle> markedWords) async {
          await tester.pumpWidget(_build(
            markedWords: markedWords,
            onMarkEnter: (word, _, _) => events.add('enter:$word'),
            onMarkExit: (_) => events.add('exit'),
          ));
          await tester.pumpAndSettle();
        }

        await pumpWith(const {'アリス': MarkStyle.solid});

        final mouse = await _setUpMouse(tester);
        final markCenter = tester.getCenter(find.text('リ'));
        await mouse.moveTo(markCenter);
        await tester.pumpAndSettle();
        expect(events, ['enter:アリス']);

        events.clear();

        // Remove 'アリス' from markedWords — pointer stays put.
        await pumpWith(const {});

        // Tiny pointer wobble that hits the same charIndex. Without the
        // markedWords-aware diff, the early-exit at charIndex == _last
        // would swallow this event.
        await mouse.moveTo(markCenter + const Offset(0.5, 0.5));
        await tester.pumpAndSettle();
        expect(events, contains('exit'),
            reason:
                'Removing the hovered mark must trigger onMarkExit on the '
                'next hover event, otherwise the popup lingers over '
                'unmarked text');
      },
    );
  });

  group('VerticalTextPage hover detection — segments change resets state', () {
    testWidgets(
      'after segments change, the next hover on the same screen position '
      'fires onMarkEnter again (state was reset)',
      (tester) async {
        var enterCount = 0;
        await tester.pumpWidget(_build(
          segments: const [PlainTextSegment('アリスが歩く')],
          markedWords: const {'アリス': MarkStyle.solid},
          onMarkEnter: (_, _, _) => enterCount++,
        ));
        await tester.pumpAndSettle();

        final mouse = await _setUpMouse(tester);
        await mouse.moveTo(tester.getCenter(find.text('リ')));
        await tester.pumpAndSettle();
        expect(enterCount, 1);

        // Same marked word in different surrounding text → triggers
        // didUpdateWidget segments-changed branch.
        await tester.pumpWidget(_build(
          segments: const [PlainTextSegment('やあアリスです')],
          markedWords: const {'アリス': MarkStyle.solid},
          onMarkEnter: (_, _, _) => enterCount++,
        ));
        await tester.pumpAndSettle();

        // Move into the new mark. Without the reset, the stale
        // _lastHoverCharIndex / _lastHoverToken could suppress this enter.
        await mouse.moveTo(tester.getCenter(find.text('リ')));
        await tester.pumpAndSettle();
        expect(enterCount, 2);
      },
    );
  });

  group('VerticalTextPage hover detection — early-frame safety', () {
    testWidgets(
      'hovering immediately on first frame (before hit regions are built) '
      'does not throw',
      (tester) async {
        await tester.pumpWidget(_build(
          markedWords: const {'アリス': MarkStyle.solid},
        ));
        // NO pumpAndSettle — only the initial frame. _hitRegions is still empty.
        final mouse = await _setUpMouse(tester);
        await mouse.moveTo(const Offset(100, 100));
        // Should not throw; the next pump rebuilds hit regions but that is
        // beyond the scope of this safety test.
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
