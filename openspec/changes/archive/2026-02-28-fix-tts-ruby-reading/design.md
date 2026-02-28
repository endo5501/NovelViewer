## Context

TTS機能では `TextSegmenter` がエピソードのテキストを文単位に分割してからTTSエンジンに渡している。テキストにはHTMLの `<ruby>` タグが含まれており、`_stripRubyTags()` メソッドでプレーンテキストに変換される。

現在の実装では、正規表現のキャプチャグループ1（base text = 漢字）を抽出している：

```dart
static final _rubyTagPattern = RegExp(
  r'<ruby>(?:<rb>)?(.*?)(?:</rb>)?(?:<rp>.*?</rp>)?<rt>.*?</rt>(?:<rp>.*?</rp>)?</ruby>',
);

String _stripRubyTags(String text) {
  return text.replaceAllMapped(_rubyTagPattern, (match) {
    return match.group(1) ?? '';  // base text（漢字）を返している
  });
}
```

`<rt>` の内容はキャプチャグループとして定義されておらず、読み捨てられている。

また、`TextSegment.offset` と `TextSegment.length` はTTSハイライト（`ttsHighlightRangeProvider`）で使用されており、UI側の `buildRubyTextSpans()` は **base text座標系** で `plainTextOffset` を計算している。したがって、offset/length はbase text座標系を維持する必要がある。

## Goals / Non-Goals

**Goals:**
- TTS合成用テキスト（`TextSegment.text`）にruby text（ふりがな）を使用する
- ハイライト用の `offset` / `length` はbase text座標系を維持する
- 空の `<rt>` タグに対してbase textへフォールバックする

**Non-Goals:**
- 文分割ロジック自体の変更
- UI表示側のルビ処理（`ruby_text_parser.dart`）の変更
- 既存TTS音声データのマイグレーション（text_hashの不一致により自動再生成される）

## Decisions

### Decision 1: 正規表現にキャプチャグループを追加する

`<rt>` の内容を新たにキャプチャグループ2として定義する。

```dart
// Before
r'<ruby>(?:<rb>)?(.*?)(?:</rb>)?(?:<rp>.*?</rp>)?<rt>.*?</rt>(?:<rp>.*?</rp>)?</ruby>'

// After
r'<ruby>(?:<rb>)?(.*?)(?:</rb>)?(?:<rp>.*?</rp>)?<rt>(.*?)</rt>(?:<rp>.*?</rp>)?</ruby>'
```

### Decision 2: 二重ストリッピングで座標系を分離する

`splitIntoSentences()` でrubyタグを2回ストリップする：
1. **ruby textストリップ**: `group(2)`（ふりがな）→ TTS合成用テキスト
2. **base textストリップ**: `group(1)`（漢字）→ offset/length計算用

```dart
List<TextSegment> splitIntoSentences(String text) {
  final spokenText = _stripRubyTags(text, useRubyText: true);
  final displayText = _stripRubyTags(text, useRubyText: false);

  final spokenSegments = _splitText(spokenText);
  final displaySegments = _splitText(displayText);

  return [
    for (var i = 0; i < spokenSegments.length; i++)
      TextSegment(
        text: spokenSegments[i].text,
        offset: displaySegments[i].offset,
        length: displaySegments[i].length,
      ),
  ];
}
```

**理由**: 句読点（。！？）はrubyタグの外にあるため、ruby textとbase textの文分割結果は常に同じ数のセグメントを生成する。これにより両者を安全にzipできる。

**代替案**:
- offset変換テーブルを構築 → より複雑で、テストが困難
- TextSegmentにdisplayOffset/displayLengthを追加 → 既存コードへの影響が大きい

### Decision 3: 空の `<rt>` タグへのフォールバック

`<rt></rt>` が空の場合、ruby textは空文字列になるため、base text にフォールバックする。

```dart
String _stripRubyTags(String text, {bool useRubyText = false}) {
  return text.replaceAllMapped(_rubyTagPattern, (match) {
    if (useRubyText) {
      final ruby = match.group(2) ?? '';
      return ruby.isEmpty ? (match.group(1) ?? '') : ruby;
    }
    return match.group(1) ?? '';
  });
}
```

### Decision 4: 文分割ロジックをプライベートメソッドに抽出する

既存の `splitIntoSentences()` の文分割ロジックを `_splitText()` に抽出し、`splitIntoSentences()` は二重ストリッピング+zip のオーケストレーターとする。

## Risks / Trade-offs

- **テキストハッシュの変更** → 既存の生成済みTTS音声は再生成が必要になる。ただし、これは `text_hash` の不一致検出により自動的に処理されるため、ユーザー操作は不要。
- **`text.length != length`** → `TextSegment.text` はruby text、`TextSegment.length` はbase text長になるため、値が異なる場合がある。これは意図された設計であり、`text` はTTS用、`length` はハイライト用と明確に用途が分かれている。
- **二重ストリッピングのコスト** → 正規表現を2回適用するが、テキスト量は小さく（1エピソード分）性能への影響は無視できる。
- **TTS編集画面の表示テキスト変更** → セグメントのtext列にふりがなが入るため、編集画面でユーザーが見るテキストが変わる。これは意図された動作であり、読み上げ対象テキストが正しく表示されることになる。
