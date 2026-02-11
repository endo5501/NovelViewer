import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';

void main() {
  group('selectedTextProvider', () {
    test('initial value is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedTextProvider), isNull);
    });

    test('tracks selected text', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedTextProvider.notifier).setText('太郎');

      expect(container.read(selectedTextProvider), '太郎');
    });

    test('clears selected text', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedTextProvider.notifier).setText('太郎');
      container.read(selectedTextProvider.notifier).setText(null);

      expect(container.read(selectedTextProvider), isNull);
    });

    test('updates to new selection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedTextProvider.notifier).setText('太郎');
      container.read(selectedTextProvider.notifier).setText('次郎');

      expect(container.read(selectedTextProvider), '次郎');
    });
  });
}
