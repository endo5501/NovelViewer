## Context

要約ポップアップは二つの表示モードで別々の経路から開かれる。横書きは `ruby_text_builder.dart` が組み立てる `TextSpan` の `onEnter`/`onExit`、縦書きは `vertical_text_page.dart` の `MouseRegion.onHover`/`onExit` である。どちらも `MouseTracker` の産物であり、指では発火しない。iPad では解析そのものは動くのに、結果を読む手段だけが存在しない。

閉じる経路も同様で、`HoverPopupNotifier` の退出は `onPopupExit` (マウスの離脱) と `hideIfShowing` (マークからの離脱、150ms の猶予つき) の二つしかない。どちらも指には来ない。

指で到達する仕組みは、この repository にすでに一つある。`touch-context-menu-trigger` がそれで、`kNoSecondaryButtonPointerKinds` によってポインタ種別で分岐し、マウスの既存の意味を一切奪わずにタッチ専用の経路を足す、という形をとっている。今回もその形に従う。

### 横書きで閉ざされている道

`TextSpan` に `recognizer` を付ける案は成立しない。`SelectableText.rich` の中身は `RenderEditable` であり、そのポインタ処理は次のようになっている (Flutter SDK `packages/flutter/lib/src/rendering/editable.dart:2015)。

```dart
void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
  if (event is PointerDownEvent) {
    if (!ignorePointer) {
      _tap.addPointer(event);
      _longPress.addPointer(event);
    }
  }
}
```

span の recognizer には配っていない。同ファイルのドキュメントコメントは「span に recognizer があれば伝える」と書いているが、実装はそうなっていない。`recognizer` を配るのは `RenderParagraph` の側であり、`SelectableText` はそこを通らない。

`SelectionArea` + `Text.rich` に置き換えれば `recognizer` は効くが、`SelectionArea` の `onSelectionChanged` は選択された文字列しか返さずオフセットを返さない。現在の横書きは `selection.start` から `plainTextOffsetFromDisplayOffset` で平文オフセットを求め、そこから TTS の再生開始位置を決めている。置き換えるとその機能が壊れる。よって採らない。

## Goals / Non-Goals

**Goals:**

- 両表示モードで、指のタップだけで解析済み語句の要約に到達できること。
- 指のタップだけでポップアップを閉じられること。
- マウスの挙動が一切変わらないこと。ホバーで開く経路、150ms の猶予、ポップアップ内の操作、子メニューの生存規則を変更しない。
- 分岐の根拠をポインタ種別に置き、プラットフォーム判定を増やさないこと。タッチスクリーン付きのデスクトップも同じ経路で到達する。
- iPad の縦持ちで、画面右寄りのマークをタップしてもポップアップが画面内に収まること。

**Non-Goals:**

- ポップアップの中身、配置方針、スナップショット操作、再解析ドロップダウンの変更。横書きは従来どおりポインタの右下に出す。
- 長押しへの新しい意味づけ。
- 縦書きのジェスチャ認識器の構成変更。`touch-context-menu-trigger` が記録した「長押し認識器を足さない」という判断をそのまま守る。
- タッチ操作に合わせた別の入れ物 (ボトムシートなど) の導入。入力手段で UI を分岐させない。
- ポップアップ本文のテキスト選択。従来どおり選択不可のままとする。

## Decisions

### 決定1: 縦書きは `_onTapUp` に三段の優先順位を置く

既存の `_onTapUp` はすでにタッチ専用の分岐を持っている。そこへマークの判定を一段挟む。

```
_onTapUp (kNoSecondaryButtonPointerKinds のときのみ)
  │
  ├─ 1. タップ位置が現在の選択範囲の内側     → コンテキストメニュー   [既存]
  ├─ 2. タップ位置がマーク範囲の内側         → 要約ポップアップ       [新規]
  └─ 3. それ以外                             → 選択クリア             [既存]
