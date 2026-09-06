import 'dart:io' show Platform;

enum FontFamily {
  system(displayName: 'システムデフォルト', fontFamilyName: null, appleOnly: false),
  hiraginoMincho(
    displayName: 'ヒラギノ明朝',
    fontFamilyName: 'Hiragino Mincho ProN',
    appleOnly: true,
  ),
  hiraginoKaku(
    displayName: 'ヒラギノ角ゴ',
    fontFamilyName: 'Hiragino Kaku Gothic ProN',
    appleOnly: true,
  ),
  yumincho(displayName: '游明朝', fontFamilyName: 'YuMincho', appleOnly: false),
  yuGothic(displayName: '游ゴシック', fontFamilyName: 'YuGothic', appleOnly: false);

  const FontFamily({
    required this.displayName,
    required this.fontFamilyName,
    required this.appleOnly,
  });

  final String displayName;
  final String? fontFamilyName;

  /// Whether the face only exists on Apple platforms (macOS and iOS).
  final bool appleOnly;

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

  /// The fonts a platform can actually render.
  ///
  /// Hiragino ships with iOS as well as macOS, so the gate is the Apple
  /// platform family rather than macOS alone: an iPad offered only the two Yu
  /// faces would have no working choice at all.
  ///
  /// The platform is a parameter because `dart:io`'s `Platform` cannot be
  /// overridden from a test.
  static List<FontFamily> availableFontsFor({required bool isApplePlatform}) {
    if (isApplePlatform) return values;
    return values.where((f) => !f.appleOnly).toList();
  }

  static List<FontFamily> get availableFonts =>
      availableFontsFor(isApplePlatform: Platform.isMacOS || Platform.isIOS);
}
