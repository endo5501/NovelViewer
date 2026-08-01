import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/providers/tts_edit_providers.dart';

void main() {
  group('ttsEditCursorIndexProvider', () {
    test('the playhead starts at the first segment', () {
      // Pressing play on a freshly opened dialog has to behave like the old
      // "play all" did, which is what makes the two features one.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsEditCursorIndexProvider), 0);
    });

    test('holds the segment it is moved to', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(ttsEditCursorIndexProvider.notifier).set(7);

      expect(container.read(ttsEditCursorIndexProvider), 7);
    });
  });

  group('ttsEditPlayingProvider', () {
    test('nothing is playing initially', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsEditPlayingProvider), false);
    });
  });
}
