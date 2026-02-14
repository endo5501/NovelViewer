## Why

小説を読む際、登場人物や用語の意味を把握したいことがある。現在、テキスト選択による検索機能は存在するが、検索結果の一覧が表示されるだけで、選択した単語が何を意味するのかを理解するには読者自身が文脈を読み解く必要がある。LLMを活用して選択単語の要約を自動生成することで、読書体験を大幅に向上させる。

## What Changes

- 右辺カラム上段の「LLM要約」プレースホルダーを実装し、選択した単語のLLM要約を表示する
- 要約は「ネタバレあり」「ネタバレなし」の2タブで表示する
  - 「ネタバレあり」: ドキュメントフォルダ内の全テキストを検索し、その検索結果近傍のテキストを元に要約
  - 「ネタバレなし」: 現在閲覧中のファイル位置までのテキストのみを使用して要約
- 各タブに「解析開始」ボタンを配置し、押下でLLM解析を実行する
- LLM解析結果をSQLiteデータベースにキャッシュし、同じ単語を再度選択した際に保存結果を表示する
- 「解析開始」ボタンによる再解析でキャッシュを更新する
- 設定画面にLLM設定セクションを追加する
  - LLMプロバイダ選択: OpenAI互換API / Ollama
  - OpenAI互換API: エンドポイントURL、APIキー、モデル名
  - Ollama: エンドポイントURL、モデル名
- GenGlossary（`/Users/endo5501/Work/GenGlossary`）の検索・要約ロジックおよびプロンプトを参考にする

## Capabilities

### New Capabilities
- `llm-summary`: 選択した単語のLLM要約機能（ネタバレあり/なしタブ、解析開始ボタン、要約表示UI）
- `llm-settings`: LLMプロバイダ設定機能（OpenAI互換API / Ollama の接続設定、設定画面UI）
- `llm-summary-cache`: LLM要約結果のSQLiteキャッシュ機能（保存・読み込み・再解析による更新）

### Modified Capabilities
- `text-search`: 検索結果から近傍テキストを抽出するコンテキスト取得機能を追加（LLM要約のプロンプト用入力データとして使用）

## Impact

- **UI**: 右辺カラム上段のプレースホルダー（`search_summary_panel.dart`）をLLM要約UIに置き換え。設定ダイアログ（`settings_dialog.dart`）にLLM設定セクションを追加
- **データベース**: SQLiteに要約キャッシュ用テーブルを追加（`novel_database.dart`のスキーマバージョンアップ）
- **依存パッケージ**: HTTP通信用の`http`パッケージは既に導入済み。追加パッケージは不要の見込み
- **外部依存**: LLMサービス（Ollama ローカルサーバー or OpenAI互換APIエンドポイント）への接続が必要
- **参考実装**: GenGlossaryのLLMクライアント実装（`llm/ollama_client.py`, `llm/openai_compatible_client.py`）およびプロンプト設計（`glossary_generator.py`）を参考にFlutter/Dart向けに再実装
