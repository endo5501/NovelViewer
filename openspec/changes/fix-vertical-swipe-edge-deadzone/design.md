## Context

縦書きビューアのスワイプ判定は `VerticalTextPage` 内の `GestureDetector`（`onPan*`）だけが持っている。過去の修正（`vertical_swipe_hit_area_test.dart` が守っている）で、`Align` を `GestureDetector` の内側へ移し、ページの描画ボックスが与えられた領域全体を覆うようにした。これにより「文字が描かれていない左側の空白をスワイプしてもページが送られない」という不具合は解消した。

しかし余白そのものは、まだ `VerticalTextViewer` 側に残っている。

```
Expanded
 └ Stack
    ├ ClipRect
    │   └ Padding( all: 16 )        ← 認識器の外側
    │      └ pageContent
    │         └ VerticalTextPage
    │            └ MouseRegion
    │               └ GestureDetector (opaque)   ← スワイプ判定はここだけ
    │                  └ Align(topRight)
    │                     └ Wrap > 文字
    └ Positioned(left: 4, top: 4) しおりアイコン
```

`Padding` が `GestureDetector` より外側にあるため、ビューア領域の外周 16pt には認識器が存在しない。この帯を触ると `VerticalTextViewer` の `Listener`（`HitTestBehavior.opaque`）に当たるが、`Listener` はフォーカス要求と `PointerSignalEvent` しか扱わずジェスチャアリーナに参加しない。結果としてドラッグは無視される。

wide レイアウト（幅 800pt 以上）ではビューアの左に 250pt のファイルブラウザがあり、右カラムも開けるため、死角が画面端に重なることは少なかった。narrow レイアウト（iPad 縦向き、iPad mini で 744pt）ではビューアが `Scaffold` の body 全幅を占めるので、16pt の死角が物理的な画面端にそのまま露出する。さらに iPadOS が画面端約 20pt で保持するシステムジェスチャ領域が外側に重なり、体感の死角は 5mm 前後になる。

## Goals / Non-Goals

**Goals:**

- ビューアのコンテンツ領域の端まで、スワイプによるページ送りが反応すること
- テキストの見た目の余白（上下左右 16pt）を変えないこと
- 文字の当たり判定（選択、ホバー、コンテキストメニュー）が 1 文字もずれないこと
- ページ分割結果が変わらないこと

**Non-Goals:**

- iPadOS のシステムジェスチャ領域への対処（`preferredScreenEdgesDeferringSystemGestures`）。今回の症状は「常に無反応、中央にずらすと解消」であり、原因はパディングで確定している。この設定は Slide Over を妨げる副作用があるため、パディング修正後に端がまだ不安定に感じられた場合に別変更として検討する
- タッチ時の pan slop（Flutter 既定 36pt）やスワイプ距離閾値（50pt / 80pt）の調整
- 端タップによるページ送りという新しい操作方法の追加
- 横書きモードの操作

## Decisions

### 決定 1: `Padding` を `GestureDetector` の内側へ移す

`VerticalTextViewer` の `Padding` を削除し、`VerticalTextPage` の `GestureDetector` と `Align` の間に `Padding(EdgeInsets.all(16.0))` を挿入する。

```
移動後
Expanded
 └ Stack
    ├ ClipRect
    │   └ pageContent
    │      └ VerticalTextPage
    │         └ MouseRegion              ← 全域
    │            └ GestureDetector       ← 全域。ここが目的
    │               └ Padding( all: 16 ) ← 挿入
    │                  └ Align(topRight)
    │                     └ Wrap > 文字
    └ IgnorePointer > Positioned しおりアイコン
```

余白の値 16 はページ側の実装詳細になるため、`VerticalTextPage` に名前付き定数として置く。

**代替案 A: `Padding` の外側に透明な `GestureDetector` を重ねて端だけ拾う。** 却下。認識器が 2 つになり、ジェスチャアリーナでの競合と、選択ドラッグが端から始まったときの扱いという新しい複雑さを持ち込む。スワイプ判定は 1 箇所という現在の設計を崩す。

**代替案 B: ビューア側の `Padding` を削除し、`Align` の代わりに `Container(padding:)` を使う。** 却下。`Container` は `Align` と `Padding` を内部で組み合わせるだけで、明示的な 2 ウィジェットより読み取りにくい。

### 決定 2: 当たり判定の座標系は変更不要

`Padding` の挿入で文字矩形とポインタ座標がずれないことを確認済み。

矩形側は `_rebuildHitRegions` がこう作る。

```dart
final pageRenderObject = context.findRenderObject();   // ページ最外の RenderBox
final topLeft = renderObject.localToGlobal(
  Offset.zero,
  ancestor: pageRenderObject,
);
```

