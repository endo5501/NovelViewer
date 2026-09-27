import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

void main() {
  group('fileBrowserOpenRequestProvider', () {
    test('starts with no request', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(fileBrowserOpenRequestProvider), 0);
    });

    test('every request is counted, so a repeat still notifies', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(fileBrowserOpenRequestProvider.notifier);

      notifier.request();
      notifier.request();

      expect(container.read(fileBrowserOpenRequestProvider), 2);
    });
  });
}
