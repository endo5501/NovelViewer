## Context

縦書きモードのスワイプ検出は `VerticalTextPage` の `GestureDetector`（`vertical_text_page.dart:245`）だけが担う。仕様（`vertical-text-display` の「Swipe gesture page navigation」）でも、選択とスワイプを **同一のジェスチャーレコグナイザ** で調停する設計（`undecided` → `selecting` / `swiping`）が明示されている。

現在の widget ツリー:

```
VerticalTextViewer
  Listener(opaque)                 ← onPointerDown / onPointerSignal のみ。ドラッグは見ない
    LayoutBuilder
      Column
        Expanded
          Stack
            ClipRect
              Padding(all: 16)
                Align(topRight)    ← ここでシュリンクラップした子を右上へ寄せる
                  VerticalTextPage
                    MouseRegion
                      GestureDetector(opaque)   ← 当たり判定 = Wrap のサイズ
                        Directionality(rtl)
                          Wrap(vertical)        ← 中身にシュリンクラップ
        Text('n / m')              ← ページ番号帯
```

`Wrap` は中身のサイズにシュリンクラップするため、`GestureDetector` の矩形＝描画されたテキストの矩形になる。`Align` はそれを右上に寄せるだけで、余った左側の領域はどのウィジェットもヒットテストを受け付けない。上位の `Listener` は `onPointerDown` と `onPointerSignal` しか扱わないため、余白はドラッグに対して完全な無反応領域となる。

実測値は proposal.md の表を参照。最終ページでは画面幅の 60〜80% が無反応になる。

なお縦方向は、改行が `SizedBox(width: 0, height: double.infinity)` のセンチネル列として `Wrap` に入る（`vertical_text_page.dart:213-221`）ため、改行が 1 つでもあるページでは `Wrap` の高さが常に領域いっぱいになる。高さ方向のデッドゾーンは「改行が 1 つも無いページ」でのみ発生し、実害は左側に比べて小さい。

## Goals / Non-Goals

**Goals:**

- テキストの有無にかかわらず、ページ領域内のどこからでもスワイプでページ送りができる
- 表示レイアウト（テキストの右上寄せ）を変えない
- 選択・ホバー・コンテキストメニューの既存挙動を変えない。特に余白タップでの選択解除は維持する
- 選択とスワイプを 1 つのレコグナイザで調停する既存設計を維持する（仕様上の制約）

**Non-Goals:**

- ページ外周 16px の `Padding` 帯をスワイプ対象にすること
- 画面下端のページ番号表示帯（約 24px）をスワイプ対象にすること
- スワイプの距離・速度しきい値（`kSwipeMinDistance` 等）の調整
- 横書き（横スクロール）モードの挙動変更

## Decisions

### 決定 1: `Align(topRight)` を `GestureDetector` の内側へ移す

`VerticalTextViewer` 側の `Align` を除去し、`VerticalTextPage` の `GestureDetector` の子として `Align(alignment: Alignment.topRight)` を置く。

```
GestureDetector(opaque)      ← 当たり判定 = 与えられた領域全面
  Align(topRight)            ← 制約が有界かつ loose なので constraints.biggest まで広がる
    Directionality(rtl)
      Wrap(vertical)         ← 従来どおりシュリンクラップし、右上に配置される
```

`Align` は `widthFactor` / `heightFactor` を指定しない場合、有界な制約の下では `constraints.biggest` まで広がる。したがって `GestureDetector` は `Padding` 内の領域全面を占め、`Wrap` の描画位置は従来と同一になる。

**なぜこの案か:**

- 既存のジェスチャー調停ロジック（`_GestureMode`）にも `detectSwipeFromDrag` にも一切手を入れずに済む
- 文字の当たり判定は `_rebuildHitRegions`（`vertical_text_page.dart:563`）が
  `renderObject.localToGlobal(Offset.zero, ancestor: pageRenderObject)` で各文字矩形を作っている。
  `pageRenderObject` はページ自身のレンダーボックスなので、ボックスが広がれば右上寄せ分のオフセットが
  自動的に矩形へ織り込まれる。`details.localPosition` も同じボックス基準であるため、**座標補正コードは不要**。
- 変更行数が小さく、レビューと巻き戻しが容易

**検討した代替案:**

| 案 | 内容 | 不採用の理由 |
|---|---|---|
| B. 背面に全面スワイプ層 | `Stack` の下層に全面 `GestureDetector` を敷き、余白のイベントだけそこへ抜けさせる | パディング帯まで拾える利点はあるが、スワイプ検出コードが 2 箇所に分かれ、アリーナ調停の検証コストが増える。得られる差分は 16px |
| C. ビューア全体に `HorizontalDragGestureRecognizer` | 最上位で横ドラッグを取る | ページ内の「選択 vs スワイプ」を 1 つのレコグナイザで捌く現設計（仕様に明記）と競合し、選択ドラッグがアリーナで奪われる恐れがある |
| D. `Wrap` を `SizedBox.expand` で包む | 当たり判定は広がるが `Wrap` が左上基準になる | 右上寄せの描画が崩れるため、結局 `Align` が必要になり案 A と同じになる |

### 決定 2: 余白タップの扱いは現状維持（追加実装なし）

