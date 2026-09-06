import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/reading_progress/domain/body_position.dart';
import 'package:novel_viewer/features/text_viewer/data/ruby_text_parser.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';

void main() {
  test(
    'vertical page offsets retain source newlines and UTF-16 ruby lengths',
    () {
      final offsets = computeCharOffsetPerPage(
        [
          [const PlainTextSegment('A\u{1f600}')],
          [const RubyTextSegment(base: 'BC', rubyText: 'reading')],
          [],
          [const PlainTextSegment('Z')],
        ],
        [0, 1, 2, 3],
        [0, 2, 3],
      );
      expect(offsets, [0, 3, 6, 7]);
    },
  );
  test('ruby display offsets map to body UTF-16 offsets', () {
    final body = BodyPositionMap(
      parseRubyText('A<ruby>BC<rt>reading</rt></ruby>\n\u{1f600}e\u0301Z'),
    );
    expect(body.text, 'ABC\n\u{1f600}e\u0301Z');
    expect(body.fromDisplayOffset(2), 3);
    expect(body.toDisplayOffset(2), 1);
    expect(body.toDisplayOffset(6), 5);
    expect(body.normalize(5), 4);
    expect(body.normalize(7), 6);
    expect(body.normalize(-1), 0);
    expect(body.normalize(100), 9);
  });

  test('restore keeps an offset the vertical pagination can page from', () {
    // Vertical pagination splits on runes (see column_splitter), so a page can
    // start inside a grapheme cluster. Snapping such an offset back to the
    // previous grapheme boundary puts it before the page start, and
    // _findPageForOffset then resolves to the page before the reader's.
    // Display conversion still normalizes, so nothing downstream sees a
    // mid-grapheme offset.
    final body = BodyPositionMap(parseRubyText('ae\u0301z'));
    expect(body.text, 'ae\u0301z');
    expect(body.normalize(2), 1);
    expect(body.restore(2, body.hash), 2);
    expect(body.toDisplayOffset(2), 1);
    expect(body.restore(-5, body.hash), 0);
  });

  test('changed or missing hashes reset position, matching hashes restore', () {
    final body = BodyPositionMap(parseRubyText('abcdef'));
    expect(body.restore(3, body.hash), 3);
    expect(body.restore(3, null), 0);
    expect(body.restore(3, 'old'), 0);
    expect(body.restore(100, body.hash), 6);
    final empty = BodyPositionMap([]);
    expect(empty.restore(12, empty.hash), 0);
  });
}
