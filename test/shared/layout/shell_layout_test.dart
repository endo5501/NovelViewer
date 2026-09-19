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
      // The breakpoint is the narrowest width at which the text viewer and
      // the search results column share the body, so it belongs to the wide
      // side.
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

  group('fileBrowserDrawerWidth', () {
    test('a wide display is capped rather than followed', () {
      // The drawer is a file list, not a second body: past the cap the extra
      // width buys nothing and only hides more of the text behind it.
      expect(fileBrowserDrawerWidth(displayWidth: 1440), 560);
    });

    test(
      'the cap is reached exactly at the display width that produces it',
      () {
        expect(fileBrowserDrawerWidth(displayWidth: 624), 560);
      },
    );

    test(
      'a display narrower than the cap keeps a strip of the body visible',
      () {
        // 390 is a phone in portrait. Subtracting the gutter is what makes the
        // drawer read as an overlay rather than as the whole screen.
        expect(fileBrowserDrawerWidth(displayWidth: 390), 326);
      },
    );

    test('a display just under the cap follows the width', () {
      expect(fileBrowserDrawerWidth(displayWidth: 600), 536);
    });
  });
}
