import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_char_map.dart';

void main() {
  group('mapToVerticalChar', () {
    test('maps period to vertical form', () {
      expect(mapToVerticalChar('。'), '︒');
    });

    test('maps comma to vertical form', () {
      expect(mapToVerticalChar('、'), '︑');
    });

    test('maps opening corner bracket to vertical form', () {
      expect(mapToVerticalChar('「'), '﹁');
    });

    test('maps closing corner bracket to vertical form', () {
      expect(mapToVerticalChar('」'), '﹂');
    });

    test('maps opening double corner bracket to vertical form', () {
      expect(mapToVerticalChar('『'), '﹃');
    });

    test('maps closing double corner bracket to vertical form', () {
      expect(mapToVerticalChar('』'), '﹄');
    });

    test('maps opening parenthesis to vertical form', () {
      expect(mapToVerticalChar('（'), '︵');
    });

    test('maps closing parenthesis to vertical form', () {
      expect(mapToVerticalChar('）'), '︶');
    });

    test('maps ellipsis to vertical form', () {
      expect(mapToVerticalChar('…'), '︙');
    });

    test('maps em dash to vertical form', () {
      expect(mapToVerticalChar('—'), '︱');
    });

    test('returns unmapped characters unchanged', () {
      expect(mapToVerticalChar('あ'), 'あ');
      expect(mapToVerticalChar('A'), 'A');
      expect(mapToVerticalChar('漢'), '漢');
      expect(mapToVerticalChar('1'), '1');
    });
  });
}
