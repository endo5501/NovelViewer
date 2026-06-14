## Context

`VerticalTextViewer`（`lib/features/text_viewer/presentation/vertical_text_viewer.dart`、約 922 行）の `build()` は `Focus > Listener > LayoutBuilder` 構成で、`LayoutBuilder.builder`（256-449 行）が以下を一塊で行っている：

1. `_paginateLines(constraints)` でレイアウト結果（`_PaginationResult`）を得る（ページネーション計算自体は F115/F116/F117 でメモ化済み・純粋）。
2. その結果と State フィールドから条件を読み、**5 つの副作用**を post-frame `setState` 等でスケジュールする。
3. その過程で **6 つの State フィールドを build 中に変異**させる。

副作用とフィールド変異の現状マッピング：

| # | 効果 | build 中変異 | スケジュール内容 |
|---|------|-------------|-----------------|
| ① | ターゲットページ飛び (273-290) | `_scheduledTargetPage` | post-frame `setState(_currentPage=target; _targetLine=null)` + `onHoverHideRequest` |
| ② | レイアウト変化でアニメ停止 (293-297) | `_lastConstraints` | 即時 `_animationController.stop()` + `_outgoingSegments=null` |
| ③ | 最終ページ飛び (309-321) | `_jumpToLastPagePending=false` | post-frame `setState(_currentPage=last)` + `onHoverHideRequest` |
| ④ | TTS 自動ナビ (324-336) | `_pendingTtsOffset=null` | post-frame `_goToPage(ttsPage)`（アニメ経路 `_changePage`） |
| ⑤ | 現在行レポート (339-347) | `_lastReportedLine` | post-frame `onPageLineChanged(pageLine)` |
| — | （補助） | `_pageCount`, `_currentPageSegments` | — |

F156 の核心的 smell は、ワンショットフラグ（③ `_jumpToLastPagePending`、④ `_pendingTtsOffset`）を **build の最中にクリア**している点。build はレイアウト確定までに複数回走りうるため、`_scheduledTargetPage` のような後追いガードで「二重スケジュール」を都度パッチしている。

制約：
- ページネーション計算（`_heavyPagination` / `_HeavyPagination` / `_PaginationResult` / `computeCharOffsetPerPage`）は変更しない。
- 既存 14 本超の widget テスト（`vertical_text_viewer_*` / `tts_auto_page_test` / `text_viewer_panel_test`）の挙動を不変に保つ。
- CLAUDE.md の TDD 厳守。

## Goals / Non-Goals

**Goals:**
- 「どの効果を起こすか」の決定を、widget tree 不要の**純関数** `resolveViewerEffects` へ抽出し、単体テスト可能にする。
- `LayoutBuilder.builder` を「決定を委譲し、効果適用だけを担う薄い層」へ縮退させ、効果適用を一箇所（即時効果 + 単一 post-frame）に集約する。
- ワンショットフラグの消費を「build 中の散発変異」から「コマンド値経由の一箇所適用」へ移し、二重適用/消失の温床を断つ。
- 振る舞い不変（ユーザ可視挙動・ページ遷移・TTS 追従・初期ページ・行レポートは現状どおり）。

**Non-Goals:**
- ページネーション計算アルゴリズムの変更（F115/F116/F117 済み）。
- TTS ナビ（④）をアニメ経路 `_changePage` から切り離すこと。④ は引き続き `_changePage` を通す（ジャンプ系①③の即時 setState とは経路が異なるため、コマンドとしては別フィールドで表現する）。
- ジェスチャ/キー/ホイールハンドラ（`_handleKeyEvent` 等）や 2 段階確認フロー（`_handleBoundaryNavigation` 等）の再設計。これらは効果オーケストレーションの外なので本変更では触らない。
- 公開 API・widget 引数・provider 契約の変更。

## Decisions

### 決定 1: 「決定」と「適用」を分離する（pure decision → command value → single application）

純関数とコマンド値を導入する：

```
@visibleForTesting
ViewerEffects resolveViewerEffects(ViewerEffectInputs inputs)
```

- `ViewerEffectInputs`（不変スナップショット）: `pageCount`, `targetPage`, `currentPage`, `scheduledTargetPage`, `jumpToLastPagePending`, `pendingTtsOffset`, `charOffsetPerPage`, `firstLinePerPage`, `safePage`, `lastReportedLine`, `constraintsChanged`, `isAnimating`。
- `ViewerEffects`（コマンド値）: 
  - `int? instantJumpToPage` — ①③を統合（即時 setState で `_currentPage` を移し hover を消す系）。①③は「即座に `_currentPage` を置き換える」点で同型なので 1 フィールドに畳む。優先順位は①（targetPage）を③（last page）より優先（現状の build 上から下への評価順を保存）。
  - `int? animatedGoToPage` — ④TTS（`_changePage` 経由）。
  - `int? reportLine` — ⑤。
  - `bool cancelAnimation` — ②。
  - `bool hideHover` — ①③④に伴う hover 非表示。
  - 消費フラグ: `bool consumeJumpToLastPage`, `bool consumeTtsOffset`, `int? newScheduledTargetPage` — 適用層が State を更新するための指示。

