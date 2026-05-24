## Why

現在のLLM単語要約UIは右カラム上部に常設パネルを置く設計だが、(1) 本文を読みながら別の領域に視線を移す必要があり閲覧体験を阻害する、(2) 解析の起動が「単語を選択 → 別領域のボタンを押す」と離れた2点で完結し動線が悪い、(3) 右カラムを常時占有するため本文表示領域を圧迫している。インラインのホバーポップアップ＋右クリック起動に再設計することで、本文の流れを切らずに既キャッシュの要約を参照でき、解析起動も選択地点で完結する。

## What Changes

- **BREAKING**: 右カラム上部の `LlmSummaryPanel`（タブ式の常設要約パネル）を撤去する
- マーク済みの語（点線/実線下線が付いている語）に**マウスホバーするとポップアップで要約を表示する**機能を追加（横書きモードのみ）
- 両種別キャッシュ済みの語にホバーした時、ポップアップ内に [なし|あり] 切替ピルを置き、既定は「ネタバレなし」
- ポップアップ内に「参照位置ズレ警告」（ノースポイラー要約の解析元ファイルが現在表示中ファイルと異なる場合）を小さく表示
- 解析の起動を**選択 → 右クリック → 「解析開始 ▸ ネタバレなし / ネタバレあり」サブメニュー**に変更
- キャッシュ済み語に対する再解析は確認ダイアログなしに上書き（メニュー文言は常に「解析開始」のまま）
- 解析中はモーダルダイアログでスピナーを表示（barrierDismissible: false、進捗％なし、キャンセル不可）
- 右カラムは検索結果のみを残す構成に変更
- 左カラム「解析履歴」タブの各エントリに**要約テキストをコピーする操作**を追加（ホバーポップアップが非コピーになる代替）
- 縦書きモードは本changeのスコープ外。既存の側線mark表示は維持、ホバーポップアップは出さない（縦書き対応は別change）
- 解析中の「単語を選択」状態への依存は撤去するが、`selectedTextProvider` 自体は他機能（辞書追加など）で使用中のため残す

## Capabilities

### New Capabilities
- `llm-summary-hover-popup`: マーク済み語へのマウスホバーで要約をポップアップ表示する機能（横書き専用）。表示種別の切替、ズレ警告、表示/非表示のトリガー条件を含む
- `llm-summary-context-menu-trigger`: 本文中のテキスト選択 → 右クリックメニューからLLM解析を起動する機能。サブメニュー構成、既キャッシュ語の再解析挙動、解析中モーダル表示を含む

### Modified Capabilities
- `llm-summary`: 右カラムパネル(`LlmSummaryPanel`)の常設表示・タブ・解析開始ボタン・選択監視に関する全要件を撤去する。markレンダリングおよびLLMパイプライン呼び出し関連の要件は維持する
- `llm-summary-history-ui`: 履歴エントリから要約テキストをコピーする要件を追加する

## Impact

**コード影響**
- 削除: `lib/features/llm_summary/presentation/llm_summary_panel.dart`
- 改修: `lib/shared/widgets/search_summary_panel.dart`（撤去または `SearchResultsPanel` 単独表示に変更）と `lib/home_screen.dart` の右カラム組み込み
- 改修: `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart`（右クリメニュー拡張、ホバー検出フック追加）
- 改修: `lib/features/text_viewer/presentation/ruby_text_builder.dart`（mark付きTextSpanに `onEnter/onExit` を生やす）
- 新規: ホバーポップアップウィジェット、ポップアップ表示用notifier、解析中モーダル表示ロジック
- 改修: `lib/features/llm_summary/presentation/llm_summary_history_panel.dart`（コピー操作追加）

**仕様/動作影響**
- ユーザは「単語を選択するだけ」では解析を起動できなくなる。右クリック操作が必須化
- 縦書きモードユーザはホバー機能を利用できない（mark表示は引き続き有効）
- ポップアップはコピー不可。コピーが必要な場合は左カラム履歴タブから

**依存・外部要素**
- LLM呼び出しパイプライン (`llm-summary-pipeline`)、キャッシュ層 (`llm-summary-cache`)、mark判定 (`mark_matcher`) には変更なし
