## Context

iPad 対応の 4 番目の変更。A（`ios-build-bootstrap`）でビルドを通し、B（`platform-capabilities`）で非対応機能を隠し、C（`ipad-adaptive-shell`）で狭い画面のレイアウトを整えた。残っていたのが「入力手段の穴」で、これが本変更にあたる。

調査時点の事実（すべて `lib` 全体の grep とウィジェットツリーの確認による）:

1. `onSecondaryTapUp` は 4 箇所 — `file_browser_panel.dart:334`、`bookmark_list_panel.dart:58`、`vertical_text_page.dart:433`、`llm_summary_history_panel.dart`。最後の 1 つは iPad では解析履歴タブごと非表示なので対象外。
2. `lib` に `onLongPress` 系のハンドラは**ゼロ**。長押しはアプリのどこでも意味を持っていない。
3. `onHover` は `vertical_text_page.dart` の 1 箇所のみ（解析済み語のポップアップ）。本変更の対象外。
4. 横書きモードは `SelectableText.rich` が `contextMenuBuilder` 経由で Flutter 標準の長押しツールバーを提供するため、既にタッチで動く。
5. iPad では `ttsSupported` も `llmSummarySupported` も false なので、縦書き選択メニューの項目は「コピー」1 つだけになる（`buildVerticalContextMenuItems` の既存のゲート）。
6. 選択テキストによる検索は AppBar の 🔍 から既に到達可能（`home_screen.dart:206 _onSearchShortcut`）。本変更で失われている機能は純粋に「コピー」だけ。

制約:

- C で確立した方針を維持する。`dart:io` の `Platform` 読み取りは `platform_capabilities_provider.dart` の 1 箇所のみ。分岐が必要なら、テストから差し替えられる値（プロバイダ、幅、ポインタ種別）を使う。
- 縦書きビューアの `GestureDetector` は pan で「範囲選択」と「ページ送り」を両方さばいている（`_tryDecideGestureMode`）。ここの調停は既存テストで守られており、壊してはならない。

## Goals / Non-Goals

**Goals:**

- iPad の指だけの操作で、ファイルブラウザ・ブックマーク一覧・縦書き選択の 3 つのコンテキストメニューすべてに到達できるようにする。
- メニューの項目・並び・動作は右クリック時と完全に同一にする（別経路を新設しない）。
- デスクトップの既存の操作感を変えない。
- 実機を必要とせず、ウィジェットテストで検証できる形にする。

**Non-Goals:**

- 解析済み語のホバーポップアップをタッチで開けるようにすること。LLM 機能全体の検討時に扱う。
- iOS ネイティブ相当の選択 UI（選択ハンドル、`AdaptiveTextSelectionToolbar`、長押しでの単語選択）を作ること。
- 横書きモードへの変更。
- メニューの内容そのものの見直し。

## Decisions

### D1. リスト項目は長押し、縦書きは選択範囲内のタップ — トリガを surface ごとに変える

同じ「長押し」で統一する方が一見きれいだが、縦書きビューアだけは事情が違う。

`long_press.dart` と `constants.dart` を読んで確認した数値:

```
kLongPressTimeout        = 500ms
preAcceptSlopTolerance   = kTouchSlop = 18px   (LongPressGestureRecognizer の既定)
computePanSlop(touch)    = kPanSlop  = 36px   (PanGestureRecognizer が arena で勝つ距離)
```

`long_press.dart:640 didExceedDeadline` は `resolve(GestureDisposition.accepted)` を呼ぶ。つまり 500ms 静止した時点で長押しが arena を強制的に取り、pan は蹴られる。結果:

```
指を置いてすぐ動かす    → 18px で長押し脱落、36px で pan 勝ち  … 現状どおり
指を置いたまま 500ms    → 長押しが accept、pan は onPanCancel   … 【範囲選択が始まらない】
```

iPad で本文に指を置いてから動かすのはごく普通の操作なので、これは稀な事故ではなく常態になる。回避するには「選択が無い状態の長押しは選択を開始し、`onLongPressMoveUpdate` で伸ばす」まで実装する必要があり、それは Non-Goals に挙げた iOS ネイティブ相当の選択 UI そのものになる。

対して「選択範囲の内側をタップ」は recognizer を 1 つも増やさない。`onTap` を `onTapUp` に差し替えるだけで、arena の構成は完全に不変。既存のドラッグ選択・スワイプページ送りのテストは 1 行も変えずに通る。iOS でも「選択をタップするとツールバーが再表示される」のは標準の作法であり、作法上も無理がない。

リスト項目側には pan ハンドラが無いので、この問題は起きない。長押しがそのまま使える。

**代替案:** 3 箇所すべて長押しに統一。→ 上記の理由で却下。
**代替案:** 縦書きは選択ドラッグを離した瞬間に自動でメニューを出す。→ arena には触らずに済むが、選択のたびにメニューが被さる。選択語検索（AppBar の 🔍）を使いたいだけのときに毎回閉じる手間が発生するため却下。

