## Why

解析履歴パネルは解析対象の単語しか表示しておらず、その単語についてどんな事実情報（Stage-1 抽出結果＝`fact_cache.facts`）が保存されているかを確認するには、ユーザーが生の `novel_data.db` を直接覗くしかない。最終的な解析結果（`word_summaries.summary`）もノベル本文をホバーしないと見られず、履歴パネルからは到達できない。履歴上で単語の中身（事実・解析結果）をその場で確認できる導線が必要。

## What Changes

- 解析履歴エントリの右クリックメニュー（現状「コピー」「削除」）に **「詳細を表示」** 項目を追加する。
- 「詳細を表示」を選ぶと、その単語の **read-only のタブ付きダイアログ** を開く:
  - **事実タブ**: `fact_cache` の行をファイル別リストで表示。`content_hash` がセンチネル（空文字）＝無効化された事実はグレー表示で残す（削除はしない）。
  - **解析結果タブ**: 既存の `HoverPopupWidget` のカード（スナップショット切替 UI 付き）を流用して `word_summaries` の要約を表示する。
- ダイアログは閲覧専用。事実・要約の編集／削除は行わない。
- データは全て永続化済みのため、DB スキーマ変更・新規永続化は不要。

## Capabilities

### New Capabilities
- `llm-summary-history-detail-view`: 解析履歴から開く read-only の単語詳細ダイアログ。事実（fact_cache）タブと解析結果（word_summaries）タブを切り替えて、選択した単語に保存されている情報を確認できる。

### Modified Capabilities
- `llm-summary-history-ui`: 履歴エントリの右クリックコンテキストメニューに「詳細を表示」項目を追加する（既存のコピー／削除に加えて、詳細ダイアログを開くトリガを提供する）。

## Impact

- 影響コード:
  - `lib/features/llm_summary/presentation/llm_summary_history_menu.dart` — `HistoryContextAction` に詳細表示アクションを追加、メニュー項目を追加。
  - `lib/features/llm_summary/presentation/llm_summary_history_panel.dart` — ディスパッチ時にダイアログを開く処理を追加。
  - 新規: 詳細ダイアログウィジェット（事実タブ＋解析結果タブ）。
  - `lib/features/llm_summary/presentation/hover_popup_widget.dart` — 解析結果カードを履歴ダイアログから流用できるよう、必要なら共有部品として切り出し。
- データアクセス:
  - `FactCacheRepository.findForWord(word)` で事実行を取得（既存）。
  - `LlmSummaryRepository.findSnapshotsForWord(word)` で要約スナップショットを取得（既存）。
- 依存・スキーマ: 変更なし（read-only、新規 DB 列なし）。
- i18n: 「詳細を表示」「事実」「解析結果」「無効」等の文言を `app_localizations` に追加。
