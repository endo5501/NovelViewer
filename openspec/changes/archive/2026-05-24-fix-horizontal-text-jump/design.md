## Context

横書きテキストビューア (`lib/features/text_viewer/presentation/widgets/text_content_renderer.dart`) は、`SelectableText.rich(textSpan)` を `SingleChildScrollView` 内に配置している。`textSpan` は `buildRubyTextSpans(segments, textStyle, query, ...)` で生成され、ルビは Flutter の `WidgetSpan`/`PlaceholderSpan` 等を用いて本文行に追加レイアウトされる。

検索マッチをクリックすると `selectedSearchMatchProvider` が更新され、ビルド時の以下のロジックで該当行へスクロールする (現状):

```dart
double _computeLineHeight(TextStyle? textStyle) {
  final fs = textStyle?.fontSize ?? 14.0;
  return (textStyle?.height ?? 1.5) * fs;
}

double _lineNumberToOffset(int lineNumber, TextStyle? textStyle) {
  return (lineNumber - 1) * _computeLineHeight(textStyle);
}

void _scrollToLineNumber(int lineNumber, TextStyle? textStyle) {
  final clampedOffset =
      _lineNumberToOffset(lineNumber, textStyle).clamp(0.0, maxOffset);
  _scrollController.animateTo(clampedOffset, ...);
}
```

同じ `_lineNumberToOffset` は `bookmarkLines` の `Positioned(top: ...)` でも使われている。両者とも上記の固定式に依存する。

縦書きは `VerticalTextViewer` に `targetLineNumber` を渡し、レイアウト結果から行→ページの対応を取得するため影響を受けない。

## Goals / Non-Goals

**Goals:**

- 横書きで検索マッチをクリックした際、該当行が viewport の上部 (padding を考慮) に正確に表示される。
- ルビ付き行、自動折り返しが発生する長い行、デフォルトと異なるフォントファミリ使用時にも誤差が半行程度以内。
- 横書きブックマーク行アイコンの Y 位置を同じ実測関数で算出し、副次的に位置精度を改善する。
- 縦書きモードは挙動を変えない (リグレッションなし)。

**Non-Goals:**

- 縦書きモードのスクロール/ページング挙動の変更。
- 検索ハイライトの色・スタイルの変更。
- TTS ハイライトスクロール (`_scrollToTtsHighlight`) の変更 (将来流用可能な形にはする)。
- bookmark-ui spec の MODIFY (既存要件は位置精度を要求していないため、暗黙的改善に留める)。

## Decisions

### 決定 1: `TextPainter` で実測 Y 座標を取得する (案 C 採用)

新ヘルパー `_measureLineNumberOffset(int lineNumber, double maxWidth)`:

1. `_lineStartOffsets` (キャッシュ) から N 行目の先頭グローバル文字インデックス `lineStart` を取得。
2. `TextPainter(text: textSpan, textDirection: TextDirection.ltr, textWidthBasis: TextWidthBasis.longestLine, ...)` を生成。
3. `textPainter.layout(maxWidth: maxWidth)` を実行。
4. `textPainter.getOffsetForCaret(TextPosition(offset: lineStart), Rect.zero).dy` を取得。
5. 描画 padding (16.0) を加算して返す。
6. `dispose()` を呼ぶ。

スクロール時はこの値を `_scrollController.position.maxScrollExtent` で clamp する。

**代替案**:
- (案 D) `Scrollable.ensureVisible` + 各行頭に `Key` 付き透明 widget を配置 → 行数分の widget 増加 (数万行 novel で深刻な負荷)。
- (案 E) `SelectableText` 内部 caret API → API 不安定、テスト困難。

採用理由: 既存の `textSpan` をそのまま流用でき、追加メモリは `_lineStartOffsets` の `List<int>` のみ。`TextPainter` は描画フレーム外で動かせるため一時的なコスト。

### 決定 2: `_lineStartOffsets` をキャッシュする

`content` 内の `\n` 位置を 1 度だけスキャンして `List<int>` を生成。`didUpdateWidget` で `content` 変更時に無効化。

```dart
List<int>? _lineStartOffsets;

List<int> _computeLineStartOffsets(String content) {
  final offsets = <int>[0];
  for (var i = 0; i < content.length; i++) {
    if (content.codeUnitAt(i) == 0x0A) offsets.add(i + 1);
  }
  return offsets;
}
```

content 長を N とすると O(N)、50万文字程度でも数ミリ秒。実行は content 変更時のみ。

#### 実装時の修正 (TextPainter caret 空間への切替)

