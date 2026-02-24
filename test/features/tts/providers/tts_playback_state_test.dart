import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';

void main() {
  group('TtsAudioState', () {
    test('has three values: none, generating, ready', () {
      expect(TtsAudioState.values.length, 3);
      expect(TtsAudioState.none, isNotNull);
      expect(TtsAudioState.generating, isNotNull);
      expect(TtsAudioState.ready, isNotNull);
    });
  });

  group('ttsAudioStateProvider', () {
    test('initial state is none', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsAudioStateProvider), TtsAudioState.none);
    });

    test('can transition to generating', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(ttsAudioStateProvider.notifier).set(
          TtsAudioState.generating);
      expect(
          container.read(ttsAudioStateProvider), TtsAudioState.generating);
    });

    test('can transition to ready', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(ttsAudioStateProvider.notifier).set(
          TtsAudioState.ready);
      expect(
          container.read(ttsAudioStateProvider), TtsAudioState.ready);
    });
  });

  group('TtsGenerationProgress', () {
    test('zero constant has 0/0', () {
      expect(TtsGenerationProgress.zero.current, 0);
      expect(TtsGenerationProgress.zero.total, 0);
    });
  });

  group('ttsGenerationProgressProvider', () {
    test('initial state is zero', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final progress = container.read(ttsGenerationProgressProvider);
      expect(progress.current, 0);
      expect(progress.total, 0);
    });

    test('can update progress', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(ttsGenerationProgressProvider.notifier).set(
          const TtsGenerationProgress(current: 5, total: 10));
      final progress = container.read(ttsGenerationProgressProvider);
      expect(progress.current, 5);
      expect(progress.total, 10);
    });
  });

  group('TtsPlaybackState', () {
    test('has three values: stopped, playing, paused', () {
      expect(TtsPlaybackState.values.length, 3);
      expect(TtsPlaybackState.stopped, isNotNull);
      expect(TtsPlaybackState.playing, isNotNull);
      expect(TtsPlaybackState.paused, isNotNull);
    });
  });

  group('ttsPlaybackStateProvider', () {
    test('initial state is stopped', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsPlaybackStateProvider), TtsPlaybackState.stopped);
    });

    test('can transition to playing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(ttsPlaybackStateProvider.notifier).set(
          TtsPlaybackState.playing);
      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.playing);
    });

    test('can transition to paused', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(ttsPlaybackStateProvider.notifier).set(
          TtsPlaybackState.paused);
      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.paused);
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
