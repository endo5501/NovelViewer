/// Characters that cannot appear at the start of a line (line-head kinsoku).
const kLineHeadForbidden = <String>{
  // 句読点
  '。', '、', '，', '．', ',', '.',
  // 閉じ括弧
  '）', '」', '』', '】', '〕', '｝', '〉', '》',
  '﹂', '﹄', '︶', '﹈', '︸', '﹀', '︼', '︺', '︘', '︾',
  ')', ']', '}',
  // 中点・コロン・セミコロン
  '・', '：', '；',
  // 感嘆符・疑問符
  '！', '？', '!', '?',
  // 長音記号
  'ー',
  // リーダー
  '…', '‥',
  // 小書き仮名
  'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ', 'っ', 'ゃ', 'ゅ', 'ょ', 'ゎ',
  'ァ', 'ィ', 'ゥ', 'ェ', 'ォ', 'ッ', 'ャ', 'ュ', 'ョ', 'ヮ', 'ヵ', 'ヶ',
};

/// Characters that cannot appear at the end of a line (line-end kinsoku).
const kLineEndForbidden = <String>{
  // 開き括弧
  '（', '「', '『', '【', '〔', '｛', '〈', '《',
  '﹁', '﹃', '︵', '﹇', '︷', '︿', '︻', '︹', '︗', '︽',
  '(', '[', '{',
};

/// Returns true if the character cannot appear at the start of a line.
bool isLineHeadForbidden(String char) => kLineHeadForbidden.contains(char);

/// Returns true if the character cannot appear at the end of a line.
bool isLineEndForbidden(String char) => kLineEndForbidden.contains(char);
