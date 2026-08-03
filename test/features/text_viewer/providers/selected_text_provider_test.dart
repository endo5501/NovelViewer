import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';

void main() {
  group('ViewerSelection', () {
    test('carries the text and its plain-text start offset', () {
      const selection = ViewerSelection(text: '太郎', plainTextOffset: 120);

      expect(selection.text, '太郎');
      expect(selection.plainTextOffset, 120);
    });

    test('compares by value', () {
      const a = ViewerSelection(text: '太郎', plainTextOffset: 120);
      const b = ViewerSelection(text: '太郎', plainTextOffset: 120);
      const differentOffset = ViewerSelection(text: '太郎', plainTextOffset: 7);
      const differentText = ViewerSelection(text: '次郎', plainTextOffset: 120);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(differentOffset));
      expect(a, isNot(differentText));
    });
  });

  group('selectedTextProvider', () {
    test('initial value is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedTextProvider), isNull);
    });

    test('tracks the selected text and offset', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedTextProvider.notifier).setSelection(
            const ViewerSelection(text: '太郎', plainTextOffset: 120),
          );

      final selection = container.read(selectedTextProvider);
      expect(selection?.text, '太郎');
      expect(selection?.plainTextOffset, 120);
    });

    test('clears the selection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedTextProvider.notifier).setSelection(
            const ViewerSelection(text: '太郎', plainTextOffset: 120),
          );
      container.read(selectedTextProvider.notifier).setSelection(null);

      expect(container.read(selectedTextProvider), isNull);
    });

    test('updates to a new selection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedTextProvider.notifier).setSelection(
            const ViewerSelection(text: '太郎', plainTextOffset: 120),
          );
      container.read(selectedTextProvider.notifier).setSelection(
            const ViewerSelection(text: '次郎', plainTextOffset: 300),
          );

      final selection = container.read(selectedTextProvider);
      expect(selection?.text, '次郎');
      expect(selection?.plainTextOffset, 300);
    });

    test('text-only consumers can read the text without the offset', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedTextProvider.notifier).setSelection(
            const ViewerSelection(text: '太郎', plainTextOffset: 120),
          );

      // What the search shortcut / dictionary / analysis call sites do.
      expect(container.read(selectedTextProvider)?.text, '太郎');

      container.read(selectedTextProvider.notifier).setSelection(null);
      expect(container.read(selectedTextProvider)?.text, isNull);
    });
  });
}
