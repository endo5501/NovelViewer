# Design

## Context

- 縦書きの 1 ページは `VerticalTextPage` が描画する。ページ全体を 1 つの `GestureDetector` が覆い、次のイベントを受け取っている。
  - `onPanDown` / `onPanStart` / `onPanUpdate` / `onPanEnd`: スワイプによるページ送りとドラッグによる選択
  - `onTapUp`: タップ
  - `onSecondaryTapUp`: 右クリック
- `_onTapUp` は、タッチとスタイラスによるタップを「選択範囲内 → マーク → 選択解除」の順に解釈している（`touch-context-menu-trigger`、`llm-summary-hover-popup`）。マウスのタップは常に選択解除になる。
- Drawer の開閉は `HomeScreen` の `_scaffoldKey` だけが行っている。ビューアの内側から `HomeScreen` へ「何かしてほしい」と伝えるときは、カウンタ型の `Notifier` を使う。既存の例は `fileOpenRequestProvider` と `ttsToggleRequestProvider` で、`HomeScreen` はこれらを `ref.listen` で購読している。
- 要約ポップアップの外側を押すと、ポップアップを閉じるための透過 `Listener` がそのイベントを受ける。このイベントは消費されないので、下にあるビューアにもタップとして届く。

## Goals / Non-Goals

**Goals:**

- 既存のシングルタップの反応時間と、ジェスチャーアリーナの構成（どの認識器が参加しているか）を一切変えない。
- 判定ロジックを `VerticalTextPage` の中に閉じ込め、フェイククロック上のウィジェットテストで検証できるようにする。

**Non-Goals:**

- 横書きモードへの対応。
- 左右 1/3 のタップでページを送る機能（範囲を空けておくだけ）。
- ダブルタップで Drawer を閉じること。

## Decisions

### 1. `onDoubleTap` を使わず、`onTapUp` の中で直前のタップを覚えて判定する

`GestureDetector` に `onDoubleTap` を加えると、`DoubleTapGestureRecognizer` がアリーナに参加する。そうなるとシングルタップは `kDoubleTapTimeout`（約 300ms）の間確定しなくなり、選択メニュー、要約ポップアップ、選択解除のすべてが遅れる。

採用する方法では、`_onTapUp` が既存の処理をそのまま実行し、最後の「何もない場所へのタップ」の分岐に到達したときだけ判定を行う。

```
_onTapUp(details)
  タッチ/スタイラス かつ 選択範囲内  -> メニュー                 （記録を破棄）
  タッチ/スタイラス かつ マーク上    -> ポップアップ             （記録を破棄）
  それ以外:
    選択があった                     -> 解除                     （記録を破棄）
    選択がなかった:
      タッチ/スタイラス かつ 中央 1/3 -> 記録があり、条件を満たす -> onCenterDoubleTap()、記録を破棄
                                         記録がない              -> 今回のタップを記録
      それ以外                                                    -> 記録を破棄
    （選択がなかった場合も、既存の onSelectionChanged(null) 通知はそのまま行う）
```

検討した他の案:

- `onDoubleTap` を追加する案。シングルタップが遅れるため却下した。
- 外側に `Listener` を置いてポインタイベントから独自に判定する案。この方法だと「選択もマークもない場所へのタップ」という条件を `_onTapUp` の外で再計算することになり、ヒットテストが二重になるため却下した。

### 2. 時間の判定は `Timer` で行う

1 回目のタップを記録するときに `Timer(kDoubleTapTimeout, ...)` を起動し、時間切れになったら記録を破棄する。`DateTime.now()` や `Stopwatch` はウィジェットテストのフェイククロックに従わないが、`Timer` は `tester.pump(duration)` で進められるので、「間隔内」と「間隔超過」の両方を確実にテストできる。`dispose` で `Timer` を止める。

距離の判定には `kDoubleTapSlop` を使い、1 回目と 2 回目の `globalPosition` の距離がこれ以下であることを条件とする。どちらの値も Flutter の定数をそのまま使い、アプリ独自の値は持たない。

### 3. 中央ゾーンの判定は、`GestureDetector` 自身の大きさを基準にする

