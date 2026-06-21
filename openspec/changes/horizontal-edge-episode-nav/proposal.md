## Why

横書き表示モードでは、本文の末尾／先頭に達してカーソルキーやマウスホイールを操作しても次話／前話へ進めず、左下に常時オーバーレイ表示される「← 前話」「次話 →」ボタンを押すか、ファイルブラウザで選び直す必要がある。このボタンは本文に重なって読みづらく、また縦書きモード（末尾でのページ送り操作がそのまま話送りになる）との操作体系も食い違っている。横書きでもキー／ホイールだけで境界から話送りでき、本文に被るボタンを撤去したい。

## What Changes

- 横書きモードに **境界エピソードナビゲーション** を追加する。本文の末尾／先頭に達した状態でさらに同方向へカーソルキー（↓／↑）またはマウスホイールを操作すると、確認なしで即座に次話／前話へ遷移する。
  - 末尾で「次ページ」操作（既定の↓キー）または下方向ホイール → 次話を `fromStart`（冒頭から）で開く。
  - 先頭で「前ページ」操作（既定の↑キー）または上方向ホイール → 前話を `fromEnd`（末尾から）で開く。
  - 当該方向に隣接ファイルが存在しない場合は no-op（何も起きない）。
- **暴発防止クールダウン** を設ける。話送り直後の一定時間は境界ナビゲーションを無視し、カーソルキー長押しのキーリピートやホイール連打で複数話を一気に飛ばしてしまうのを防ぐ。
- **BREAKING（UI 挙動）**: 横書きモードの常時オーバーレイ「← 前話」「次話 →」ボタン（`EpisodeNavigationButtons`）を撤去する。境界での話送りはキー／ホイール操作に一本化する。
- ファイル内のページスクロール（1 ビューポート単位のアニメーションスクロール）の既存挙動は変更しない。前話遷移時に新ファイルの末尾から開始する初期スクロール挙動（`fromEnd`）も維持する。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `text-viewer`: 横書きモードに境界エピソードナビゲーション要件（キー／ホイールによる境界での話送り＋暴発防止クールダウン）を追加し、常時表示の次話／前話ボタン要件を削除する。前話遷移時の初期スクロール位置要件は、トリガをボタン押下から境界ナビゲーションに記述更新する（スクロール挙動自体は不変）。

## Impact

- コード:
  - `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart` — 矢印キー境界検知（`_pageScroll` のクランプ地点をフック）、`Listener.onPointerSignal` によるホイール傍受（エッジフラグで条件分岐）、クールダウン状態の追加、`EpisodeNavigationButtons` の描画削除。
  - `lib/features/text_viewer/presentation/widgets/episode_navigation_buttons.dart` — 横書きビューアからの参照が無くなり不要化（削除または未使用化）。
- 再利用（変更なし）: `episode-navigation` capability の `adjacentFilesProvider` / `episodeNavigationControllerProvider`（`navigateToNext` / `navigateToPrevious`）をそのまま利用する。境界検知に用いるエッジフラグ（`_atScrollTop` / `_atScrollBottom`）も既存実装を流用する。
- テスト: `test/features/text_viewer/presentation/horizontal_page_scroll_test.dart` 周辺に、境界での話送り・クールダウン・短い（1 画面）エピソードでの連続遷移ガードのテストを追加。ボタンに関する既存テストは削除または境界ナビ用に置換する。
