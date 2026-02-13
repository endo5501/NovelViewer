import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_char_map.dart';

void main() {
  group('mapToVerticalChar', () {
    test('maps space to ideographic space', () {
      expect(mapToVerticalChar(' '), '\u3000');
    });

    test('maps arrows with 90° rotation', () {
      expect(mapToVerticalChar('↑'), '→');
      expect(mapToVerticalChar('↓'), '←');
      expect(mapToVerticalChar('←'), '↑');
      expect(mapToVerticalChar('→'), '↓');
    });

    test('maps punctuation to vertical form', () {
      expect(mapToVerticalChar('。'), '︒');
      expect(mapToVerticalChar('、'), '︑');
      expect(mapToVerticalChar(','), '︐');
      expect(mapToVerticalChar('､'), '︑');
    });

    test('maps long vowel marks and dashes to vertical bar', () {
      expect(mapToVerticalChar('ー'), '丨');
      expect(mapToVerticalChar('ｰ'), '丨');
      expect(mapToVerticalChar('-'), '丨');
      expect(mapToVerticalChar('_'), '丨');
      expect(mapToVerticalChar('−'), '丨'); // U+2212 minus sign
      expect(mapToVerticalChar('－'), '丨');
      expect(mapToVerticalChar('─'), '丨');
      expect(mapToVerticalChar('—'), '丨');
    });

    test('maps wave dashes to vertical bar', () {
      expect(mapToVerticalChar('〜'), '丨');
      expect(mapToVerticalChar('～'), '丨');
    });

    test('maps slash to vertical form', () {
      expect(mapToVerticalChar('／'), '＼');
    });

    test('maps ellipsis and two-dot leader to vertical form', () {
      expect(mapToVerticalChar('…'), '︙');
      expect(mapToVerticalChar('‥'), '︰');
    });

    test('maps colons and semicolons to vertical form', () {
      expect(mapToVerticalChar('：'), '︓');
      expect(mapToVerticalChar(':'), '︓');
      expect(mapToVerticalChar('；'), '︔');
      expect(mapToVerticalChar(';'), '︔');
    });

    test('maps equals to vertical form', () {
      expect(mapToVerticalChar('＝'), '॥');
      expect(mapToVerticalChar('='), '॥');
    });

    test('maps corner brackets to vertical form', () {
      expect(mapToVerticalChar('「'), '﹁');
      expect(mapToVerticalChar('」'), '﹂');
      expect(mapToVerticalChar('『'), '﹃');
      expect(mapToVerticalChar('』'), '﹄');
      expect(mapToVerticalChar('｢'), '﹁');
      expect(mapToVerticalChar('｣'), '﹂');
    });

    test('maps parentheses to vertical form', () {
      expect(mapToVerticalChar('（'), '︵');
      expect(mapToVerticalChar('）'), '︶');
      expect(mapToVerticalChar('('), '︵');
      expect(mapToVerticalChar(')'), '︶');
    });

    test('maps square brackets to vertical form', () {
      expect(mapToVerticalChar('［'), '﹇');
      expect(mapToVerticalChar('］'), '﹈');
      expect(mapToVerticalChar('['), '﹇');
      expect(mapToVerticalChar(']'), '﹈');
    });

    test('maps curly brackets to vertical form', () {
      expect(mapToVerticalChar('｛'), '︷');
      expect(mapToVerticalChar('｝'), '︸');
      expect(mapToVerticalChar('{'), '︷');
      expect(mapToVerticalChar('}'), '︸');
    });

    test('maps angle brackets to vertical form', () {
      expect(mapToVerticalChar('＜'), '︿');
      expect(mapToVerticalChar('＞'), '﹀');
      expect(mapToVerticalChar('<'), '︿');
      expect(mapToVerticalChar('>'), '﹀');
      expect(mapToVerticalChar('〈'), '︿');
      expect(mapToVerticalChar('〉'), '﹀');
      expect(mapToVerticalChar('《'), '︽');
      expect(mapToVerticalChar('》'), '︾');
    });

    test('maps lenticular and tortoise shell brackets to vertical form', () {
      expect(mapToVerticalChar('【'), '︻');
      expect(mapToVerticalChar('】'), '︼');
      expect(mapToVerticalChar('〔'), '︹');
      expect(mapToVerticalChar('〕'), '︺');
      expect(mapToVerticalChar('〖'), '︗');
      expect(mapToVerticalChar('〗'), '︘');
    });

    test('returns unmapped characters unchanged', () {
      expect(mapToVerticalChar('あ'), 'あ');
      expect(mapToVerticalChar('A'), 'A');
      expect(mapToVerticalChar('漢'), '漢');
      expect(mapToVerticalChar('1'), '1');
    });
  });
}
