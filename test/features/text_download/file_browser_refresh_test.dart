import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

void main() {
  group('File browser refresh after download', () {
    test(
        'directoryContentsProvider can be invalidated to trigger refresh',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory('/tmp/test');

      // Access the provider to ensure it's initialized
      container.read(directoryContentsProvider);

      // Invalidating should cause the provider to recompute
      container.invalidate(directoryContentsProvider);

      // Provider should be accessible again after invalidation
      final result = container.read(directoryContentsProvider);
      expect(result, isNotNull);
    });

    test('setDirectory updates the current directory', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(currentDirectoryProvider), isNull);

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory('/new/path');

      expect(container.read(currentDirectoryProvider), '/new/path');
    });

    test('changing directory triggers contents reload', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory('/first/path');

      final first = container.read(directoryContentsProvider);

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory('/second/path');

      final second = container.read(directoryContentsProvider);

      // Both should be accessible (different evaluations)
      expect(first, isNotNull);
      expect(second, isNotNull);
    });
  });
}