### D2. リスト項目の長押しはポインタ種別で分岐しない。縦書きのタップは分岐する

判断の線引きは「既存の意味を奪うかどうか」。

- 長押しはアプリのどこでも何の意味も持っていない（事実 2）。
- タップは縦書きビューアで「選択解除」という既存の意味を持っている。

**レビュー後の訂正（D2b）:** この線引きから「長押しは分岐不要」と結論したが、これは誤りだった。長押し自体に意味が無くても、**マウスの左ボタンを 500ms 以上保持して離す操作**——遅い左クリック——は既存の意味を持つ。長押しレコグナイザが期限で arena を取ると `ListTile.onTap` が蹴られ、フォルダが開かずメニューが出る。実測で確認済み。

結局どちらの入口も「既存の意味を奪わない」という同じ基準で判断すべきで、基準は「そのポインタが副ボタンを持つか」に一本化される。マウスは副ボタンを持つのでタッチ入口を必要とせず、与えれば既存の操作を失うだけである。したがって 4 箇所すべてを `kNoSecondaryButtonPointerKinds`（touch / stylus / invertedStylus）に限定した。

リスト側は `GestureDetector` を入れ子にして内側に `supportedDevices` を指定する。1 つの `GestureDetector` に指定すると `onSecondaryTapUp` まで制限されて右クリックが壊れるため。

`PointerDeviceKind` を使うのは C で `MediaQuery` の幅を使ったのと同じ発想で、`Platform` を増やさずに済む。トラックパッドを接続した iPad では従来どおり右クリックが効き、タッチスクリーン付きの Windows 機では指でメニューが開く — プラットフォームではなく実際の入力デバイスに追従する。

**代替案（当初案）:** 縦書きも分岐なし。→ デスクトップで選択の途中をクリックして解除する操作が効かなくなる。範囲の外をクリックすれば解除できるので致命的ではないが、主対象プラットフォームの既存挙動を変える側の賭けなので採らない。

**レビュー後の訂正（D2a）:** 当初 `kind == PointerDeviceKind.touch` の 1 種別だけで判定していたが、これでは Apple Pencil（`stylus`）が漏れる。Pencil は iPad の一級のポインタで副ボタンも持たないため、本変更が塞ごうとしている穴そのものが Pencil 利用者には残っていた。判定基準は「touch であること」ではなく「副ボタンを持たないポインタであること」なので、`touch` / `stylus` / `invertedStylus` の集合に改めた。`unknown` は除外している——実マウスを `unknown` として報告するプラットフォームがあった場合に選択解除が黙って失われる方が害が大きく、そこでは副ボタンでメニューに到達できるため。

### D5a. 列間ギャップのタップは距離上限つきで吸着させる

レビューで判明した実害。列と列の間には `columnSpacing`（既定 8pt）の余白があり何も描画されていない。`_hitTest` を既定の `snapToNearest: false` で呼ぶと、そこへのタップは `null` を返して「選択範囲外」と判定され、**選択が破棄される**。フォントサイズ 14 では列のピッチが 22pt に対しギャップが 8pt なので、本文領域の横方向の 3 割強が「タップすると選択が消える帯」になっていた。指で文字を狙えば十分に起こりうる。

単純に `snapToNearest: true` にするのは誤り。既存の吸着は**距離無制限**で、最寄りの領域を必ず返す（`vertical_text_layout.dart:79-102`）。余白の遠いタップまで選択中の文字に吸着し、「範囲外をタップして解除する」動作が壊れる。

そこで `hitTestCharIndexFromRegions` に `maxSnapDistance` を追加し、上限を `widget.columnSpacing` とした。ギャップ中央は両側の列から `columnSpacing / 2` の距離なので確実に届き、余白のタップは従来どおり `null` になる。ドラッグ選択が同じ理由で（ただし上限なしで）吸着しているのと同じ発想である。

### D3. `Tooltip` の `triggerMode` を `manual` にする

`file_browser_panel.dart:318` のタイトルは `Tooltip` で包まれている。Flutter のソースを読んで確認した挙動:

```
raw_tooltip.dart:632  _handlePointerDown
raw_tooltip.dart:643    case TooltipTriggerMode.longPress:            ← tooltip.dart:396 の既定値
raw_tooltip.dart:644      LongPressGestureRecognizer(
                            supportedDevices: {touch, stylus, trackpad, invertedStylus, unknown})
                          ..addPointer(event)
```

`Tooltip` は指で触れた瞬間に自前の長押し recognizer を arena に登録する。しかも `Tooltip` は我々の `GestureDetector` より内側にあるため、hit-test の配送順（内側 → 外側）で先に `addPointer` され、同じ 500ms のタイマーが先に生成され、先に accept する。タイトルはタイルの面積のほとんどを占めるので、放置すると「アイコンの上なら出るが題名の上では出ない」という最悪の当たり判定になる。

