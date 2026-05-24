// Spike test for OpenSpec change `llm-summary-hover-popup` task 1.1.
//
// Verifies that `TextSpan.onEnter` / `onExit` fire on a decoration-bearing
// TextSpan nested inside a `SelectableText.rich`, and that pointer transitions
// between adjacent marked / unmarked spans produce the expected enter/exit
// sequence. If any expectation here fails, the design must fall back to the
// WidgetSpan + MouseRegion alternative documented in design.md R1 (b).
//
// This file lives under test/spike/ and is throwaway — delete after the
// design decision is confirmed.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHarness({
  required void Function(String word, Offset position) onEnter,
  required void Function(String word) onExit,
}) {
  TextSpan markedSpan(String word) => TextSpan(
        text: word,
        style: const TextStyle(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.solid,
        ),
        mouseCursor: SystemMouseCursors.help,
        onEnter: (event) => onEnter(word, event.position),
        onExit: (_) => onExit(word),
      );

  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: DefaultTextStyle(
          // Large, monospace-ish font so adjacent spans have predictable widths.
          style: const TextStyle(fontSize: 40, color: Colors.black),
          child: SelectableText.rich(
            TextSpan(
              style: const TextStyle(fontSize: 40, color: Colors.black),
              children: [
                const TextSpan(text: 'AAA '),
                markedSpan('BBB'),
                const TextSpan(text: ' '),
                markedSpan('CCC'),
                const TextSpan(text: ' DDD'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'TextSpan.onEnter/onExit fire on decoration-bearing span inside SelectableText.rich',
    (tester) async {
      final enters = <String>[];
      final exits = <String>[];
      Offset? lastEnterPosition;

      await tester.pumpWidget(_buildHarness(
        onEnter: (word, position) {
          enters.add(word);
          lastEnterPosition = position;
        },
        onExit: exits.add,
      ));

      final textFinder = find.byType(SelectableText);
      expect(textFinder, findsOneWidget);

      final box = tester.renderObject<RenderBox>(textFinder);
      final topLeft = box.localToGlobal(Offset.zero);
      final size = box.size;

      // Approximate horizontal positions for each span. The harness uses
      // 5 plain + 5 marked segments separated by spaces. With monospace-ish
      // fallback fonts the layout is roughly even; we sample at fractional
      // widths and verify the marked span fires for points in its band.
      final yMid = topLeft.dy + size.height / 2;
      Offset xAt(double frac) =>
          Offset(topLeft.dx + size.width * frac, yMid);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(-100, -100));
      addTearDown(gesture.removePointer);

      // 1. Enter the BBB region (somewhere in the second quarter).
      await gesture.moveTo(xAt(0.30));
      await tester.pumpAndSettle();

      expect(enters, contains('BBB'),
          reason: 'Hovering over BBB should fire its onEnter');
      expect(exits, isEmpty,
          reason: 'No exit should fire while still inside BBB');
      expect(lastEnterPosition, isNotNull,
          reason: 'event.position should be populated');

      // 2. Move off BBB to the gap between BBB and CCC.
      enters.clear();
      exits.clear();
      await gesture.moveTo(xAt(0.50));
      await tester.pumpAndSettle();

      expect(exits, contains('BBB'),
          reason: 'Moving off BBB should fire its onExit');

      // 3. Move onto CCC region.
      enters.clear();
      exits.clear();
      await gesture.moveTo(xAt(0.70));
      await tester.pumpAndSettle();

      expect(enters, contains('CCC'),
          reason: 'Moving onto CCC should fire its onEnter');

      // 4. Move directly from CCC back into BBB (cross adjacent marked spans).
      enters.clear();
      exits.clear();
      await gesture.moveTo(xAt(0.30));
      await tester.pumpAndSettle();

      expect(exits, contains('CCC'),
          reason: 'Leaving CCC must fire its onExit');
      expect(enters, contains('BBB'),
          reason: 'Entering BBB must fire its onEnter');

      // 5. Move completely off the text widget.
      enters.clear();
      exits.clear();
      await gesture.moveTo(const Offset(-100, -100));
      await tester.pumpAndSettle();

      expect(exits, contains('BBB'),
          reason: 'Moving off the widget entirely should exit BBB');
    },
  );
}
