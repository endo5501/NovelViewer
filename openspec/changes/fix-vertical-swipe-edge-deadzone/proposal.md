## Why

iPad で縦書き表示を使うと、画面の左右端でスワイプによるページ送りがまったく反応しない。原因は `VerticalTextViewer` の `EdgeInsets.all(16.0)` が `VerticalTextPage` の `GestureDetector` より外側に置かれていることで、ビューア領域の外周 16pt にはドラッグ認識器が一つも存在しない。この帯を触っても上位の `Listener`（フォーカス要求とマウスホイールしか見ていない）に当たるだけで、指の動きは捨てられる。

デスクトップでは左カラムと右カラムが両脇にあるため死角が画面端に重ならず気付かれなかったが、幅 800pt 未満の narrow レイアウト（iPad 縦向き）ではビューアが全幅を占めるため、この死角が物理的な画面端にそのまま露出する。

## What Changes

- `VerticalTextViewer` が持つ `Padding(EdgeInsets.all(16.0))` を、`VerticalTextPage` 内部の `GestureDetector` 直下へ移す。`GestureDetector` がビューアのコンテンツ領域全体を占めるようになり、外周 16pt の死角が消える。テキストの見た目の余白は変わらない。
- `VerticalTextViewer` の `ClipRect` は `Padding` を介さず `pageContent` を直接包む。
- しおりアイコン（`Positioned(left: 4, top: 4)`）を `IgnorePointer` で包む。`Stack` は前面の子から順にヒットテストして最初に当たった時点で止まるため、現状は左上の約 20pt 四方がページに届いていない。
- ページ分割の定数 `_kHorizontalPadding = 32.0` / `_kVerticalPadding = 62.0` は変更しない。`LayoutBuilder` はパディングより外側にあり `constraints` は常にビューア全域なので、`Padding` ウィジェットの位置に依存しない。

破壊的変更はない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `vertical-text-display`: 「Swipe gesture page navigation」要件のスワイプ有効域の定義を、「`VerticalTextPage` に与えられた領域全体」から「ビューアのコンテンツ領域全体（テキストの余白を含む）」へ広げる。あわせて余白が `GestureDetector` の内側にあることを要件として固定する。

## Impact

- `lib/features/text_viewer/presentation/vertical_text_viewer.dart`: `Padding` の削除、`ClipRect` の子の差し替え、しおりアイコンの `IgnorePointer` 包み
- `lib/features/text_viewer/presentation/vertical_text_page.dart`: `GestureDetector` と `Align` の間へ `Padding` を挿入
- `test/features/text_viewer/presentation/vertical_swipe_hit_area_test.dart`: ビューア外周からのスワイプと座標ずれ非発生の回帰テストを追加。ハーネスの `Align` に関する前提コメントの更新
- 当たり判定の座標系は影響を受けない。`_rebuildHitRegions` は `localToGlobal(ancestor: pageRenderObject)` で最外ボックスまでの変換を累積するため、挿入した `Padding` のオフセットは文字矩形側にも自動的に乗る。ポインタ側の `localPosition` は `MouseRegion` と `GestureDetector` のボックス基準で、どちらもページ最外ボックスと矩形が一致する。両者が同じ空間で一緒に 16pt 動くため差分は生じない。
- iPadOS 自体が画面端約 20pt で保持するシステムジェスチャ領域は本変更の対象外。今回の症状は「常に無反応」で位置を中央にずらすと解消することから、原因はパディングで確定している。