ページ矩形が広がることで、余白のタップも `_onTapUp` に届くようになる。`_onTapUp` は `_hitTest` を列間隔ぶんの吸着距離つきで解決し、該当なしなら選択解除する。余白は吸着距離を超えるため「文字なし」と解決され、**従来どおり選択解除**になる。ユーザー確認済みの期待挙動と一致するため、分岐は追加しない。

同様に、余白から始まるドラッグは `_onPanStart` で `_anchorIndex` が `null` になり `_startSelection` が早期 return するため、選択は開始されない。一方 `_panStartGlobalPosition` は `_onPanDown` で無条件に記録される（`vertical_text_page.dart:310`）ので、スワイプ判定は正常に働く。この非対称性は既存コードのままで成立する。

### 決定 3: `MouseRegion` の拡大は許容する

`MouseRegion` もページ矩形と同じく全面に広がる。従来は余白へマウスを移動すると `onExit` でポップアップが隠れていたが、変更後は `_onHover` が `charIndex == null` で発火し、`onMarkExit` 経由で同じくポップアップが隠れる。結果は等価であり、追加対応は不要。

### 決定 4: スライドアニメーションの移動量は変わらない

当初「短い最終ページでは移動量が小さかったものが画面幅ぶんに揃う」と見立てたが、これは誤りだった。除去した `Align` は loose 制約下で既に `constraints.biggest` まで広がっており、`SlideTransition` の子のサイズは変更前後で同じである。移動量に変化はなく、`page-transition-animation` の spec delta も不要。

ただし副作用が 1 つある。outgoing ページも領域全面を占める opaque な `GestureDetector` を持つようになり、incoming ページはスライド開始時点で完全に画面外にあるため、**アニメーション中のポインタは全て outgoing ページに当たる**。outgoing には `onSwipe` が配線されていなかったため、連続してページをめくると 2 回目のスワイプが落ちていた（`page-transition-animation` の「Swipe during animation」に反する）。outgoing ページにも `onSwipe` を配線して解消する。ホバー配線の意図（orphan token を残さない）を壊さないため `IgnorePointer` は採らない。

### 決定 5: ヒット領域はページのサイズ変化でも作り直す

当たり判定を広げたことで、文字の描画位置がページ幅に依存するようになった（従来は `Wrap` の原点基準で幅に依存しなかった）。`didUpdateWidget` は segments / baseStyle / columnSpacing しか見ないため、制約だけが変わったリサイズを検知できない。`_rebuildHitRegions` が測定時のページサイズを保持し、`_hitTest` が現在のサイズと異なれば作り直す。

### 決定 6: 選択の anchor はポインタが降りた位置から解決する

`onPanStart` が報告するのは pan が受理された位置で、タッチの slop（36px）は縦書きの 1〜2 文字分に相当する。実測で「'あ' の中心から下へドラッグすると選択が 'いうえ' になる」ことを確認したため、`_onPanDown` でページローカル座標を保持し、そこから anchor を解決する。

これに伴う 2 点も同時に扱う。

- 受理された move には `onPanUpdate` が続かないため、`_onPanStart` で selecting に決まった時点で受理位置まで範囲を広げる。さもないと `down → 1 回の move → up` で押した 1 文字しか選択されない。
- anchor 解決は列間隔ぶん最寄り文字へ吸着させる（`_onTapUp` と同じ規則）。列間の隙間は 8〜24px あり、そこに指が落ちると anchor が解決できずドラッグ全体が無効になり、既存の選択まで消えてしまう。

### 決定 7: スワイプによる選択解除は「見えている選択」を基準に通知する

`onSelectionChanged(null)` は「嘘の通知」ではなく、owner に選択を落としてもらう唯一の手段である（ページ側は owner の `selectionStart`/`selectionEnd` を書き換えられない）。既存仕様はタップもスワイプも *any active* な選択を解除すると定めており、`vertical_text_page_test.dart` の 3 件がその契約を固定している。したがって通知条件は `_effectiveStart`/`_effectiveEnd` 基準とする。

レビューで 3 度「owner 提供の選択がある間は通知するな」と指摘されたが、いずれもこの既存契約と矛盾するため不採用とした。

## Risks / Trade-offs

- **`Stack` / `SlideTransition` のサイズ計算が変わる** → `Stack` の非配置子が全面サイズになるため `Stack` 自体も全面になる。`ClipRect` 内なのではみ出しは従来どおりクリップされる。アニメーション中の見た目はアニメーションテスト（`vertical_text_viewer_animation_test.dart`）で回帰確認する。
- **既存テストがページ矩形のサイズに依存している可能性** → `VerticalTextPage` のレンダーボックスサイズを前提にしたテストがあれば失敗する。実装前に該当テストを洗い出し、意図した変更であることを確認したうえで期待値を更新する。
- **文字ヒット領域の座標ズレ** → `localToGlobal(ancestor:)` 基準なので理論上ズレないが、リグレッションの影響が大きい箇所であるため、既存の選択オフセットテスト（`vertical_selection_offset_test.dart`）とホバーテストを必ず通す。加えて「余白から始めた縦ドラッグで選択が始まらない」ことを新規テストで固定する。
- **残るデッドゾーン** → 外周 16px と下端のページ番号帯（約 24px）は無反応のまま。左側の実害（最大 640px）が解消されれば体感上は十分と判断する。将来必要になれば案 B を追加で検討する。
