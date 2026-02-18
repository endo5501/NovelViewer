import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';

void main() {
  group('TtsPlaybackState', () {
    test('has three values: stopped, loading, playing', () {
      expect(TtsPlaybackState.values.length, 3);
      expect(TtsPlaybackState.stopped, isNotNull);
      expect(TtsPlaybackState.loading, isNotNull);
      expect(TtsPlaybackState.playing, isNotNull);
    });
  });

  group('ttsPlaybackStateProvider', () {
    test('initial state is stopped', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsPlaybackStateProvider), TtsPlaybackState.stopped);
    });

    test('can transition to loading', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(ttsPlaybackStateProvider.notifier).set(
          TtsPlaybackState.loading);
      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.loading);
    });

    test('can transition to playing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(ttsPlaybackStateProvider.notifier).set(
          TtsPlaybackState.playing);
      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.playing);
    });

    test('can transition back to stopped', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(ttsPlaybackStateProvider.notifier).set(
          TtsPlaybackState.playing);
      container.read(ttsPlaybackStateProvider.notifier).set(
          TtsPlaybackState.stopped);
      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.stopped);
    });
  });

  group('ttsHighlightRangeProvider', () {
    test('initial state is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsHighlightRangeProvider), isNull);
    });

    test('can set a text range', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const range = TextRange(start: 10, end: 25);
      container.read(ttsHighlightRangeProvider.notifier).set(range);
      expect(container.read(ttsHighlightRangeProvider), range);
    });

    test('can clear range back to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(ttsHighlightRangeProvider.notifier).set(
          const TextRange(start: 0, end: 5));
      container.read(ttsHighlightRangeProvider.notifier).set(null);
      expect(container.read(ttsHighlightRangeProvider), isNull);
    });

    test('range start and end match set values', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const range = TextRange(start: 42, end: 58);
      container.read(ttsHighlightRangeProvider.notifier).set(range);

      final result = container.read(ttsHighlightRangeProvider);
      expect(result!.start, 42);
      expect(result.end, 58);
    });
  });
}