`GestureDetector` は、余白を含めてページ領域全体を覆っている（`vertical-text-display` の "Text margin lives inside the gesture area"）。そのため `details.localPosition.dx` を、このウィジェット自身の `RenderBox` の幅と比べる。条件は `width / 3 <= dx < width * 2 / 3` とする。画面全体の幅を使わないのは、ワイドレイアウトで右カラムが表示されているとき、中央の位置がずれるからである。

### 4. 記録を破棄するタイミング

次のときに記録を破棄する。

- `onPanStart` が呼ばれたとき（スワイプやドラッグ選択が始まった）
- Timer が時間切れになったとき
- 中央ゾーン以外への「何もない場所へのタップ」があったとき
- 何か意味を持つタップ（メニュー、ポップアップ、選択解除）があったとき
- ダブルタップが成立したとき

`onPanDown` では破棄しない。`onPanDown` はタップのときにも呼ばれるので、そこで破棄すると 2 回目のタップの時点で記録がもう残っていない。

### 5. `VerticalTextPage` から `HomeScreen` への伝え方

経路は次のとおり。

- `VerticalTextPage` にコールバック `onCenterDoubleTap`（`VoidCallback?`）を追加する。
- `VerticalTextViewer` は、表示中のページ（incoming page）にだけこのコールバックを渡す。スライドアニメーション中の outgoing page には渡さない。
- `TextContentRenderer` はこのコールバックで `fileBrowserOpenRequestProvider.notifier.request()` を呼ぶ。
- `HomeScreen` はこのプロバイダを `ref.listen` し、Drawer が閉じていれば `openDrawer()` を呼ぶ。

プロバイダは `file_browser_providers.dart` に、`FileOpenRequestNotifier` と同じ形（`int` のカウンタ）で追加する。「開く」要求にするので、トグルの `_toggleFileBrowser` は使わない。すでに開いている場合は何もしない。

`onDrawerChanged` によって `_startupDrawerSettled = true` になるので、読者自身がダブルタップで Drawer を開いた後に起動時の自動オープンが重ねて走ることはない。これは既存の仕組みがそのまま働く。

検討した他の案: `Scaffold.of(context).openDrawer()` をビューアから直接呼ぶ案。Drawer の所有者は `HomeScreen` であり、ビューアを単体テストするときに Scaffold が必要になってしまうため却下した。

### 6. 要約ポップアップが開いている状態からのダブルタップ

ポップアップを閉じる `Listener` はイベントを消費しないので、何もない場所をタップすると、ポップアップが閉じると同時にビューアも「何もない場所へのタップ」を受け取る。このタップを 1 回目として数えることを許す。ダブルタップすれば、ポップアップが閉じて Drawer が開く。どちらも「本文から離れる」操作なので、読者の意図と矛盾しない。これを避けるにはページ側がポップアップの表示状態を知る必要があり、得られる効果に対して結合が大きすぎる。

## Risks / Trade-offs

- [ページ送りの直後に中央をタップすると、記録が残っているように見える] → ページ送りは必ず `onPanStart` を経由するので、記録は破棄される。矢印キーやホイールでページを送った場合は、`segments` が変わったときに `didUpdateWidget` で記録を破棄する。
- [Drawer が開くアニメーション中に 3 回目のタップが届く] → ダブルタップが成立した時点で記録を破棄しているので、3 回目は新しい 1 回目として扱われる。Drawer のスクリムが表示された後は、タップがビューアに届かない。
- [文字の上を中央でダブルタップしても Drawer が開く] → 縦書きには単語選択のダブルタップがないので、失われる操作はない。マーク上のタップは除外している。
- [プロバイダのカウンタが 0 のまま listen されている間に要求が来る] → `ref.listen` は変化だけを受け取る。カウンタは必ず増えるので取りこぼしはない。

## Migration Plan

永続化されるデータや設定はないので、移行作業は不要。元に戻すときはこの変更を revert すればよい。

アーカイブ時には `openspec/specs/adaptive-shell-layout/spec.md` の Purpose 節にある "Both drawers open only from the app bar or a shortcut" を、中央ダブルタップを含む記述に書き換える。delta spec では Purpose を変更できないため、この作業は tasks に含める。
