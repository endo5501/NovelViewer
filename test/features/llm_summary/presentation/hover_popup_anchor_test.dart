import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_anchor.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';

void main() {
  // Use the same numeric defaults that the implementation reports through
  // its public constants, so the tests stay in sync if the popup ever needs
  // to grow.
  const w = kHoverPopupApproxWidth;
  const h = kHoverPopupApproxHeight;
  const g = kHoverPopupGap;
  const screen = Size(1920, 1080);

  group('computePopupAnchor — horizontal mode', () {
    test('places top-left of popup down-right of pointer', () {
      final anchor = computePopupAnchor(
        mode: TextDisplayMode.horizontal,
        pointer: const Offset(100, 100),
        screenSize: screen,
      );
      expect(anchor.left, 100 + g);
      expect(anchor.top, 100 + g);
    });

    test('horizontal mode does not flip even near a screen edge', () {
      // Horizontal popup placement is intentionally simple — the existing
      // archived hover behavior never flipped.
      final anchor = computePopupAnchor(
        mode: TextDisplayMode.horizontal,
        pointer: const Offset(1900, 1070),
        screenSize: screen,
      );
      expect(anchor.left, 1900 + g);
      expect(anchor.top, 1070 + g);
    });
  });

  group('computePopupAnchor — vertical mode default placement', () {
    test('places bottom-left of popup up-right of pointer when room permits',
        () {
      // pointer comfortably away from any edge.
      final anchor = computePopupAnchor(
        mode: TextDisplayMode.vertical,
        pointer: const Offset(800, 600),
        screenSize: screen,
      );
      // bottom-left at (pointer.dx + g, pointer.dy - g)
      // → top-left at (pointer.dx + g, pointer.dy - g - h)
      expect(anchor.left, 800 + g);
      expect(anchor.top, 600 - g - h);
    });
  });

  group('computePopupAnchor — vertical mode horizontal flip', () {
    test(
        'when default placement would overflow the right edge, the popup '
        'flips to the left of the pointer',
        () {
      // pointer near right edge: default left would be screen.width - small,
      // and left + w would exceed screen.width.
      final pointer = Offset(screen.width - 50, 600);
      final anchor = computePopupAnchor(
        mode: TextDisplayMode.vertical,
        pointer: pointer,
        screenSize: screen,
      );
      // Flipped: popup right edge sits to the left of pointer, so its top-left
      // x is pointer.dx - g - w.
      expect(anchor.left, pointer.dx - g - w);
      // Vertical (above) placement is preserved.
      expect(anchor.top, pointer.dy - g - h);
    });
  });

  group('computePopupAnchor — vertical mode vertical flip', () {
    test(
        'when default placement would overflow the top edge, the popup '
        'flips to below the pointer',
        () {
      // pointer near top edge: pointer.dy - g - h would be negative.
      const pointer = Offset(800, 20);
      final anchor = computePopupAnchor(
        mode: TextDisplayMode.vertical,
        pointer: pointer,
        screenSize: screen,
      );
      // Flipped vertical: top-left y is pointer.dy + g.
      expect(anchor.top, pointer.dy + g);
      // Horizontal (right) placement is preserved.
      expect(anchor.left, pointer.dx + g);
    });
  });

  group('computePopupAnchor — vertical mode double flip', () {
    test('flips both axes when near the top-right corner', () {
      final pointer = Offset(screen.width - 50, 20);
      final anchor = computePopupAnchor(
        mode: TextDisplayMode.vertical,
        pointer: pointer,
        screenSize: screen,
      );
      expect(anchor.left, pointer.dx - g - w);
      expect(anchor.top, pointer.dy + g);
    });
  });

  group('computePopupAnchor — clamps to keep popup on-screen', () {
    test(
        'narrow window: horizontal-flip would push left negative, so left is '
        'clamped to >= 0',
        () {
      // screen narrower than popup-width + gap so even the flipped placement
      // would push left negative.
      const narrow = Size(300, 1080);
      const pointer = Offset(150, 600);
      final anchor = computePopupAnchor(
        mode: TextDisplayMode.vertical,
        pointer: pointer,
        screenSize: narrow,
      );
      expect(anchor.left, greaterThanOrEqualTo(0.0),
          reason: 'popup must not hang off the left edge');
    });

    test(
        'short window: vertical-flip would push popup off the bottom, so top '
        'is clamped to keep the popup visible',
        () {
      // Even the flipped placement (top = dy + g) would push the popup
      // bottom past the screen.
      const short = Size(1920, 180);
      const pointer = Offset(800, 80);
      final anchor = computePopupAnchor(
        mode: TextDisplayMode.vertical,
        pointer: pointer,
        screenSize: short,
      );
      expect(anchor.top + h, lessThanOrEqualTo(short.height),
          reason: 'popup bottom must not extend past screen bottom');
      expect(anchor.top, greaterThanOrEqualTo(0.0),
          reason: 'popup top must not be negative');
    });

  });
}
