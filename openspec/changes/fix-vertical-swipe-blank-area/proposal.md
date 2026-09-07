## Why

縦書きモードで、文字が描画されていない余白をスワイプしてもページ送りが動作しない。スワイプ検出は `VerticalTextPage` の `GestureDetector` だけが担っているが、その子は中身にシュリンクラップする `Wrap` であり、さらに `VerticalTextViewer` 側で `Align(alignment: Alignment.topRight)` によって右上へ寄せられている。結果として、当たり判定はテキストが実際に描かれた矩形そのものに一致し、余白はヒットテストの外側になる。

800×600・fontSize 16 で `VerticalTextPage` の矩形を実測した結果:

| ケース | ページ矩形 | 左側の無反応領域 |
|---|---|---|
| 文字が埋まったページ | `(32,16)-(784,560)` | 32px |
| エピソード最終ページ（内容が短い） | `(480,16)-(784,560)` | **480px（画面幅の 60%）** |
| 改行のない 1 段落だけのページ | `(640,16)-(784,584)` | **640px（画面幅の 80%）** |

読み終えた最終ページこそ余白が最も広く、かつ「次話へ進む」操作をしたい場所であるため、実害が大きい。iPad ではスワイプが唯一のページ送り手段であり、この問題が常用の妨げになっている。

## What Changes

- `VerticalTextPage` の当たり判定を、テキストの描画矩形ではなく **与えられた領域全面** に広げる。`Align(alignment: Alignment.topRight)` を `VerticalTextViewer` から `VerticalTextPage` の `GestureDetector` の内側へ移し、`GestureDetector` 自身は利用可能な領域いっぱいに広がるようにする。
- これにより、余白（特に最終ページ左側）からのスワイプでもページ送りが動作する。
- 文字の当たり判定（選択・ホバー）の座標系は `_rebuildHitRegions` が `localToGlobal(ancestor: pageRenderObject)` で構築しているため、ページ矩形の拡大に自動追従する。座標補正コードは追加しない。
- 余白タップで選択が解除される既存挙動は維持する。余白は最寄り文字への吸着距離（列間隔）を超えるため、従来どおり「文字なし」と解決される。
- 表示上のレイアウト（テキストが右上寄せで描画されること）は一切変更しない。
- スワイプで選択を解除したとき、`onSelectionChanged(null)` を必ず通知する。現在は `_handleSwipeEnd` が内部の選択状態だけを消し、通知はページ移動が成立したときに `VerticalTextViewer._changePage` が行っている。境界ページでは `_changePage` が `_handleBoundaryNavigation` へ早期 return するため通知に到達せず、**ハイライトは消えているのに `selectedTextProvider` は古い選択を保持したまま**になる。既存の不具合だが、当たり判定の拡張によって発生領域がページ全面へ広がるため本変更に含める。

対象外（本変更では扱わない）:

- ページ外周 16px のパディング帯と、画面下端のページ番号表示帯（約 24px）は引き続きスワイプ対象外のまま。左側の実害が解消されれば残余は 16px であり、費用対効果が見合わないため。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `vertical-text-display`: スワイプのヒット領域が「描画されたテキスト矩形」ではなく「ページに与えられた領域全面」であることを要件化する。あわせて `Wrap` を包む構造（`GestureDetector` > `Align` > `Wrap`）を rendering 要件に反映する。
- `vertical-text-selection`: ドラッグ／タップが文字のない領域から始まった場合の扱い（選択は開始しない、スワイプ判定の対象にはなる、タップは選択解除）を明文化する。あわせて、スワイプで選択を解除したときはページが実際に移動したかによらず解除を通知する要件を追加する。

## Impact

- `lib/features/text_viewer/presentation/vertical_text_page.dart`: `build` の widget ツリーに `Align` を追加、`_handleSwipeEnd` で選択解除を通知
- `lib/features/text_viewer/presentation/vertical_text_viewer.dart`: incoming／outgoing 両ページを包んでいた `Align` を除去
- テスト: `test/features/text_viewer/presentation/` 配下の縦書きスワイプ／選択関連テスト
- 依存パッケージ・API・データ形式への影響なし
