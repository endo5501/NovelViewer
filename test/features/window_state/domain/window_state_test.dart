import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/window_state/domain/window_state.dart';

void main() {
  group('WindowState', () {
    test('empty represents "nothing was ever saved"', () {
      const state = WindowState.empty;
      expect(state.width, isNull);
      expect(state.height, isNull);
      expect(state.maximized, isFalse);
      expect(state.hasSize, isFalse);
    });

    test('hasSize is true only when both axes are present', () {
      expect(const WindowState(width: 1600, height: 1000).hasSize, isTrue);
      expect(const WindowState(width: 1600).hasSize, isFalse);
      expect(const WindowState(height: 1000).hasSize, isFalse);
    });

    test('maximized is independent of the stored size', () {
      const state = WindowState(width: 1400, height: 900, maximized: true);
      expect(state.width, 1400);
      expect(state.height, 900);
      expect(state.maximized, isTrue);
    });

    test('copyWith replaces only the given fields', () {
      const state = WindowState(width: 1400, height: 900);
      final maximized = state.copyWith(maximized: true);
      expect(maximized.width, 1400);
      expect(maximized.height, 900);
      expect(maximized.maximized, isTrue);
    });

    test('value equality holds for identical field sets', () {
      expect(
        const WindowState(width: 1400, height: 900, maximized: true),
        const WindowState(width: 1400, height: 900, maximized: true),
      );
      expect(
        const WindowState(width: 1400, height: 900),
        isNot(const WindowState(width: 1400, height: 901)),
      );
    });
  });
}
