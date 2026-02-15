import 'dart:io' show Platform;

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

  group('FontFamily.macOSOnly', () {
    test('hiragino fonts are macOS-only', () {
      expect(FontFamily.hiraginoMincho.macOSOnly, isTrue);
      expect(FontFamily.hiraginoKaku.macOSOnly, isTrue);
    });

    test('system, yumincho, yuGothic are cross-platform', () {
      expect(FontFamily.system.macOSOnly, isFalse);
      expect(FontFamily.yumincho.macOSOnly, isFalse);
      expect(FontFamily.yuGothic.macOSOnly, isFalse);
    });
  });

  group('FontFamily.effectiveFontFamilyName', () {
    if (Platform.isWindows) {
      test('system default returns Yu Mincho on Windows', () {
        expect(FontFamily.system.effectiveFontFamilyName, 'Yu Mincho');
      });

      test('maps font names to Windows format on Windows', () {
        expect(FontFamily.yumincho.effectiveFontFamilyName, 'Yu Mincho');
        expect(FontFamily.yuGothic.effectiveFontFamilyName, 'Yu Gothic');
        expect(FontFamily.hiraginoMincho.effectiveFontFamilyName,
            'Hiragino Mincho ProN');
        expect(FontFamily.hiraginoKaku.effectiveFontFamilyName,
            'Hiragino Kaku Gothic ProN');
      });
    }

    if (Platform.isMacOS) {
      test('system default returns null on macOS', () {
        expect(FontFamily.system.effectiveFontFamilyName, isNull);
      });

      test('returns fontFamilyName as-is on macOS', () {
        expect(FontFamily.yumincho.effectiveFontFamilyName, 'YuMincho');
        expect(FontFamily.yuGothic.effectiveFontFamilyName, 'YuGothic');
        expect(FontFamily.hiraginoMincho.effectiveFontFamilyName,
            'Hiragino Mincho ProN');
        expect(FontFamily.hiraginoKaku.effectiveFontFamilyName,
            'Hiragino Kaku Gothic ProN');
      });
    }
  });

  group('FontFamily.availableFonts', () {
    if (Platform.isWindows) {
      test('excludes macOS-only fonts on Windows', () {
        final available = FontFamily.availableFonts;
        expect(available, contains(FontFamily.system));
        expect(available, contains(FontFamily.yumincho));
        expect(available, contains(FontFamily.yuGothic));
        expect(available, isNot(contains(FontFamily.hiraginoMincho)));
        expect(available, isNot(contains(FontFamily.hiraginoKaku)));
      });
    }

    if (Platform.isMacOS) {
      test('includes all fonts on macOS', () {
        final available = FontFamily.availableFonts;
        expect(available, hasLength(5));
      });
    }
  });
}
