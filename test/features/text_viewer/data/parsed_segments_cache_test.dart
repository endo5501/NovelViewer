import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/ruby_text_parser.dart';
import 'package:novel_viewer/features/text_viewer/data/parsed_segments_cache.dart';

void main() {
  group('ParsedSegmentsCache', () {
    test('returns parsed segments for given content', () {
      final cache = ParsedSegmentsCache();
      final segments = cache.getSegments('テスト。');

      expect(segments, isNotEmpty);
      expect(segments, equals(parseRubyText('テスト。')));
    });

    test('returns same reference for identical content', () {
      final cache = ParsedSegmentsCache();
      final segments1 = cache.getSegments('テスト。');
      final segments2 = cache.getSegments('テスト。');

      expect(identical(segments1, segments2), isTrue);
    });

    test('returns new reference when content changes', () {
      final cache = ParsedSegmentsCache();
      final segments1 = cache.getSegments('テスト１。');
      final segments2 = cache.getSegments('テスト２。');

      expect(identical(segments1, segments2), isFalse);
    });

    test('returns new reference after content changes back', () {
      final cache = ParsedSegmentsCache();
      final segments1 = cache.getSegments('テスト１。');
      cache.getSegments('テスト２。');
      final segments3 = cache.getSegments('テスト１。');

      // Cache only holds last value, so this should be a new parse
      expect(identical(segments1, segments3), isFalse);
    });
  });
}