`triggerMode: TooltipTriggerMode.manual` はこの `_handlePointerDown` を no-op にするだけで、ホバー経路（`MouseRegion` の `_handleMouseEnter`）は `triggerMode` を参照しない。したがってデスクトップのホバーツールチップは完全に無傷のまま、タッチの長押しだけが我々に渡る。

**代替案:** タイトル以外の領域の長押しで我慢する。→ 当たり判定が実質破綻するため却下。
**代替案:** `Tooltip` を外す。→ `file-browser` の既存要件「フルネームのホバーツールチップ」を壊すため却下。

このアリーナ順の推論はソース読みによるものなので、**実装時には「タイトル文字の上を長押ししてメニューが出る」ことを判別力のあるテストとして先に書き、`triggerMode` を戻すと落ちることを確認する**。

### D4. メニュー本体は共有し、新設しない

3 箇所とも既存の `_showContextMenu` / `_onSecondaryTapUp` の本体をそのまま呼ぶ。項目の組み立て、`showMenu` の呼び出し、選択結果のディスパッチには手を入れない。

- 位置は `LongPressStartDetails.globalPosition` / `TapUpDetails.globalPosition` を使う。どちらも既存の `TapUpDetails.globalPosition` と同じ座標系。
- 縦書き側は `_onSecondaryTapUp` の本体を `_openContextMenuAt(Offset globalPosition)` に切り出して 2 つの入口から呼ぶ。切り出しは純粋なリファクタで、右クリック経路の挙動は変わらない。

これにより「iPad だけ項目が違う」「iPad だけ動作が違う」という分岐が一切生まれない。iPad で項目が 1 つになるのは `buildVerticalContextMenuItems` の既存のケイパビリティゲートの結果であり、本変更は関与しない。

### D5. 縦書きのタップ判定は既存部品の組み替えで済ませる

`_isInSelection(int index)` は選択ハイライトの描画に既に使われており、`_hitTest(Offset localPosition)` も既にある。`_effectiveStart` / `_effectiveEnd` は外部から渡された選択（`widget.selectionStart`）と内部選択の両方を吸収するので、どちらの経路で作られた選択でも同じように判定できる。

```
onTapUp(details):
  kind == touch かつ _isInSelection(_hitTest(details.localPosition)) なら
      _openContextMenuAt(details.globalPosition)      … 選択は維持する
  そうでなければ
      _clearInternalSelection() ＋ onSelectionChanged(null)   … 従来どおり
```

`onTap` は使わず `onTapUp` 一本にする。両方を登録すると同一のタップで 2 回発火するため。

### D6. 選択はメニューを開いても閉じても維持する

右クリック経路が現在そうなっているのに合わせる。コピー後に選択が消えないので、続けて AppBar の 🔍 で選択語検索に回せる。

### D7. 「更新」の代替経路は作らない

ファイルブラウザの長押しが通れば「更新」に到達できるので、AppBar への昇格などは行わない。iPad だけ導線が違う状態を作らない方が良い。

## Risks / Trade-offs

- **[D3 のアリーナ順の推論が外れている]** → タイトル文字上の長押しを判別力のあるテストとして先に書き、`triggerMode` を戻すと落ちることを確認する。ソース読みだけで確定させない。
- **[長押しがスクロールと競合する]** ブックマーク一覧・ファイル一覧はスクロール可能なリストの中にある。→ 長押しとスクロールの調停は Material の `ListTile(onLongPress:)` が日常的に行っていることで、`preAcceptSlopTolerance` により指が動けば長押しは落ちる。既存のスクロールテストが通ることで確認する。
- **[`maxSnapDistance` の値が状況に合わない]** 上限を `columnSpacing` に等しく取っているため、ギャップは確実に覆えるが、列の外側にも同じ距離だけはみ出す。→ 列のピッチ（フォントサイズ + `columnSpacing`）より十分小さいので、隣の列を飛び越えることはない。余白のタップが解除として働くことはテストで固定した。
- **[縦書きで選択範囲内をタップして解除したい人がいる]** → 範囲の外をタップすれば従来どおり解除できる。また指のみの分岐なので、マウス操作は一切変わらない。
- **[長押しメニューが Drawer の中で開く]** 狭い画面ではファイル一覧・ブックマーク一覧は `Drawer` の中にある。→ `showMenu` は `Navigator` のオーバーレイに出るため Drawer の上に重なる。フォルダタイルの長押しはファイル選択ではないので、C で入れた `fileOpenRequestProvider` による Drawer 自動クローズは発火しない。ウィジェットテストで狭いレイアウトでも確認する。

## Open Questions

なし。探索段階で 5 点すべて決着済み（スコープ = ①②③、縦書きのトリガ = 選択範囲内タップ、リストの長押し = 分岐なし、縦書きのタップ = タッチのみ、ホバーポップアップ = 対象外）。
