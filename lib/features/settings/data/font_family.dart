import 'dart:io' show Platform;

enum FontFamily {
  system(
    displayName: 'システムデフォルト',
    fontFamilyName: null,
    macOSOnly: false,
  ),
  hiraginoMincho(
    displayName: 'ヒラギノ明朝',
    fontFamilyName: 'Hiragino Mincho ProN',
    macOSOnly: true,
  ),
  hiraginoKaku(
    displayName: 'ヒラギノ角ゴ',
    fontFamilyName: 'Hiragino Kaku Gothic ProN',
    macOSOnly: true,
  ),
  yumincho(
    displayName: '游明朝',
    fontFamilyName: 'YuMincho',
    macOSOnly: false,
  ),
  yuGothic(
    displayName: '游ゴシック',
    fontFamilyName: 'YuGothic',
    macOSOnly: false,
  );

  const FontFamily({
    required this.displayName,
    required this.fontFamilyName,
    required this.macOSOnly,
  });

  final String displayName;
  final String? fontFamilyName;
  final bool macOSOnly;

  static const _windowsFontNames = {
    'YuMincho': 'Yu Mincho',
    'YuGothic': 'Yu Gothic',
  };

  String? get effectiveFontFamilyName {
    if (Platform.isWindows) {
      if (this == FontFamily.system) return 'Yu Mincho';
      return _windowsFontNames[fontFamilyName] ?? fontFamilyName;
    }
    return fontFamilyName;
  }

  static List<FontFamily> get availableFonts {
    if (Platform.isMacOS) return values;
    return values.where((f) => !f.macOSOnly).toList();
  }
}
