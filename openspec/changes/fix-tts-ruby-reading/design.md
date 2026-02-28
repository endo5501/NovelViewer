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

## Goals / Non-Goals

**Goals:**
- `_stripRubyTags()` がruby text（ふりがな）を返すようにする
- 既存テストの期待値を新しい動作に合わせて更新する

**Non-Goals:**
- 文分割ロジック自体の変更
- UI表示側のルビ処理（`ruby_text_parser.dart`）の変更
- 既存TTS音声データのマイグレーション（text_hashの不一致により自動再生成される）

## Decisions

### Decision 1: 正規表現にキャプチャグループを追加し、参照先を変更する

**変更**: `<rt>` の内容を新たにキャプチャグループ2として定義し、`match.group(2)` を返すようにする。

```dart
// Before
r'<ruby>(?:<rb>)?(.*?)(?:</rb>)?(?:<rp>.*?</rp>)?<rt>.*?</rt>(?:<rp>.*?</rp>)?</ruby>'
//                                                    ^^^^ キャプチャなし

// After
r'<ruby>(?:<rb>)?(.*?)(?:</rb>)?(?:<rp>.*?</rp>)?<rt>(.*?)</rt>(?:<rp>.*?</rp>)?</ruby>'
//                                                    ^^^^^^ キャプチャグループ2を追加
```

```dart
String _stripRubyTags(String text) {
  return text.replaceAllMapped(_rubyTagPattern, (match) {
    return match.group(2) ?? '';  // ruby text（ふりがな）を返す
  });
}
```

**理由**: 最小限の変更で目的を達成できる。正規表現パターン自体の構造は変わらず、キャプチャグループの追加と参照先の変更のみ。

**代替案**: 正規表現を書き直す → 不要な複雑さ。既存パターンは十分に検証されている。

### Decision 2: テストの期待値を更新する

既存テスト（`text_segmenter_test.dart`）のルビ関連テストケースは、base textが返されることを期待している。これらの期待値をruby text（ふりがな）に変更する。

対象テストケース:
- `strips ruby tags and uses base text only`: `漢字を読む。` → `かんじを読む。`
- `strips multiple ruby tags`: `東京の空。` → `とうきょうのそら。`
- `strips ruby tags with rb element`: `漢字を読む。` → `かんじを読む。`
- `strips ruby tags with rb and rp elements`: `漢字を読む。` → `かんじを読む。`
- `produces same plain text as parseRubyText for rb format`: `東京の空。` → `とうきょうのそら。`

## Risks / Trade-offs

- **テキストハッシュの変更** → 既存の生成済みTTS音声は再生成が必要になる。ただし、これは `text_hash` の不一致検出により自動的に処理されるため、ユーザー操作は不要。
- **セグメントのoffset/length値の変化** → ルビテキストはbase textと文字数が異なる（例: `漢字`=2文字 vs `かんじ`=3文字）。offset/lengthはストリップ後のテキスト内の位置を追跡しているため、値が変わるがロジックに影響はない。テストの期待値を合わせて更新する。
- **TTS編集画面の表示テキスト変更** → セグメントのtext列にふりがなが入るため、編集画面でユーザーが見るテキストが変わる。これは意図された動作であり、読み上げ対象テキストが正しく表示されることになる。
