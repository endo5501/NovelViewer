import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/text_viewer/data/parsed_segments_cache.dart';
import 'package:novel_viewer/features/text_viewer/data/parsed_segments_cache_provider.dart';
import 'package:novel_viewer/features/text_viewer/data/ruby_text_parser.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';

void main() {
  group('ParsedSegmentsCache', () {
    test('same hash returns cached segments without re-invoking parser', () {
      var calls = 0;
      final cache = ParsedSegmentsCache();
      List<TextSegment> parser(String s) {
        calls++;
        return parseRubyText(s);
      }

      final first = cache.getOrParse('テスト。', 'h1', parser);
      final second = cache.getOrParse('テスト。', 'h1', parser);

      expect(calls, 1);
      expect(identical(first, second), isTrue);
    });

    test('different hash stores a separate entry', () {
      final cache = ParsedSegmentsCache();
      final a = cache.getOrParse('テスト１', 'h1', parseRubyText);
      final b = cache.getOrParse('テスト２', 'h2', parseRubyText);

      expect(identical(a, b), isFalse);
      expect(cache.size, 2);
    });

    test('LRU eviction kicks in past max entries', () {
      final cache = ParsedSegmentsCache(maxEntries: 3);
      cache.getOrParse('a', 'h1', parseRubyText);
      cache.getOrParse('b', 'h2', parseRubyText);
      cache.getOrParse('c', 'h3', parseRubyText);
      expect(cache.size, 3);

      cache.getOrParse('d', 'h4', parseRubyText);
      expect(cache.size, 3);

      // h1 should have been evicted; re-parsing it invokes parser again.
      var calls = 0;
      cache.getOrParse('a', 'h1', (s) {
        calls++;
        return parseRubyText(s);
      });
      expect(calls, 1);
    });

    test('access promotes entry to most-recently-used (LRU semantics)', () {
      final cache = ParsedSegmentsCache(maxEntries: 3);
      cache.getOrParse('a', 'h1', parseRubyText);
      cache.getOrParse('b', 'h2', parseRubyText);
      cache.getOrParse('c', 'h3', parseRubyText);

      // Touch h1 so h2 becomes the LRU.
      cache.getOrParse('a', 'h1', parseRubyText);
      cache.getOrParse('d', 'h4', parseRubyText);

      // h2 evicted, h1 still cached.
      var h1Calls = 0;
      var h2Calls = 0;
      cache.getOrParse('a', 'h1', (s) {
        h1Calls++;
        return parseRubyText(s);
      });
      cache.getOrParse('b', 'h2', (s) {
        h2Calls++;
        return parseRubyText(s);
      });
      expect(h1Calls, 0);
      expect(h2Calls, 1);
    });
  });

  group('parsedSegmentsCacheProvider', () {
    test('cache survives widget rebuild (provider lifetime)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final cache1 = container.read(parsedSegmentsCacheProvider);
      final cache2 = container.read(parsedSegmentsCacheProvider);

      expect(identical(cache1, cache2), isTrue);

      cache1.getOrParse('テスト', 'h1', parseRubyText);
      expect(cache2.size, 1);
    });
  });
}