```

コンテキストメニューを最優先にするのは、読者が範囲を選び終えた直後の操作だからである。マークの上に選択範囲が重なっている場合、読者が意図しているのは自分が今作った選択に対する操作であって、傍線ではない。

ヒットテストは既存のものをそのまま使う。`_hitTest(details.localPosition, snapToNearest: true, maxSnapDistance: widget.columnSpacing)` はすでに 1 の判定で呼ばれており、その結果を 2 でも使い回せる。桁の隙間へのスナップも同じ理由で必要であり、同じ規則が適用される。マーク範囲は `_markedRanges` として手元にある。

**代替案:** マーク判定を選択判定より先に置く。却下した。選択中の語がたまたま解析済みだと、コンテキストメニューへ到達できなくなる。

### 決定2: 横書きは Flutter 自身のヒットテスト結果を借りる

タップ座標から文字位置を自前で計算しない。`SelectableText` は指のタップに対して `onSelectionChanged` を `SelectionChangedCause.tap` で呼び、折りたたまれた選択を報告する。iOS では `selectWordEdge` を経由するため、タップ位置に最も近い語の端へスナップした表示オフセットが届く。

変換に必要な部品はすべて既存である。

| 必要なもの | 使うもの |
|---|---|
| 表示オフセット → 平文オフセット | `plainTextOffsetFromDisplayOffset` (`ruby_text_parser.dart`) |
| 平文オフセット → マーク | `findMarks` の結果。`buildRubyTextSpans` が内部で同じ空間で作っている |
| ポップアップのアンカー座標 | `Listener` が拾うポインタの global 座標 |
| タッチかどうか | `kNoSecondaryButtonPointerKinds` |

`buildRubyTextSpans` は `findMarks(text: _concatenatedBaseText(segments), ...)` でマークを作る。`plainTextOffsetFromDisplayOffset` が返すのも同じ平文空間である。そこで、平文テキストの連結と `findMarks` の呼び出しを共有の関数として切り出し、`buildRubyTextSpans` と `TextContentRenderer` の双方から使う。レンダラ側は既存の `_cachedTextSpan` と同じ条件でマーク一覧をキャッシュする。

**代替案:** 自前の `TextPainter` を同じ幅でレイアウトして `getPositionForOffset` を呼ぶ。却下した。`SelectableText` の内部レイアウトと `strutStyle`、`textScaler`、`locale` まで一致させ続ける必要があり、ずれると行単位でタップがずれる。既存の栞ガター計算が同種の再現に依存しているが、そこは Y 座標の目安であり、ずれても読み取りが壊れるだけで誤った語を開くことはない。

### 決定3: タップの解決はポインタアップ後のマイクロタスクで一度だけ行う

`onSelectionChanged` の中で直接ポップアップを開かない。iOS のタッチ分岐では、同じ位置を再度タップすると選択が変化せず、コールバックが呼ばれないことがある。閉じたあとに同じ語をもう一度タップしても開かない、という穴ができる。

そこで次の形にする。

```
Listener(onPointerUp)              SelectableText.onSelectionChanged
   │ kind がタッチか確認             │ cause == tap のとき
   │ global 座標を控える             │ baseOffset を控える
   │ マイクロタスクを積む            │
   ▼
   マイクロタスクで、控えた最新のオフセットからマークを引く
     見つかった → show(word, position, token)
     見つからない → hide()
