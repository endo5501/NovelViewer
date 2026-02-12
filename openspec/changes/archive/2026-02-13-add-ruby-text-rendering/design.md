## Context

現在、テキストビューア (`TextViewerPanel`) は `SelectableText.rich(TextSpan)` でプレーンテキストを表示している。ダウンロード済みテキストファイルにはHTMLルビタグ（`<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>`）がそのまま含まれており、生のHTML文字列として表示されてしまう。

既存のパイプライン:
```
ファイル読み込み (String) → buildHighlightedTextSpan() → SelectableText.rich()
```

## Goals / Non-Goals

**Goals:**
- HTMLルビタグをパースし、親文字の上にルビ（振り仮名）を視覚的に描画する
- 既存の検索ハイライト機能を維持する
- 既存のスクロール・テキスト選択機能を維持する

**Non-Goals:**
- 縦書きレイアウト対応
- ルビ以外のHTML要素の描画対応
- テキストファイルの保存形式の変更

## Decisions

### 1. パース方式: 正規表現ベースのパーサー

**選択**: 正規表現で `<ruby>...</ruby>` タグをパースする

**理由**: 保存されるルビタグの形式は `_blockToText()` によって生成され、フォーマットが固定されている。`html` パッケージによるフルDOM解析はオーバーキルであり、正規表現で十分かつ高速に処理できる。

**代替案**:
- `html` パッケージでDOM解析 → ルビタグのみに対してはオーバースペック、パフォーマンス上も不利

### 2. データモデル: セグメントリスト

**選択**: テキストコンテンツを `List<TextSegment>` にパースする

```dart
sealed class TextSegment {}
class PlainTextSegment extends TextSegment { String text; }
class RubyTextSegment extends TextSegment { String base; String rubyText; }
```

**理由**: パース結果を構造化データとして持つことで、描画・検索・テキスト選択それぞれの処理から参照できる。sealed classにすることでパターンマッチによる網羅性チェックが可能。

### 3. 描画方式: WidgetSpanベースのインライン描画

**選択**: `SelectableText.rich()` 内で `WidgetSpan` を使用し、ルビ付きテキストをインライン描画する

ルビ部分は `WidgetSpan` 内の `Column` で構築:
```
  [ルビテキスト]  ← 小さいフォントサイズ
  [ベーステキスト] ← 通常フォントサイズ
```

**理由**:
- 既存の `SelectableText.rich(TextSpan)` 構造と互換性がある
- 追加パッケージ不要
- プレーンテキスト部分の選択・ハイライトは従来通り動作する

**代替案**:
- `flutter_html` パッケージ → 大きな依存追加、既存の検索ハイライトとの統合が困難
- カスタム `RenderObject` → 実装コストが高すぎる
- `ruby_text` パッケージ → メンテナンス状況が不明

### 4. 検索ハイライトとの統合

**選択**: パース結果からプレーンテキスト（ルビタグ除去済み）を生成し、検索・ハイライトはプレーンテキストベースで行う

パイプライン変更:
```
ファイル読み込み (String)
  → parseRubyText() → List<TextSegment>
  → buildPlainText() → String (検索・選択用)
  → buildRubyTextSpans() → TextSpan (描画用、WidgetSpan含む)
```

検索ハイライトはプレーンテキスト上の位置を計算し、セグメント単位でハイライトスタイルを適用する。

### 5. テキスト選択の方針

**選択**: WidgetSpan内のルビベーステキストは選択不可として許容する

**理由**: Flutterの制約上、`WidgetSpan` 内のテキストは `SelectableText` の選択範囲に含まれない。しかし、ルビはWeb小説で部分的に使用されるものであり、テキストの大部分はプレーンテキストとして選択可能。視覚的改善の利点が選択制限のデメリットを上回る。

## Risks / Trade-offs

- **[テキスト選択制限]** → WidgetSpan内のテキストは選択できない。ルビ付き箇所を含む範囲のコピー時に、ルビベーステキストが欠落する可能性がある。将来的にカスタムRenderObjectで改善可能
- **[行高さの変動]** → ルビ付き行はルビ分だけ高くなる。スクロール位置の計算精度が低下する可能性がある → 許容範囲として扱い、大きな問題があれば後で対応
- **[正規表現パースの制約]** → 想定外のルビHTML形式には対応できない → 現在のダウンローダーが生成する形式のみをサポートすれば十分
