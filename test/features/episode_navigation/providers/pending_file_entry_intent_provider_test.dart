import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/domain/file_entry_start_intent.dart';
import 'package:novel_viewer/features/episode_navigation/providers/pending_file_entry_intent_provider.dart';

void main() {
  group('pendingFileEntryIntentProvider', () {
    test('initial value is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pendingFileEntryIntentProvider), isNull);
    });

    test('set updates the held value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(pendingFileEntryIntentProvider.notifier)
          .set(FileEntryStartIntent.fromEnd);

      expect(
        container.read(pendingFileEntryIntentProvider),
        FileEntryStartIntent.fromEnd,
      );
    });

    test('clear resets to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(pendingFileEntryIntentProvider.notifier)
          .set(FileEntryStartIntent.fromEnd);
      container.read(pendingFileEntryIntentProvider.notifier).clear();

      expect(container.read(pendingFileEntryIntentProvider), isNull);
    });

    test('overwriting replaces the previous value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(pendingFileEntryIntentProvider.notifier)
          .set(FileEntryStartIntent.fromStart);
      container
          .read(pendingFileEntryIntentProvider.notifier)
          .set(FileEntryStartIntent.fromEnd);

      expect(
        container.read(pendingFileEntryIntentProvider),
        FileEntryStartIntent.fromEnd,
      );
    });
  });
}
