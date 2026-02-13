enum FontFamily {
  system(displayName: 'システムデフォルト', fontFamilyName: null),
  hiraginoMincho(
    displayName: 'ヒラギノ明朝',
    fontFamilyName: 'Hiragino Mincho ProN',
  ),
  hiraginoKaku(
    displayName: 'ヒラギノ角ゴ',
    fontFamilyName: 'Hiragino Kaku Gothic ProN',
  ),
  yumincho(displayName: '游明朝', fontFamilyName: 'YuMincho'),
  yuGothic(displayName: '游ゴシック', fontFamilyName: 'YuGothic');

  const FontFamily({required this.displayName, required this.fontFamilyName});

  final String displayName;
  final String? fontFamilyName;
}
