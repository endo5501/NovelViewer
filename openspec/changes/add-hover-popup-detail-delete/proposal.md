## Why

LLM 解析の結果を削除したり、その元になった事実（`fact_cache`）を確認したりする操作は、現在は Drawer の解析履歴タブでエントリを右クリック／長押しして開くメニューからしか行えない。解析結果に納得がいかず消したい、元の事実を確かめたいと思うのは、たいてい本文上で要約ポップアップを読んでいるその瞬間であり、そこから Drawer を開いて目的の単語を探し直すのは手間が大きい。

## What Changes

- 要約ポップアップの要約テキストの下に1行設け、右寄せでボタンを2つ追加する（アイコンと文字ラベル付き）。
  - 「詳細を表示」（`Icons.info_outline`）: 解析履歴メニューと同じ単語詳細ダイアログ（事実タブ／解析結果タブ）を開く。
  - 「削除」（`Icons.delete_outline`）: 確認ダイアログを経て、その単語の解析結果を語単位で全削除する（`word_summaries` の全スナップショットと `fact_cache`。解析履歴メニューの「削除」と同じ処理）。
- ポップアップ経由の削除には確認ダイアログを挟む。解析履歴メニューの削除は従来どおり確認なしのまま変更しない。
- 詳細・削除のボタンは、LLM 要約が利用できないプラットフォームでも表示する。どちらも LLM を必要としないため。再解析ボタンが非対応環境で出ないのは従来どおり。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `llm-summary-hover-popup`: ポップアップに「詳細を表示」「削除」の操作を追加する要件を加える。削除時の確認ダイアログ、削除単位、プラットフォームによらず表示することを定める。
- `llm-summary-history-detail-view`: 単語詳細ダイアログの起動元に、解析履歴メニューに加えて要約ポップアップの「詳細を表示」を追加する。

## Impact

- コード: `lib/features/llm_summary/presentation/hover_popup_widget.dart`（ボタン追加と確認ダイアログ）、`lib/features/llm_summary/providers/llm_summary_history_provider.dart`（削除時にポップアップ用キャッシュも破棄）
- l10n: `lib/l10n/app_{ja,en,zh}.arb`（ボタンのラベルと確認ダイアログの文言）
- テスト: `test/` 配下のホバーポップアップ関連ウィジェットテスト、履歴 provider のテスト
- データ構造・リポジトリ API・依存パッケージの変更はない
