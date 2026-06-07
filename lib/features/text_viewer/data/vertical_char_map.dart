const verticalCharMap = <String, String>{
  // スペース
  ' ': '\u3000', // half-width → full-width ideographic space

  // 矢印（90°回転）
  '↑': '→',
  '↓': '←',
  '←': '↑',
  '→': '↓',

  // 句読点
  '。': '︒',
  '、': '︑',
  ',': '︐',
  '､': '︑', // half-width ideographic comma

  // 長音・ダッシュ類
  'ー': '丨', // katakana long vowel mark
  'ｰ': '丨', // half-width katakana long vowel mark
  '-': '丨', // hyphen-minus
  '_': '丨', // underscore
  '−': '丨', // minus sign U+2212
  '－': '丨', // fullwidth hyphen-minus
  '─': '丨', // box drawings light horizontal
  '—': '丨', // em dash (U+2014)
  '―': '丨', // zenkaku-dash (U+2015)
  '‐': '丨', // another hyphen-minus (U+2010)
  '‑': '丨', // another hyphen-minus (U+2011)
  '–': '丨', // EN dash(U+2013)

  // 波線
  '〜': '丨', // wave dash
  '～': '丨', // fullwidth tilde

  // スラッシュ
  '／': '＼',

  // 三点リーダー・二点リーダー
  '…': '︙',
  '‥': '︰',

  // コロン・セミコロンは verticalCharMap では扱わない。
  // フォントが縦書き用CJK互換形(U+FE13/FE14)を回転グリフとして描画できないため、
  // RotatedBox による物理回転で対応する（verticalRotateChars 参照）。

  // イコール
  '＝': '॥',
  '=': '॥',

  // 括弧（角括弧・カギ括弧）
  '「': '﹁',
  '」': '﹂',
  '『': '﹃',
  '』': '﹄',
  '｢': '﹁', // half-width left corner bracket
  '｣': '﹂', // half-width right corner bracket

  // 括弧（丸括弧）
  '（': '︵',
  '）': '︶',
  '(': '︵',
  ')': '︶',

  // 括弧（角括弧）
  '［': '﹇',
  '］': '﹈',
  '[': '﹇',
  ']': '﹈',

  // 括弧（波括弧）
  '｛': '︷',
  '｝': '︸',
  '{': '︷',
  '}': '︸',

  // 括弧（不等号）
  '＜': '︿',
  '＞': '﹀',
  '<': '︿',
  '>': '﹀',

  // 括弧（亀甲括弧・隅付き括弧）
  '【': '︻',
  '】': '︼',
  '〔': '︹',
  '〕': '︺',
  '〖': '︗',
  '〗': '︘',

  // 括弧（山括弧・二重山括弧）
  '〈': '︿',
  '〉': '﹀',
  '《': '︽',
  '》': '︾',
};

String mapToVerticalChar(String char) {
  return verticalCharMap[char] ?? char;
}

/// 縦書き表示時に物理回転（時計回り90°）で描画する文字の集合。
///
/// これらの文字は Unicode に縦書き用字形が存在しない（クオート類）か、
/// 存在してもフォントが回転グリフを描画できない（コロン・セミコロン）ため、
/// [verticalCharMap] による置換ではなく [RotatedBox] で字形を回転して描画する。
/// 文字自体は置換しないため、文字数・テキストオフセットは変化しない。
const verticalRotateChars = <String>{
  // ダブルクオート
  '"', // U+0022 quotation mark
  '＂', // U+FF02 fullwidth quotation mark
  '“', // U+201C left double quotation mark
  '”', // U+201D right double quotation mark

  // シングルクオート・アポストロフィ
  "'", // U+0027 apostrophe
  '＇', // U+FF07 fullwidth apostrophe
  '‘', // U+2018 left single quotation mark
  '’', // U+2019 right single quotation mark

  // バッククォート
  '`', // U+0060 grave accent
  '｀', // U+FF40 fullwidth grave accent

  // コロン
  ':', // U+003A
  '：', // U+FF1A

  // セミコロン
  ';', // U+003B
  '；', // U+FF1B
};

/// [char] が縦書きで物理回転して描画すべき文字かどうかを返す。
bool shouldRotateVertical(String char) {
  return verticalRotateChars.contains(char);
}
