import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/window_state/domain/window_size_resolver.dart';
import 'package:novel_viewer/shared/layout/shell_layout.dart';
import 'package:novel_viewer/shared/providers/layout_providers.dart';

void main() {
  group('rightColumnVisibleProvider', () {
    test('initial value is false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(rightColumnVisibleProvider), isFalse);
    });

    test('toggle changes value to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(rightColumnVisibleProvider.notifier).toggle();
      expect(container.read(rightColumnVisibleProvider), isTrue);
    });

    test('toggle twice returns to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(rightColumnVisibleProvider.notifier).toggle();
      container.read(rightColumnVisibleProvider.notifier).toggle();
      expect(container.read(rightColumnVisibleProvider), isFalse);
    });
  });

  group('shellBreakpointProvider', () {
    test(
      'defaults to the narrowest width the three columns are supported at',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(shellBreakpointProvider), 800);
      },
    );

    test(
      'the default matches the minimum window size the desktop enforces',
      () {
        // Not a coincidence to be kept in sync by hand: below that width a
        // desktop window could not show the three columns either, which is what
        // makes 800 the principled place to fold them away.
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          container.read(shellBreakpointProvider),
          kMinimumWindowSize.width,
        );
      },
    );

    test('an override selects the other layout at an unchanged width', () {
      final container = ProviderContainer(
        overrides: [shellBreakpointProvider.overrideWithValue(900)],
      );
      addTearDown(container.dispose);

      expect(
        resolveShellLayout(
          width: 800,
          breakpoint: container.read(shellBreakpointProvider),
        ),
        ShellLayout.narrow,
      );
    });
  });
}