```

コールバックが呼ばれた場合は控えた値が最新になり、呼ばれなかった場合は前回の値がそのまま正しい。どちらの場合も同じ一本の経路で解決する。タップ認識器の解決はポインタアップの同期処理の中で完了するため、マイクロタスクはその後に走る。

語端スナップにより、オフセットがマーク範囲の外側へ一つずれることがある。マーク判定はタップ位置と、その一つ手前の位置の両方を見る。

### 決定4: 閉じるのは透過リスナー、閉じるボタンは置かない

ポップアップの下に画面全体を覆うオーバーレイをもう一枚敷き、`HitTestBehavior.translucent` の `Listener` を置く。ポインタダウンを見るだけで何も吸収しないため、下の操作は妨げない。

閉じる条件は三つすべてを満たすときとする。

1. ポインタ種別が `kNoSecondaryButtonPointerKinds` に含まれる。マウスは無視する。
2. 座標がポップアップ本体の矩形の外側にある。ポップアップには `GlobalKey` を持たせ、その `RenderBox` から矩形を求める。
3. ポップアップが所有する子メニュー (再解析ドロップダウン) が開いていない。`HoverPopupNotifier._childMenuOpen` がすでにこの状態を持っている。

子メニューは `showMenu` のモーダルルートであり、自前の `ModalBarrier` がヒットテストを吸収するため通常はここまで届かない。それでも 3 を条件に入れるのは、オーバーレイの積み順に依存した暗黙の前提を残さないためである。

**代替案:** ポップアップに閉じるボタンを常設する。却下した。デスクトップの見た目が変わる。マウスには離脱があり、ボタンは要らない。

**代替案:** タッチで開いた場合だけバリアを敷く。却下した。開き方を状態に持つ必要が生じるが、ポインタ種別で判定すれば同じ結果が状態なしで得られる。

### 決定5: 横書きのスクロールでも閉じる

縦書きは `onHoverHideRequest` でページ送りとドラッグ選択の開始時に閉じている。横書きには繋がっていない。`TextContentRenderer` の `NotificationListener<ScrollNotification>` から、読者の操作に由来するスクロール開始で `hide()` を呼ぶ。

TTS の自動追従スクロール (`_isTtsScrolling`) では閉じない。読者が動かしたわけではないからである。既存のコードがこの区別をすでに `ScrollStartNotification` の `dragDetails` と `_isTtsScrolling` で行っているので、同じ判定を使う。

### 決定6: 横書きのアンカーにも画面内クランプを通す

`computePopupAnchor` の横書き分岐は現在ポインタの右下へ一定量ずらすだけで、めくり返しもクランプもしない。縦書き分岐にはすでに両方ある。同じ処理を横書きにも適用する。基本方針である「ポインタの右下」は変えない。画面右端または下端を越える場合にだけ、めくり返しとクランプが働く。

デスクトップでは窓が広いためこの分岐に入ることは稀であり、挙動は実質変わらない。

## Risks / Trade-offs

**[語端スナップによるオフセットのずれ] → 対策:** iOS のタッチタップは `selectWordEdge` を通るため、報告されるオフセットが語の端に寄る。日本語では語境界の判定が期待と違うことがある。タップ位置とその一つ手前の両方でマークを引く。境界上のマークを両方向から開けることをウィジェットテストで確かめる。

**[マイクロタスクのタイミングが認識器の解決より先になる] → 対策:** タップ認識器が二度タップの判定で遅延を持つ場合、マイクロタスクのほうが先に走る可能性がある。ウィジェットテストでタップから `show` までを検証し、先に走ってしまう場合はポストフレームコールバックへ切り替える。どちらも解決の一本道は変わらない。

**[透過リスナーがヒットテストを通さない] → 対策:** `HitTestBehavior.translucent` は自分をヒットテスト結果に加えつつ、背後のウィジェットへも到達させる。オーバーレイは `Stack` なので、同じ `Stack` の下層にあるルートの中身まで届く。届かない場合、ポップアップを開いたまま文字がタップできなくなる。オーバーレイの下のボタンが押せることをウィジェットテストで確かめる。

**[縦書きでマークのタップが選択クリアを奪う] → 対策:** 解析済み語句の上をタップしたとき、これまでは選択が消えていたが今後は消えない。読者が選択を消すつもりでたまたまマークの上をタップした場合、消えずにポップアップが出る。マークのないところをタップすれば従来どおり消えるため、逃げ道は常にある。この挙動の変更を `touch-context-menu-trigger` の要件として明示的に記録する。

**[横書きでマークのタップがカーソル位置の設定を奪わない] → 対策:** 奪わない。`onSelectionChanged` を観測するだけで、`SelectableText` のタップ処理には介入しない。折りたたみ選択はこれまでどおり設定される。

**[ポップアップ矩形の判定が最初のフレームで得られない] → 対策:** `GlobalKey` の `RenderBox` は、ポップアップが最初にレイアウトされるまで取得できない。取得できない間は「外側」と判定せず、閉じないほうへ倒す。開いた瞬間に自分自身のポインタダウンで閉じることを避けるためでもある。
