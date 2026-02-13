import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';

void main() {
  group('FontFamily', () {
    test('has all expected values', () {
      expect(FontFamily.values, hasLength(5));
      expect(FontFamily.values, contains(FontFamily.system));
      expect(FontFamily.values, contains(FontFamily.hiraginoMincho));
      expect(FontFamily.values, contains(FontFamily.hiraginoKaku));
      expect(FontFamily.values, contains(FontFamily.yumincho));
      expect(FontFamily.values, contains(FontFamily.yuGothic));
    });

    test('system has null fontFamilyName', () {
      expect(FontFamily.system.fontFamilyName, isNull);
      expect(FontFamily.system.displayName, 'システムデフォルト');
    });

    test('hiraginoMincho has correct properties', () {
      expect(FontFamily.hiraginoMincho.fontFamilyName,
          'Hiragino Mincho ProN');
      expect(FontFamily.hiraginoMincho.displayName, 'ヒラギノ明朝');
    });

    test('hiraginoKaku has correct properties', () {
      expect(FontFamily.hiraginoKaku.fontFamilyName,
          'Hiragino Kaku Gothic ProN');
      expect(FontFamily.hiraginoKaku.displayName, 'ヒラギノ角ゴ');
    });

    test('yumincho has correct properties', () {
      expect(FontFamily.yumincho.fontFamilyName, 'YuMincho');
      expect(FontFamily.yumincho.displayName, '游明朝');
    });

    test('yuGothic has correct properties', () {
      expect(FontFamily.yuGothic.fontFamilyName, 'YuGothic');
      expect(FontFamily.yuGothic.displayName, '游ゴシック');
    });
  });
}
