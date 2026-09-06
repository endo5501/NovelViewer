import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/layout/shell_layout.dart';

void main() {
  group('resolveShellLayout', () {
    test('a width below the breakpoint selects the narrow layout', () {
      expect(
        resolveShellLayout(width: 744, breakpoint: 800),
        ShellLayout.narrow,
      );
    });

    test('a width equal to the breakpoint selects the wide layout', () {
      // The breakpoint is the narrowest width the three-column layout is
      // supported at, so it belongs to the wide side.
      expect(resolveShellLayout(width: 800, breakpoint: 800), ShellLayout.wide);
    });

    test('a width above the breakpoint selects the wide layout', () {
      expect(
        resolveShellLayout(width: 1133, breakpoint: 800),
        ShellLayout.wide,
      );
    });

    test('the same width follows the breakpoint it is given', () {
      // What makes the decision testable: the width the test process itself
      // renders at is irrelevant, and no platform is consulted.
      expect(
        resolveShellLayout(width: 800, breakpoint: 900),
        ShellLayout.narrow,
      );
      expect(resolveShellLayout(width: 800, breakpoint: 700), ShellLayout.wide);
    });
  });
}
