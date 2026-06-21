## Context

横書きビューア（`TextContentRenderer`）は `SingleChildScrollView` 上に本文を連続スクロールで表示する。カーソルキー（↓／↑）は viewer 限定の `Shortcuts`/`Actions` で `NextPageIntent`/`PrevPageIntent` に束ねられ、`_pageScroll(±1)` が 1 ビューポート分のアニメーションスクロールを行う（`text_content_renderer.dart`）。マウスホイールは `SingleChildScrollView` がネイティブに処理する。スクロールが先頭／末尾にあるかは既に `_atScrollTop` / `_atScrollBottom` フラグで追跡しており（スクロールリスナで更新）、現状はこのフラグで左下オーバーレイの `EpisodeNavigationButtons` の表示可否を切り替えている。

縦書きビューア（`VerticalTextViewer`）は自前ページャで、末尾／先頭ページからさらにページ送り操作をすると `_handleBoundaryNavigation` が走り、2 段階確認プロンプトと 300ms クールダウンを経て `episodeNavigationControllerProvider` の `navigateToNext`/`navigateToPrevious` を呼ぶ。横書きにはこの境界遷移が無く、被るボタンが唯一のキー操作外導線になっている。

隣接ファイル導出（`adjacentFilesProvider`）と遷移ヘルパー（`episodeNavigationControllerProvider`）は `episode-navigation` capability が提供しており、本変更ではこれらを変更せずそのまま利用する。

## Goals / Non-Goals

**Goals:**

- 横書きモードで、本文の末尾／先頭に達した状態からカーソルキー（↓／↑）またはマウスホイールを同方向へ操作するだけで、次話／前話へ遷移できるようにする。
- キーリピート／ホイール連打による複数話の暴発を、暴発防止クールダウンで抑止する。
- 本文に被る常時オーバーレイの次話／前話ボタンを撤去する。
- ファイル内ページスクロールおよび前話遷移時の末尾開始スクロール（`fromEnd`）の既存挙動を壊さない。

**Non-Goals:**

- 縦書きモードの挙動変更（2 段階確認方式は維持）。
- 確認プロンプトや境界ヒント行の追加（探索フェーズで「確認なし即移動・ヒント不要」と合意済み。話送り時はファイルブラウザの選択ファイルが連動して切り替わるため気づける）。
- `episode-navigation` capability（provider 層）の変更。
- スワイプ／タッチ操作への対応（横書きはマウス＋キーボード前提）。

## Decisions

### 決定 1: ホイール境界検知は `Listener.onPointerSignal` をエッジフラグで条件分岐する

`SingleChildScrollView` を `Listener` でラップし、`onPointerSignal` で `PointerScrollEvent` を受ける。`_atScrollBottom` かつ下方向スクロールなら次話、`_atScrollTop` かつ上方向スクロールなら前話へ遷移する。境界以外では何もせず、ネイティブのスクロール処理に委ねる。これは縦書き（`VerticalTextViewer._handlePointerSignal`）が既に採用している方式と同型。

**代替案（不採用）: `NotificationListener<OverscrollNotification>`。** Flutter のスクロール位置はマウスホイール時に `ScrollPosition.pointerScroll` 内で目標値を可動範囲へクランプし、`targetPixels == pixels`（既に境界）のときは `setPixels` を呼ばず、overscroll も scroll-end も **一切通知しない**。したがって境界での「さらにホイール」を overscroll 通知では検知できない。`onPointerSignal` の自前傍受が確実。

**取り合いの懸念について:** 境界では `Scrollable` 側の `pointerScroll` がいずれにせよ no-op になるため、外側の `Listener` で遷移処理を行ってもスクロール側と競合しない。イベントを consume する必要もない。

### 決定 2: カーソルキー境界検知は `_pageScroll` のクランプ地点をフックする

既存の `_pageScroll(direction)` は目標オフセットを可動範囲へ clamp し、`target == position.pixels`（これ以上動けない＝境界）のとき早期 return している。この地点が「境界に達した」シグナルそのものなので、ここで return する代わりに境界遷移へルーティングする。縦書きの `_changePage` がページ index のクランプで同じ判定をしているのと対応する。

### 決定 3: 暴発防止はクールダウン・フラグ 1 つで両入力を一律ガードする

話送りを実行したら一定時間（縦書きの `_kFileNavigationConfirmCooldown` と同オーダーの ~300〜400ms）を Timer で計測し、その間の境界ナビゲーション要求をすべて無視する。これによりカーソルキー長押しのキーリピート（`SingleActivator` は既定で repeat を通す）も、ホイール 1 ジェスチャが生む多数の離散イベントも、同じ 1 経路でガードできる。KeyRepeat を個別に判定する必要はない。

**代替案（不採用）: `SingleActivator(includeRepeats: false)`。** これはファイル内ページスクロールの長押し連続送りまで無効化してしまうため、境界遷移だけを抑えたい目的に合わない。クールダウンは境界遷移の発火点のみをガードするので、ファイル内スクロールの体験には影響しない。

### 決定 4: 常時オーバーレイのボタンを撤去する

`EpisodeNavigationButtons` を横書きビューアの `Stack` から外す。境界の話送りはキー／ホイールに一本化される。これにより本文との重なり（読みづらさ）が解消する。ウィジェット定義ファイル自体は他に参照が無ければ削除する。

### 決定 5: 既存のエッジフラグと遷移ヘルパーを再利用する

境界判定は既存の `_atScrollTop` / `_atScrollBottom` をそのまま使う。遷移は `episodeNavigationControllerProvider` の `navigateToNext`（`fromStart`）／`navigateToPrevious`（`fromEnd`）を呼ぶ。隣接ファイルの有無は `adjacentFilesProvider` で確認し、無ければ no-op。前話遷移後の末尾開始スクロールは既存の `_jumpToEndPending`（`fromEnd` intent 消費）経路がそのまま機能する。

## Risks / Trade-offs

- **[短い（1 画面）エピソードでの連続暴走]** 遷移先が 1 画面に収まると `_atScrollTop && _atScrollBottom` が同時に立ち、クールダウン明けの次操作で即・さらに話送りできてしまう。→ クールダウンで 1 操作あたり最大 1 遷移に制限し、tasks に「短いエピソードでの連続遷移はクールダウンで 1 話ずつに制限される」テストを含める。

- **[ボタン撤去による発見性低下]** 明示ボタンが無くなる。→ 話送り時にファイルブラウザの選択ファイルが連動して切り替わるため視覚フィードバックは残る（探索フェーズで合意）。ヒント行は追加しない。

- **[ホイール境界検知のプラットフォーム差]** `onPointerSignal` ＋エッジフラグ方式は縦書きで実績がありデスクトップで決定論的に動くが、`_atScrollBottom` の更新タイミング（スクロール確定後のリスナ反映）に依存する。→ 「末尾に着地するティック」と「境界を越えるティック」は自然に分かれる（着地でフラグが立ち、次ティックで遷移）。tasks にホイール境界遷移のウィジェットテストを含めて回帰を防ぐ。

- **[TTS 自動スクロールとの干渉]** TTS 再生中のオートスクロール（`_isTtsScrolling`）が末尾付近でエッジフラグを立てる可能性。→ 境界遷移はユーザ入力（キー／ホイール）起点に限定し、TTS のオートスクロール経路からは発火させない。既存の「ユーザ操作で TTS 停止」要件との整合も確認する。