**なぜ純関数か:** F156 の指摘「最高チャーンのロジックが最もテスト困難な場所に集中」を直接解消する。決定ロジックを `WidgetTester` 不要の table-driven テストで網羅でき、TDD のテストファーストが自然に成立する。

**代替案:** (a) Controller/ChangeNotifier に状態機械を載せる → 状態移行の副作用が増え、レイアウト由来の入力（constraints）を controller に注入する配管が重い。(b) build 内の現状維持で `_scheduledTargetPage` 式ガードを足し続ける → F156 が問題視するパッチの上塗り。純関数抽出が最小侵襲かつ最大のテスト性向上。

### 決定 2: ワンショットフラグのクリアを散発変異から単一適用箇所へ集約する

`resolveViewerEffects` は「このフラグを消費すべき」を `consumeXxx` フラグとして返すだけにし、実際の State 変異（`_jumpToLastPagePending=false`、`_pendingTtsOffset=null` 等）は **単一の適用ヘルパー `_applyViewerEffects` に集約**する。`LayoutBuilder.builder` の本体（ページネーション読み取り〜widget ツリー構築）に散らばっていた直書き変異を撤去する。

消費（フラグクリア）は `_applyViewerEffects` の中で **build 同期的に**行う。これは意図的な選択である：もし消費を post-frame に遅延すると、レイアウト確定までに build が複数回走った際、各 build の `resolveViewerEffects` がまだ立っているフラグを見て post-frame を再スケジュールし、効果が二重適用されてしまう（F156 が問題視する再入バグそのもの）。同期消費により、消費後の build のスナップショットは安定し、二重適用が構造的に起きない。`_scheduledTargetPage` ガードはコマンド値の `newScheduledTargetPage`（同期記録 → post-frame で null リセット）に置き換わり、意図が明示される。

「散発変異の排除」は *ページネーション読み取りや widget 構築のロジックと交錯した状態変異をなくす* ことを意味し、消費を build 内に残すことと矛盾しない。F156 の smell は「レイアウト計算・効果スケジュール・フラグ変異が `LayoutBuilder.builder` 内で絡み合っている」点であり、それらを「決定（純関数）＋単一適用箇所」へ分離することで解消される。

**トレードオフ:** ②（アニメ停止）も `_applyViewerEffects` 内で build 同期的に即時適用する（post-frame に回すとフレーム内整合が崩れる）。コマンド値としては `cancelAnimation` で表現するが適用タイミングは即時。これは現状と同じ挙動。ページ飛び（①③④）・hover 非表示・行コールバックのみ単一 post-frame に遅延する。

### 決定 3: 配置とスコープ

`resolveViewerEffects` / `ViewerEffects` / `ViewerEffectInputs` は当面 `vertical_text_viewer.dart` 同一ファイル内のトップレベル（`@visibleForTesting` 公開）に置く。`_PaginationResult` 等と同居させ、後続で必要なら専用ファイルへ切り出す。

**なぜ:** F115/F116/F117 が同ファイル内トップレベル純関数（`computeCharOffsetPerPage`）+ `@visibleForTesting` カウンタという手本を既に確立している。同じ流儀に合わせ、レビュー差分を読みやすく保つ。

### 決定 4: TDD の順序と回帰ガード

1. 純関数 `resolveViewerEffects` のユニットテストを先に書く（各効果単独 / 競合時の優先順位 / consume-once / no-op 条件）。失敗を確認 → コミット。
2. build を委譲へ差し替える。
3. 既存 widget テスト 14 本 + 新規ユニットテストが緑になるまで実装を修正。

既存テストの効果別カバレッジ：① `vertical_text_viewer_initial_page_test`/`_pagination_test`、② `_animation_test`、③ `_initial_page_test`、④ `tts_auto_page_test`、⑤ `_pagination_test`/`text_viewer_panel_test`。

## Risks / Trade-offs

- [build 評価順に潜む暗黙の優先順位を取りこぼす] → スナップショット抽出時に現状の「上から下」評価順（①→②→③→④→⑤）をコメントで固定し、`resolveViewerEffects` のテストで競合ケース（同一 build で target/last/tts が同時成立）を明示的に検証する。
- [②アニメ停止のタイミング差で 1 フレームのちらつき] → ②は build 内即時適用を維持し、post-frame に回さない。`_animation_test` で回帰確認。
- [`_changePage` 経路（④）と即時 setState 経路（①③）の取り違え] → コマンド値で `instantJumpToPage` と `animatedGoToPage` を別フィールドに分け、適用層で経路を固定。`tts_auto_page_test` が回帰ガード。
- [ワンショット消費の二重適用/消失] → 消費を post-frame 単一適用に集約し、純関数テストで「複数回 build → 1 回適用」を `scheduledTargetPage`/`consume*` の状態遷移として検証。
- [最高チャーン箇所ゆえ将来の競合] → 振る舞い不変に徹し、spec に決定論要件を 1 つ追加するのみ。挙動拡張は別 change に分離。