`localToGlobal(ancestor:)` は文字の `RenderBox` から最外ボックスまでの変換をすべてたどるので、間に挟まった `Padding` の 16pt も累積される。

ポインタ側の `localPosition` の出どころは 2 つだけで、どちらも最外ボックスと矩形が一致する。

| 呼び出し元 | 基準 RenderBox | 最外ボックスとの関係 |
|---|---|---|
| `MouseRegion.onHover` | `RenderMouseRegion` | 最外ボックスそのもの |
| `GestureDetector` の pan / tap | `RenderPointerListener` | `MouseRegion` の直下の Proxy ボックス、矩形一致 |

両者が同じ空間で一緒に 16pt 動くため差分は生じない。`_hitRegionsSize` はページのサイズ変化を検知して矩形を作り直す仕組みなので、サイズが 32pt 大きくなった直後に一度だけ再構築が走って収束する。

とはいえこの不変条件は暗黙で壊れやすいため、「文字をタップして解決される文字インデックスが移動前と一致する」ことを回帰テストで固定する。

### 決定 3: ページ分割の定数は値を変えず、余白定数から導出する

`LayoutBuilder` は `Padding` より外側にあり、`constraints` は常にビューア全域である。組版は `Padding` ウィジェットの位置ではなくこの定数に依存しているので、移動しても分割結果は 1 文字も変わらない。

```dart
final availableWidth  = constraints.maxWidth  - _kHorizontalPadding;
final availableHeight = constraints.maxHeight - _kVerticalPadding;
```

ただし余白の値がビューアとページの 2 ファイルに分かれることになる。コメントだけで対応関係を示すと片方だけが動かされる余地が残るので、定数をリテラルからページ側の定数を使った式に置き換える。

```dart
// 変更前
const _kHorizontalPadding = 32.0;
const _kVerticalPadding   = 62.0;

// 変更後
const _kHorizontalPadding = 2 * kVerticalTextMargin;
const _kVerticalPadding   = 2 * kVerticalTextMargin + 30.0;   // + ページ番号行
```

`kVerticalTextMargin` は 16.0 なので値は 32.0 と 62.0 のまま完全に一致する。いずれも 2 の冪を含む小さい整数値なので丸め差も生じない。

### 決定 4: しおりアイコンを `IgnorePointer` で包む

`Stack` の `defaultHitTestChildren` は前面の子から順に試し、最初に当たった子で探索を打ち切る。`Icon` は内部の `RichText` が `hitTestSelf` で true を返すため、左上の約 20pt 四方でヒットを消費し、下の `ClipRect` 側までポインタが届かない。`IgnorePointer` で包めば `Stack` はこの子を飛ばして次の子を試す。

装飾表示であり操作対象ではないので、ポインタを無視するのが正しい。

### 決定 5: `ClipRect` の扱い

`ClipRect` は `Padding` を介さず `pageContent` を直接包む。クリップ範囲は現在も移動後もビューア全域で変わらない。`SlideTransition` の移動量がページ幅（全域幅 - 32 から全域幅へ）だけ増えるが、スライドアウトするページが画面端まで見えるようになるだけで、むしろ自然になる。

## Risks / Trade-offs

**[余白の値がビューアとページの 2 ファイルに分かれる]** → `VerticalTextPage` 側に名前付き定数を置き、`vertical_text_viewer.dart` の `_kHorizontalPadding` / `_kVerticalPadding` のコメントから参照関係を明示する。既存テストが両者の整合を間接的に守る。

**[`VerticalTextPage` を単体で使う既存テストのレイアウトが 32pt 変わる]** → `vertical_swipe_hit_area_test.dart` のハーネスは `Align` でビューアの loose 制約を再現している。ページが自前の余白を持つようになるため、ハーネスの前提コメントを更新し、文字位置を絶対値で検証している箇所があれば相対検証に直す。

**[当たり判定が 16pt ずれる潜在バグ]** → 座標系の解析上ずれないことは確認済みだが、暗黙の不変条件なので回帰テストで固定する。文字をタップして得られる文字インデックスが変更前後で一致することを検証する。

**[ホバーが余白領域でも発火するようになる]** → `MouseRegion` が全域を覆うため、余白上でも `onHover` が呼ばれる。`_hitTest` は該当矩形がなければ null を返し、`_markedRanges[null]` に至らず新しいトークンは null になるので、既存の差分ロジックがそのまま「マークなし」として扱う。落ちないことをテストで確認する。

**[縦方向の死角も同時に消える]** → `EdgeInsets.all(16.0)` なので上下 16pt も有効域になる。スワイプは横方向判定なので影響はなく、上下端からの選択ドラッグが可能になるのは改善にあたる。
