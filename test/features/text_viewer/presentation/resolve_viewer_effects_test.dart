import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';

/// Builds a [ViewerEffectInputs] with neutral defaults (no effect fires) so each
/// test only sets the fields relevant to the case under test.
ViewerEffectInputs inputs({
  int totalPages = 5,
  int currentPage = 0,
  int? targetPage,
  int? scheduledTargetPage,
  bool jumpToLastPagePending = false,
  int? pendingTtsOffset,
  List<int> charOffsetPerPage = const [0, 50, 100, 150, 200],
  List<int> firstLinePerPage = const [1, 1, 1, 1, 1],
  int lastReportedLine = 1,
  bool constraintsChanged = false,
  bool isAnimating = false,
}) {
  return ViewerEffectInputs(
    totalPages: totalPages,
    currentPage: currentPage,
    targetPage: targetPage,
    scheduledTargetPage: scheduledTargetPage,
    jumpToLastPagePending: jumpToLastPagePending,
    pendingTtsOffset: pendingTtsOffset,
    charOffsetPerPage: charOffsetPerPage,
    firstLinePerPage: firstLinePerPage,
    lastReportedLine: lastReportedLine,
    constraintsChanged: constraintsChanged,
    isAnimating: isAnimating,
  );
}

void main() {
  group('resolveViewerEffects — no-op', () {
    test('idle snapshot produces no effects', () {
      expect(resolveViewerEffects(inputs()), ViewerEffects.none);
    });

    test('targetPage equal to currentPage does not fire', () {
      expect(resolveViewerEffects(inputs(targetPage: 0, currentPage: 0)),
          ViewerEffects.none);
    });

    test('idle snapshot has no jumps', () {
      final fx = resolveViewerEffects(inputs());
      expect(fx.targetJumpToPage, isNull);
      expect(fx.lastJumpToPage, isNull);
      expect(fx.animatedGoToPage, isNull);
    });

    test('single page never animates TTS even when offset pending', () {
      // totalPages must be > 1 for ④; with one page the offset stays pending.
      final fx = resolveViewerEffects(inputs(
        totalPages: 1,
        pendingTtsOffset: 100,
        charOffsetPerPage: const [0],
        firstLinePerPage: const [1],
      ));
      expect(fx.animatedGoToPage, isNull);
      expect(fx.consumeTtsOffset, isFalse);
    });
  });

  group('resolveViewerEffects — ① target-line jump', () {
    test('fires and schedules the re-entrancy guard', () {
      final fx = resolveViewerEffects(inputs(targetPage: 3, currentPage: 0));
      expect(fx.targetJumpToPage, 3);
      expect(fx.newScheduledTargetPage, 3);
      expect(fx.lastJumpToPage, isNull);
    });

    test('does not re-fire when already scheduled (re-entrancy guard)', () {
      final fx = resolveViewerEffects(
          inputs(targetPage: 3, currentPage: 0, scheduledTargetPage: 3));
      expect(fx.targetJumpToPage, isNull);
      expect(fx.newScheduledTargetPage, isNull);
    });
  });

  group('resolveViewerEffects — ③ jump-to-last-page', () {
    test('fires and consumes when not already on last page', () {
      final fx = resolveViewerEffects(
          inputs(totalPages: 4, currentPage: 0, jumpToLastPagePending: true));
      expect(fx.lastJumpToPage, 3);
      expect(fx.consumeJumpToLastPage, isTrue);
    });

    test('consumes without jumping when already on last page', () {
      final fx = resolveViewerEffects(
          inputs(totalPages: 4, currentPage: 3, jumpToLastPagePending: true));
      expect(fx.lastJumpToPage, isNull);
      expect(fx.consumeJumpToLastPage, isTrue);
    });

    test('does not consume when there are no pages', () {
      final fx = resolveViewerEffects(inputs(
        totalPages: 0,
        jumpToLastPagePending: true,
        charOffsetPerPage: const [0],
        firstLinePerPage: const [1],
      ));
      expect(fx.consumeJumpToLastPage, isFalse);
      expect(fx.lastJumpToPage, isNull);
    });
  });

  group('resolveViewerEffects — ④ TTS auto-navigate', () {
    test('navigates to the page containing the offset and consumes', () {
      final fx = resolveViewerEffects(inputs(
        totalPages: 3,
        currentPage: 0,
        pendingTtsOffset: 120,
        charOffsetPerPage: const [0, 50, 100],
        firstLinePerPage: const [1, 1, 1],
      ));
      expect(fx.animatedGoToPage, 2); // last offset <= 120 is index 2 (100)
      expect(fx.consumeTtsOffset, isTrue);
    });

    test('consumes without navigating when offset is on the current page', () {
      final fx = resolveViewerEffects(inputs(
        totalPages: 3,
        currentPage: 0,
        pendingTtsOffset: 10,
        charOffsetPerPage: const [0, 50, 100],
        firstLinePerPage: const [1, 1, 1],
      ));
      expect(fx.animatedGoToPage, isNull);
      expect(fx.consumeTtsOffset, isTrue);
    });
  });

  group('resolveViewerEffects — ⑤ report line', () {
    test('reports when the current page first line changed', () {
      final fx = resolveViewerEffects(inputs(
        firstLinePerPage: const [7, 7, 7, 7, 7],
        lastReportedLine: 3,
      ));
      expect(fx.reportLine, 7);
    });

    test('does not report when unchanged', () {
      final fx = resolveViewerEffects(inputs(
        firstLinePerPage: const [7, 7, 7, 7, 7],
        lastReportedLine: 7,
      ));
      expect(fx.reportLine, isNull);
    });
  });

  group('resolveViewerEffects — ② cancel animation', () {
    test('cancels when constraints changed mid-animation', () {
      final fx = resolveViewerEffects(
          inputs(constraintsChanged: true, isAnimating: true));
      expect(fx.cancelAnimation, isTrue);
    });

    test('does not cancel when not animating', () {
      final fx = resolveViewerEffects(
          inputs(constraintsChanged: true, isAnimating: false));
      expect(fx.cancelAnimation, isFalse);
    });

    test('does not cancel when constraints unchanged', () {
      final fx = resolveViewerEffects(
          inputs(constraintsChanged: false, isAnimating: true));
      expect(fx.cancelAnimation, isFalse);
    });
  });

  group('resolveViewerEffects — priority & consume-once', () {
    test('target and last-page jumps are emitted independently when both fire',
        () {
      // Both effects are emitted; apply order (① then ③) lands on the last
      // page exactly as the prior two-post-frame code did.
      final fx = resolveViewerEffects(inputs(
        totalPages: 5,
        currentPage: 0,
        targetPage: 2,
        jumpToLastPagePending: true,
      ));
      expect(fx.targetJumpToPage, 2);
      expect(fx.lastJumpToPage, 4);
      expect(fx.consumeJumpToLastPage, isTrue);
      expect(fx.newScheduledTargetPage, 2);
    });

    test('last-page one-shot does not re-fire after consumption', () {
      // build 1: pending → fires + consume.
      final first = resolveViewerEffects(
          inputs(totalPages: 4, currentPage: 0, jumpToLastPagePending: true));
      expect(first.lastJumpToPage, 3);
      expect(first.consumeJumpToLastPage, isTrue);
      // build 2: apply cleared the flag → no effect.
      final second = resolveViewerEffects(
          inputs(totalPages: 4, currentPage: 0, jumpToLastPagePending: false));
      expect(second.lastJumpToPage, isNull);
      expect(second.consumeJumpToLastPage, isFalse);
    });

    test('TTS one-shot does not re-fire after consumption', () {
      final first = resolveViewerEffects(inputs(
        totalPages: 3,
        pendingTtsOffset: 120,
        charOffsetPerPage: const [0, 50, 100],
        firstLinePerPage: const [1, 1, 1],
      ));
      expect(first.animatedGoToPage, 2);
      final second = resolveViewerEffects(inputs(
        totalPages: 3,
        pendingTtsOffset: null,
        charOffsetPerPage: const [0, 50, 100],
        firstLinePerPage: const [1, 1, 1],
      ));
      expect(second.animatedGoToPage, isNull);
      expect(second.consumeTtsOffset, isFalse);
    });
  });
}
