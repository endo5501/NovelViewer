## Why

`lib/features/text_viewer/presentation/vertical_text_viewer.dart` の `build()` 内 `LayoutBuilder.builder` は、レイアウト結果から条件を読み取って post-frame `setState` を撒く「5 つの副作用スケジューラ + 6 つの build 中フィールド変異」が絡み合った塊になっている（TECH_DEBT_AUDIT F156）。最高チャーン（31 コミット/6 ヶ月）のロジックが最もテスト困難な場所に集中し、`_scheduledTargetPage` 等のガードは再入バグの後追いパッチになっている。とりわけ build 中にワンショットフラグ（`_jumpToLastPagePending`、`_pendingTtsOffset`）を書き換える設計は、build が複数回走ると効果が二重適用/消失しうる潜在バグ面である。

ページネーション計算自体は F115/F116/F117 のメモ化で既に純粋層（`_heavyPagination` / `_HeavyPagination` / `_PaginationResult`）へ抽出済みのため、本変更は残る「副作用オーケストレーション」の分離だけを対象とする。

## What Changes

- 「決定（どの効果を起こすか）」を純関数 `resolveViewerEffects(snapshot)` へ抽出する。入力は不変スナップショット（pages 数 / targetPage / charOffsetPerPage / firstLinePerPage / 現在ページ / scheduledTargetPage / jumpToLastPagePending / pendingTtsOffset / lastReportedLine / constraints 変化フラグ）、出力はコマンド値 `ViewerEffects`（即時ジャンプ / アニメ付きジャンプ(TTS) / 行レポート / アニメ停止 / hover 非表示 / 消費すべきワンショットフラグ）。
- `build()` 内 `LayoutBuilder.builder` を「決定を委譲し、効果適用だけを担う薄い層」へ縮退させる。即時効果（アニメ停止）を適用し、残りのジャンプ系は単一の post-frame 適用箇所に集約する。
- ワンショットフラグの消費（クリア）を build 中の散発変異から、`ViewerEffects` 経由の一箇所適用へ移す。
- **振る舞いは不変**（behavior-preserving refactor）。ユーザから見える挙動・ページ遷移・TTS 追従・初期ページ決定・行レポートは変えない。既存 14 本の widget テスト（initial_page / animation / tts_auto_page / pagination / swipe / wheel / memoization 等）を回帰ガードとする。
- 観測可能な契約として「ワンショットページ効果（ターゲット飛び / 最終ページ飛び / TTS ナビ）は、レイアウト確定までに build が複数回走っても高々 1 回だけ適用される」決定論を `vertical-text-display` spec に明文化する。

## Capabilities

### New Capabilities
<!-- なし -->

### Modified Capabilities
- `vertical-text-display`: ページ効果（ページ飛び・行レポート・アニメ停止）の決定論的オーケストレーションを要件として追加する。既存のページネーション/ナビゲーション/TTS ハイライト要件の挙動は変更しない。

## Impact

- 影響コード: `lib/features/text_viewer/presentation/vertical_text_viewer.dart`（`build()` の `LayoutBuilder.builder`、ワンショットフラグ群、効果適用ヘルパー）。新規に純関数とコマンド値型（同ファイル内 or 近接の data/presentation ヘルパー）を追加。
- 影響テスト: 既存 widget テスト群は挙動不変ゆえ pass を維持（回帰ガード）。新規に `resolveViewerEffects` の純関数ユニットテストを追加。
- API/依存: 公開 API・widget の引数・provider 契約に変更なし。外部依存の追加なし。
- リスク: 中。最高チャーン箇所への介入だが、強い既存テスト網があり振る舞い不変。ページネーション計算には触れない。
