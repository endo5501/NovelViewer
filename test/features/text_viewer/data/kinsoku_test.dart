import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/kinsoku.dart';

void main() {
  group('isLineHeadForbidden', () {
    test('句読点は行頭禁則文字', () {
      expect(isLineHeadForbidden('。'), isTrue);
      expect(isLineHeadForbidden('、'), isTrue);
      expect(isLineHeadForbidden('，'), isTrue);
      expect(isLineHeadForbidden('．'), isTrue);
      expect(isLineHeadForbidden(','), isTrue);
      expect(isLineHeadForbidden('.'), isTrue);
    });

    test('閉じ括弧は行頭禁則文字', () {
      expect(isLineHeadForbidden('）'), isTrue);
      expect(isLineHeadForbidden('」'), isTrue);
      expect(isLineHeadForbidden('』'), isTrue);
      expect(isLineHeadForbidden('】'), isTrue);
      expect(isLineHeadForbidden('〕'), isTrue);
      expect(isLineHeadForbidden('｝'), isTrue);
      expect(isLineHeadForbidden('〉'), isTrue);
      expect(isLineHeadForbidden('》'), isTrue);
      expect(isLineHeadForbidden(')'), isTrue);
      expect(isLineHeadForbidden(']'), isTrue);
      expect(isLineHeadForbidden('}'), isTrue);
    });

    test('縦書き用閉じ括弧は行頭禁則文字', () {
      expect(isLineHeadForbidden('﹂'), isTrue);
      expect(isLineHeadForbidden('﹄'), isTrue);
      expect(isLineHeadForbidden('︶'), isTrue);
      expect(isLineHeadForbidden('﹈'), isTrue);
      expect(isLineHeadForbidden('︸'), isTrue);
      expect(isLineHeadForbidden('﹀'), isTrue);
      expect(isLineHeadForbidden('︼'), isTrue);
      expect(isLineHeadForbidden('︺'), isTrue);
      expect(isLineHeadForbidden('︘'), isTrue);
      expect(isLineHeadForbidden('︾'), isTrue);
    });

    test('中点・コロン・セミコロンは行頭禁則文字', () {
      expect(isLineHeadForbidden('・'), isTrue);
      expect(isLineHeadForbidden('：'), isTrue);
      expect(isLineHeadForbidden('；'), isTrue);
    });

    test('感嘆符・疑問符は行頭禁則文字', () {
      expect(isLineHeadForbidden('！'), isTrue);
      expect(isLineHeadForbidden('？'), isTrue);
      expect(isLineHeadForbidden('!'), isTrue);
      expect(isLineHeadForbidden('?'), isTrue);
    });

    test('長音記号は行頭禁則文字', () {
      expect(isLineHeadForbidden('ー'), isTrue);
    });

    test('リーダーは行頭禁則文字', () {
      expect(isLineHeadForbidden('…'), isTrue);
      expect(isLineHeadForbidden('‥'), isTrue);
    });

    test('小書き仮名は行頭禁則文字', () {
      expect(isLineHeadForbidden('ぁ'), isTrue);
      expect(isLineHeadForbidden('ぃ'), isTrue);
      expect(isLineHeadForbidden('ぅ'), isTrue);
      expect(isLineHeadForbidden('ぇ'), isTrue);
      expect(isLineHeadForbidden('ぉ'), isTrue);
      expect(isLineHeadForbidden('っ'), isTrue);
      expect(isLineHeadForbidden('ゃ'), isTrue);
      expect(isLineHeadForbidden('ゅ'), isTrue);
      expect(isLineHeadForbidden('ょ'), isTrue);
      expect(isLineHeadForbidden('ゎ'), isTrue);
      expect(isLineHeadForbidden('ァ'), isTrue);
      expect(isLineHeadForbidden('ィ'), isTrue);
      expect(isLineHeadForbidden('ゥ'), isTrue);
      expect(isLineHeadForbidden('ェ'), isTrue);
      expect(isLineHeadForbidden('ォ'), isTrue);
      expect(isLineHeadForbidden('ッ'), isTrue);
      expect(isLineHeadForbidden('ャ'), isTrue);
      expect(isLineHeadForbidden('ュ'), isTrue);
      expect(isLineHeadForbidden('ョ'), isTrue);
      expect(isLineHeadForbidden('ヮ'), isTrue);
      expect(isLineHeadForbidden('ヵ'), isTrue);
      expect(isLineHeadForbidden('ヶ'), isTrue);
    });

    test('通常の文字は行頭禁則文字ではない', () {
      expect(isLineHeadForbidden('あ'), isFalse);
      expect(isLineHeadForbidden('漢'), isFalse);
      expect(isLineHeadForbidden('A'), isFalse);
      expect(isLineHeadForbidden('1'), isFalse);
      expect(isLineHeadForbidden('（'), isFalse);
      expect(isLineHeadForbidden('「'), isFalse);
    });
  });

  group('isLineEndForbidden', () {
    test('開き括弧は行末禁則文字', () {
      expect(isLineEndForbidden('（'), isTrue);
      expect(isLineEndForbidden('「'), isTrue);
      expect(isLineEndForbidden('『'), isTrue);
      expect(isLineEndForbidden('【'), isTrue);
      expect(isLineEndForbidden('〔'), isTrue);
      expect(isLineEndForbidden('｛'), isTrue);
      expect(isLineEndForbidden('〈'), isTrue);
      expect(isLineEndForbidden('《'), isTrue);
      expect(isLineEndForbidden('('), isTrue);
      expect(isLineEndForbidden('['), isTrue);
      expect(isLineEndForbidden('{'), isTrue);
    });

    test('縦書き用開き括弧は行末禁則文字', () {
      expect(isLineEndForbidden('﹁'), isTrue);
      expect(isLineEndForbidden('﹃'), isTrue);
      expect(isLineEndForbidden('︵'), isTrue);
      expect(isLineEndForbidden('﹇'), isTrue);
      expect(isLineEndForbidden('︷'), isTrue);
      expect(isLineEndForbidden('︿'), isTrue);
      expect(isLineEndForbidden('︻'), isTrue);
      expect(isLineEndForbidden('︹'), isTrue);
      expect(isLineEndForbidden('︗'), isTrue);
      expect(isLineEndForbidden('︽'), isTrue);
    });

    test('通常の文字は行末禁則文字ではない', () {
      expect(isLineEndForbidden('あ'), isFalse);
      expect(isLineEndForbidden('漢'), isFalse);
      expect(isLineEndForbidden('。'), isFalse);
      expect(isLineEndForbidden('、'), isFalse);
      expect(isLineEndForbidden('）'), isFalse);
      expect(isLineEndForbidden('」'), isFalse);
    });
  });
}