上記の素朴な実装は raw content 上の `\n` を数えるが、`TextPainter.getOffsetForCaret` が期待するのは **TextSpan tree 上の caret offset** で、`buildRubyTextSpans` は `<ruby>...<rt>...</rt></ruby>` 1 個を **1 個の `WidgetSpan` (= 1 caret unit)** に圧縮する。ルビ 1 個ごとに「raw markup 文字数 − 1」分のずれが累積し、ルビが多い長文では数行〜十数行先に着地する不具合が出たため、実装では **`parseRubyText` 済みの `segments` を入力に取る** `computeTextPainterLineStartOffsets(List<TextSegment> segments)` に置換した。`_measureLineNumberOffset` / `_bookmarkLineYsFor` も `segments` を受け取って同関数経由で offset を取得する。`computeLineStartOffsets(String)` 自体は純粋ユーティリティとして残置 (テストおよび将来用途)。

### 決定 3: `LayoutBuilder` で Viewport 幅を取得する

`SingleChildScrollView` の child を `LayoutBuilder` で囲み、`constraints.maxWidth - leftBookmarkGutter - horizontalPadding*2` を `maxWidth` として `TextPainter` に渡す。具体的には:

- `SingleChildScrollView` 自体の padding は `EdgeInsets.all(16.0)` → 横方向 32 引く
- `bookmarkLines.isEmpty ? 0 : 20` の bookmark gutter padding を引く

これらを正確に計算しないと折り返し位置がレンダリングと一致せず Y 座標がずれる。**最重要**。

### 決定 4: `_scrollToLineNumber` と `bookmarkLines` の `Positioned.top` で同一関数を使用

両方とも `_measureLineNumberOffset` を経由させる。テストの観点でも、ブックマーク表示テストでヘルパーの正しさを確認できる。

ただしブックマーク行アイコンの座標は描画フレーム内で取得する必要があるので、build 内で `LayoutBuilder` の constraints から `maxWidth` を求めてから呼ぶ。Bookmark の `top` には padding 16.0 を含めず、TextPainter の生 Y を渡す (Bookmark は padding の内側で Positioned されるため。実装時にレイアウト構造を再確認)。

### 決定 5: TTS スクロール (`_scrollToTtsHighlight`) は触らない

ユーザー報告は検索ジャンプのみ。TTS スクロールも同じ問題を抱えるが、影響範囲を絞るため別途扱う。新ヘルパーは `int lineNumber` ではなく `int globalCharOffset` を引数に取る形に設計しておくと、TTS の文字オフセットベースの呼び出しにも流用できる。具体的には:

```dart
double _measureCharOffsetY(int globalCharOffset, double maxWidth) { ... }
double _measureLineNumberOffset(int lineNumber, double maxWidth) {
  final idx = _lineStartOffsets![lineNumber - 1];
  return _measureCharOffsetY(idx, maxWidth);
}
```

## Risks / Trade-offs

- **[Risk]** `TextPainter` 生成・レイアウトはフレーム時間を圧迫する → **Mitigation**: スクロール時のみ (検索クリック直後の 1 度だけ) 実行。ビルド中の毎フレームには走らせない。ブックマーク Positioned 用は build 中に呼ぶが、結果をキャッシュする (例: `_bookmarkOffsetCache: Map<int, double>`、content/style/maxWidth の組合せで無効化)。
- **[Risk]** `WidgetSpan`/`PlaceholderSpan` を含む `textSpan` を `TextPainter` でレイアウトする際の caret 位置が、実際の `SelectableText.rich` のレンダリングと完全一致しない可能性 → **Mitigation**: 同じ `TextStyle`/`textDirection`/`maxWidth` を使えば一致するはず。テストで実測差を計測し、半行以内に収まることを確認。
- **[Risk]** `maxWidth` を正しく計算しないと折り返し位置がずれ、すべての行で Y 座標が累積的にずれる → **Mitigation**: 既存レイアウト構造 (padding, bookmark gutter) を逐次 `Stack`/`Padding` の構造と突き合わせて検証。テストでも `maxWidth` を変えるケースを追加。
- **[Risk]** 折り返しが多い長文では `TextPainter.layout` のコストが大きい → **Mitigation**: 一度レイアウトすれば同じインスタンスで複数の `getOffsetForCaret` を呼べる。ブックマークが複数ある場合は同じ painter を使い回す。
- **[Trade-off]** content 変更時に `_lineStartOffsets` 再計算が走るが、O(N) 1 回で十分軽量。受容。

## Migration Plan

- 設定永続化や DB 変更なし。
- 既存ユーザーは検索ジャンプの精度向上のみを体感する。リグレッションは縦書きモード非変更で防ぐ。

## Open Questions

- ブックマークアイコンの Y 位置精度が現状どれほどズレているか実機確認していない。実装時に同時に直る前提だが、もし別軸 (Stack の親 padding 等) のズレがあれば追加対応が必要。実装時に確認。
