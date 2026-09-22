import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/utils/ruby_annotation.dart';

void main() {
  group('stripRubyAnnotations', () {
    test('keeps the base and drops the reading', () {
      expect(stripRubyAnnotations('<ruby>紅蓮<rt>ぐれん</rt></ruby>'), '紅蓮');
    });

    test('drops rp fallback parentheses', () {
      expect(
        stripRubyAnnotations('<ruby>紅蓮<rp>（</rp><rt>ぐれん</rt><rp>）</rp></ruby>'),
        '紅蓮',
      );
    });

    test('joins the base with the plain text that follows it', () {
      // The case the analysis evidence search depends on: the displayed word
      // "紅蓮の剣" spans the ruby boundary, so only the stripped text has it
      // as one contiguous run.
      expect(
        stripRubyAnnotations('<ruby>紅蓮<rt>ぐれん</rt></ruby>の剣を手にした'),
        '紅蓮の剣を手にした',
      );
    });

    test('joins the bases of two adjacent ruby groups', () {
      expect(
        stripRubyAnnotations(
          '<ruby>紅蓮<rt>ぐれん</rt></ruby>の<ruby>剣<rt>けん</rt></ruby>を抜いた',
        ),
        '紅蓮の剣を抜いた',
      );
    });

    test('leaves text without ruby unchanged', () {
      expect(stripRubyAnnotations('紅蓮の剣を抜いた'), '紅蓮の剣を抜いた');
    });

    test('is case-insensitive about the tag names', () {
      expect(stripRubyAnnotations('<RUBY>紅蓮<RT>ぐれん</RT></RUBY>の剣'), '紅蓮の剣');
    });

    test('returns the empty string unchanged', () {
      expect(stripRubyAnnotations(''), '');
    });

    test('keeps an empty-base annotation from swallowing its neighbours', () {
      expect(stripRubyAnnotations('前<ruby><rt>よみ</rt></ruby>後'), '前後');
    });
  });
}
