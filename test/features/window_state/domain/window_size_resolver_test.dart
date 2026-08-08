import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/window_state/domain/window_size_resolver.dart';
import 'package:novel_viewer/features/window_state/domain/window_state.dart';

void main() {
  // Comfortably larger than every size used below, so tests that are not about
  // clamping never trip over it.
  const roomyWorkArea = Size(3840, 2160);

  group('resolveWindowSize - rule 1: nothing stored', () {
    test('falls back to the default size', () {
      expect(
        resolveWindowSize(WindowState.empty, roomyWorkArea),
        kDefaultWindowSize,
      );
      expect(kDefaultWindowSize, const Size(1280, 720));
    });

    test('falls back when only one axis was stored', () {
      expect(
        resolveWindowSize(const WindowState(width: 1600), roomyWorkArea),
        kDefaultWindowSize,
      );
    });
  });

  group('resolveWindowSize - rule 2: invalid values', () {
    test('falls back on a non-positive axis', () {
      expect(
        resolveWindowSize(
          const WindowState(width: -1600, height: 1000),
          roomyWorkArea,
        ),
        kDefaultWindowSize,
      );
      expect(
        resolveWindowSize(
          const WindowState(width: 1600, height: 0),
          roomyWorkArea,
        ),
        kDefaultWindowSize,
      );
    });

    test('falls back on a non-finite axis', () {
      expect(
        resolveWindowSize(
          const WindowState(width: double.infinity, height: 1000),
          roomyWorkArea,
        ),
        kDefaultWindowSize,
      );
      expect(
        resolveWindowSize(
          const WindowState(width: 1600, height: double.nan),
          roomyWorkArea,
        ),
        kDefaultWindowSize,
      );
    });

    test('the fallback is itself clamped to the work area', () {
      // A default larger than the screen must not slip through unvalidated.
      expect(
        resolveWindowSize(WindowState.empty, const Size(1024, 640)),
        const Size(1024, 640),
      );
    });
  });

  group('resolveWindowSize - rule 3: minimum size', () {
    test('raises an axis below the minimum', () {
      expect(
        resolveWindowSize(
          const WindowState(width: 320, height: 240),
          roomyWorkArea,
        ),
        kMinimumWindowSize,
      );
      expect(kMinimumWindowSize, const Size(800, 600));
    });

    test('raises only the axis that is too small', () {
      expect(
        resolveWindowSize(
          const WindowState(width: 320, height: 1000),
          roomyWorkArea,
        ),
        const Size(800, 1000),
      );
    });

    test('leaves a size at exactly the minimum untouched', () {
      expect(
        resolveWindowSize(
          const WindowState(width: 800, height: 600),
          roomyWorkArea,
        ),
        const Size(800, 600),
      );
    });
  });

  group('resolveWindowSize - rule 4: work area clamp', () {
    test('clamps a size larger than the work area', () {
      expect(
        resolveWindowSize(
          const WindowState(width: 3400, height: 1900),
          const Size(1920, 1040),
        ),
        const Size(1920, 1040),
      );
    });

    test('clamps only the axis that overflows', () {
      expect(
        resolveWindowSize(
          const WindowState(width: 3400, height: 900),
          const Size(1920, 1040),
        ),
        const Size(1920, 900),
      );
    });

    test('leaves a size that fits untouched', () {
      expect(
        resolveWindowSize(
          const WindowState(width: 1600, height: 1000),
          const Size(1920, 1040),
        ),
        const Size(1600, 1000),
      );
    });
  });

  group('resolveWindowSize - rule 5: clamp wins over the minimum', () {
    test('fitting on screen beats honouring the minimum size', () {
      expect(
        resolveWindowSize(
          const WindowState(width: 1600, height: 1000),
          const Size(640, 480),
        ),
        const Size(640, 480),
      );
    });

    test('a stored size below the minimum is still capped by a tiny work area',
        () {
      expect(
        resolveWindowSize(
          const WindowState(width: 320, height: 240),
          const Size(640, 480),
        ),
        const Size(640, 480),
      );
    });
  });

  group('resolveWindowSize - unusable work area', () {
    test('ignores a non-positive work area and applies the minimum only', () {
      expect(
        resolveWindowSize(
          const WindowState(width: 320, height: 240),
          Size.zero,
        ),
        kMinimumWindowSize,
      );
    });

    test('ignores a null work area', () {
      expect(
        resolveWindowSize(const WindowState(width: 3400, height: 1900), null),
        const Size(3400, 1900),
      );
    });
  });
}
