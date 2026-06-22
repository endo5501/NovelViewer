## Context

解析履歴パネル（`LlmSummaryHistoryPanel` / `_HistoryEntryTile`）は単語と要約プレビューのみを表示し、右クリックメニュー（`onSecondaryTapUp` → `showMenu`）から「コピー」「削除」を提供している。一方、単語の事実情報（Stage-1 抽出結果）は `fact_cache` テーブルに永続化されているが UI に一切露出しておらず、確認には生 DB を覗くしかない。最終要約（`word_summaries.summary`）は永続化済みでホバーポップアップ（`HoverPopupWidget`）でのみ閲覧可能。

データは全て永続化済みで、本変更は read-only の表示導線を追加するのみ。スキーマ変更・新規永続化は不要。

関連リポジトリ（いずれも既存）:
- `FactCacheRepository.findForWord(word)` → `List<FactCacheEntry>`（ファイル別の事実）
- `LlmSummaryRepository.findSnapshotsForWord(word)` → `List<WordSummary>`（エピソード別の要約）

## Goals / Non-Goals

**Goals:**
- 解析履歴の右クリックメニューに「詳細を表示」を追加し、単語の事実＋解析結果を1つのダイアログで確認できるようにする。
- 事実はファイル別に表示し、無効化済み（センチネル hash）の事実もグレー表示で残す。
- 解析結果は既存の要約カードを流用し、スナップショット切替を維持する。

**Non-Goals:**
- 事実・要約の編集／削除／再解析トリガ（read-only に限定）。
- DB スキーマ変更・新規永続化。
- 縦書き／本文ホバー側の挙動変更。

## Decisions

### 決定1: 新規ダイアログウィジェットを追加し、コンテキストメニューはアクション追加で拡張する

`HistoryContextAction`（sealed class）に `ViewDetailsAction` を追加し、`buildHistoryContextMenuItems` に「詳細を表示」項目を挿入する（コピー submenu と削除の間）。`dispatchHistoryContextAction` に `onViewDetails` コールバックを追加し、`LlmSummaryHistoryPanel` 側で `showDialog` を呼ぶ。

- 理由: 右クリック基盤（`onSecondaryTapUp` + `showMenu`）と sealed action のディスパッチは既存。最小差分で導線を足せる。
- 代替案: 既存の `HoverPopupWidget` を履歴から直接開く案 → 事実タブが無く、ホバー専用のポインタ追従ロジックに依存するため不適。

### 決定2: 2タブ構成の `StatefulWidget` ダイアログ

`AlertDialog`/`Dialog` 内に `TabBar` + `TabBarView`（事実 / 解析結果）を持つ専用ウィジェットを新設する。データ取得は `FutureBuilder`（または Riverpod の `FutureProvider.family`）で `findForWord` / `findSnapshotsForWord` を非同期ロードする。

- 理由: 2つの異なる粒度（事実=ファイル別 N件、要約=スナップショット別）を1画面に同居させるにはタブが自然。read-only なので状態管理は最小。
- 取得方式: 既存パネルが Riverpod を使うため、`folderPath` を引数に取る `FutureProvider.family` を1〜2本追加するのが一貫する（パネルの provider 構成に合わせる）。

### 決定3: 解析結果タブは要約カードを共有部品として流用

`HoverPopupWidget` 内の `_Card`（スナップショット切替 ◀／▶ 付きの要約表示）を、ホバー固有のポインタ制御から切り離した共有ウィジェットとして切り出し、ホバーと詳細ダイアログの両方から利用する。切り出しが大きくなる場合は、まず最小限の共有（要約テキスト＋スナップショット選択 UI）に留める。

- 理由: 重複実装を避け、スナップショット選択ロジック（`chooseDefaultSnapshot` 等）を再利用する。
- 注意: ホバー側は再解析ドロップダウン等の操作を持つが、詳細ダイアログは read-only。共有部品には「操作を出さない」フラグ、または read-only 用の薄いラッパを用意する。

### 決定4: 無効事実の判定

`fact_cache` 行の `content_hash` が空文字（`FactCacheRepository.sentinelHash`）の場合を「無効」とみなす（`isFactCacheValid` と整合）。無効行はリストから除外せず、減衰表示（opacity 低下）＋「無効」バッジで表示する。

- 理由: ユーザー意図（「無効化された事実はグレー表示で残す」）に直結。`prompt_version` 不一致も厳密には無効だが、ファイルの現在 hash が無いと判定できないため、UI 上の単純判定はセンチネル hash のみとする。

## Risks / Trade-offs

- [要約カード切り出しでホバー側を壊すリスク] → 切り出しは TDD で進め、既存ホバーのテストを先に通す。共有が困難なら、当面は詳細ダイアログ側で要約＋スナップショット選択の最小再実装に切り替える（spec は「流用」を要求するが、見た目・挙動が一致すれば実装手段は問わない）。
- [事実テキストが長大] → タブ内はスクロール可能にし、ファイル別に折りたたみ可能とすることを検討（最小実装ではスクロールのみで可）。
- [provider 構成の不一致] → パネル既存の provider（`llmSummaryRepositoryProvider` / `factCacheRepositoryProvider` family）に合わせて追加し、独自経路を作らない。
- [i18n] → 「詳細を表示」「事実」「解析結果」「無効」「事実がありません」「解析結果がありません」等を `app_localizations`（ja/en）に追加。未追加だとビルド時に欠落する。
