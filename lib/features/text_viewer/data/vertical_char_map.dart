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

  // コロン・セミコロン
  '：': '︓',
  ':': '︓',
  '；': '︔',
  ';': '︔',

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
