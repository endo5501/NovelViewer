## Why

小説を読む際に、登場人物名や用語を素早く検索して確認したいニーズがある。現在の実装では中央カラムでテキスト選択は可能だが、選択した単語を検索する手段がなく、右辺カラムもプレースホルダーのままである。検索機能を追加することで、読書体験を大幅に向上させる。

## What Changes

- 中央カラムのテキストビューアで選択した文字列を取得し、Cmd+F（Mac）/ Ctrl+F（Windows/Linux）で検索を実行する機能を追加
- 右辺カラムに検索結果を表示する機能を実装（右辺カラムは上段・下段の2段構成とし、下段に検索結果を表示）
- 検索は現在選択中のディレクトリ内の全テキストファイルを対象とする
- 検索結果にはファイル名と該当箇所の前後テキスト（コンテキスト）を表示
- 右辺カラムの上段はLLM要約用の領域として確保（今回はプレースホルダー、LLM要約機能は別途実装予定）

## Capabilities

### New Capabilities

- `text-search`: テキスト選択状態の追跡、キーボードショートカットによる検索トリガー、ディレクトリ内全ファイルの全文検索、検索結果の表示

### Modified Capabilities

- `three-column-layout`: 右辺カラムのレイアウトを上段（LLM要約プレースホルダー）・下段（検索結果）の2段構成に変更
- `text-viewer`: テキスト選択コールバックの追加とキーボードショートカット（Cmd+F / Ctrl+F）対応

## Impact

- `lib/shared/widgets/search_summary_panel.dart`: 右辺カラムを2段構成に再実装
- `lib/features/text_viewer/presentation/text_viewer_panel.dart`: テキスト選択の追跡とキーボードショートカット対応を追加
- `lib/features/text_viewer/providers/`: 選択テキスト状態の管理プロバイダを追加
- 新規 `lib/features/text_search/`: 検索サービス、検索結果表示、検索状態プロバイダの追加
- 既存テスト: text_viewer, search_summary_panel のテストに変更が必要
- 新規テスト: 検索機能に関するテストの追加
