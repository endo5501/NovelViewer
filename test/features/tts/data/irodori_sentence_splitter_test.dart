import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/irodori_sentence_splitter.dart';

void main() {
  group('splitAtCommas', () {
    test('a sentence within the length stays whole', () {
      expect(splitAtCommas('あいう、えお。', maxLength: 10), ['あいう、えお。']);
    });

    test('a sentence of exactly the length stays whole', () {
      final text = 'あ' * 9 + '。';
      expect(splitAtCommas(text, maxLength: 10), [text]);
    });

    test('cuts after the last comma within the length', () {
      // Commas after the 3rd and the 7th character; the 7th is the last one
      // within 8, so the first piece runs to it.
      expect(splitAtCommas('あいう、えおか、きくけこ。', maxLength: 8), [
        'あいう、えおか、',
        'きくけこ。',
      ]);
    });

    test('keeps cutting the rest', () {
      expect(splitAtCommas('あい、うえ、おか、きく。', maxLength: 4), [
        'あい、',
        'うえ、',
        'おか、',
        'きく。',
      ]);
    });

    test(
      'cuts after the first comma past the length when none is within it',
      () {
        expect(splitAtCommas('あいうえおか、きく、け。', maxLength: 4), [
          'あいうえおか、',
          'きく、',
          'け。',
        ]);
      },
    );

    test('a rest without a comma stays whole however long', () {
      expect(splitAtCommas('あい、うえおかきくけこ。', maxLength: 4), ['あい、', 'うえおかきくけこ。']);
    });

    test('a long sentence without any comma stays whole', () {
      final text = 'あ' * 30 + '。';
      expect(splitAtCommas(text, maxLength: 10), [text]);
    });

    test('every comma it knows is a place to cut', () {
      for (final comma in ['、', '，', ',', '；', ';']) {
        expect(splitAtCommas('あいう${comma}えおか。', maxLength: 5), [
          'あいう$comma',
          'えおか。',
        ], reason: comma);
      }
    });

    test('a comma that ends the text is not a cut', () {
      expect(splitAtCommas('あいうえおか、', maxLength: 4), ['あいうえおか、']);
    });

    test('the pieces join back into the text', () {
      const text =
          '昔々あるところに、おじいさんとおばあさんが住んでいました、'
          'おじいさんは山へ芝刈りに、おばあさんは川へ洗濯に行きました。';
      final pieces = splitAtCommas(text, maxLength: 20);
      expect(pieces.join(), text);
      expect(pieces.length, greaterThan(1));
    });

    test('defaults to 80 characters', () {
      final short = '${'あ' * 40}、${'い' * 39}';
      expect(splitAtCommas(short), [short]);
      final long = '${'あ' * 40}、${'い' * 40}';
      expect(splitAtCommas(long), ['${'あ' * 40}、', 'い' * 40]);
    });
  });
}
