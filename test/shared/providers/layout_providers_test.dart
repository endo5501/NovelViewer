import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
