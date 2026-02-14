## 1. ドメインモデルとLLM設定基盤

- [x] 1.1 `lib/features/llm_summary/domain/llm_config.dart` を作成: LlmProvider enum (ollama, openai, none)、LlmConfig モデルクラス（provider, baseUrl, apiKey, model）
- [x] 1.2 `lib/features/llm_summary/domain/llm_summary_result.dart` を作成: WordSummary モデルクラス（id, folderName, word, summaryType, summary, sourceFile, createdAt, updatedAt）、SummaryType enum (spoiler, noSpoiler)
- [x] 1.3 `lib/features/settings/data/settings_repository.dart` を拡張: LLM設定の読み書きメソッド追加（getLlmConfig / setLlmConfig）、SharedPreferencesキー定義

## 2. LLMクライアント実装

- [x] 2.1 `lib/features/llm_summary/data/llm_client.dart` を作成: LlmClient 抽象クラス（Future<String> generate(String prompt)）
- [x] 2.2 `lib/features/llm_summary/data/ollama_client.dart` を作成: OllamaClient 実装（POST {baseUrl}/api/generate、stream: false、リトライ付き）
- [x] 2.3 `lib/features/llm_summary/data/openai_compatible_client.dart` を作成: OpenAiCompatibleClient 実装（POST {baseUrl}/chat/completions、Bearer認証、JSON応答パース）

## 3. テキスト検索の拡張コンテキスト対応

- [x] 3.1 `SearchMatch` モデルに `extendedContext` フィールドを追加（オプション）
- [x] 3.2 `TextSearchService` に `searchWithContext(directoryPath, query, {contextLines})` メソッドを追加: マッチ行の前後N行を含むコンテキストを返す
- [x] 3.3 `searchWithContext` のユニットテストを作成（通常ケース、ファイル境界、コンテキスト行数指定）

## 4. データベースマイグレーションとキャッシュリポジトリ

- [x] 4.1 `NovelDatabase` のバージョンを2に更新し、`onUpgrade` で `word_summaries` テーブルを作成。`onCreate` にも同テーブルの作成を追加
- [x] 4.2 `lib/features/llm_summary/data/llm_summary_repository.dart` を作成: findSummary（キャッシュ検索）、saveSummary（保存/更新）、deleteSummary のCRUD操作
- [x] 4.3 キャッシュリポジトリのユニットテスト作成（保存、取得、更新、キャッシュミス、spoiler/no_spoiler独立キャッシュ）

## 5. プロンプトビルダーと要約サービス

- [x] 5.1 `lib/features/llm_summary/data/llm_prompt_builder.dart` を作成: buildSpoilerPrompt / buildNoSpoilerPrompt メソッド（XMLタグ構造、最大10件コンテキスト制限、JSON応答要求）
- [x] 5.2 プロンプトビルダーのユニットテスト作成（spoiler/no-spoilerプロンプト生成、コンテキスト上限、空コンテキスト）
- [x] 5.3 `lib/features/llm_summary/data/llm_summary_service.dart` を作成: generateSummary メソッド（検索結果フィルタリング → コンテキスト付き検索 → プロンプト構築 → LLM呼び出し → JSON解析 → キャッシュ保存）
- [x] 5.4 要約サービスのユニットテスト作成（ネタバレあり全ファイル使用、ネタバレなしファイル番号フィルタ、LLMレスポンスJSONパース、非JSONフォールバック）

## 6. Riverpodプロバイダー

- [x] 6.1 `lib/features/llm_summary/providers/llm_summary_providers.dart` を作成: llmConfigProvider、llmClientProvider、llmSummaryRepositoryProvider、llmSummaryServiceProvider
- [x] 6.2 要約状態管理の Notifier を作成: LlmSummaryNotifier（解析実行、キャッシュ読み込み、状態管理）、AsyncValue で loading/data/error 状態を管理
- [x] 6.3 LLM設定プロバイダーのユニットテスト作成

## 7. LLM設定UI

- [x] 7.1 `settings_dialog.dart` にLLM設定セクションを追加: プロバイダドロップダウン（未設定/OpenAI互換API/Ollama）
- [x] 7.2 プロバイダ選択に応じた動的フォーム表示: OpenAI → エンドポイントURL + APIキー + モデル名、Ollama → エンドポイントURL（デフォルト値付き）+ モデル名
- [x] 7.3 設定変更時のSharedPreferences永続化とプロバイダー更新
- [x] 7.4 LLM設定UIのウィジェットテスト作成（プロバイダ切り替え、フォーム表示、設定保存）

## 8. LLM要約パネルUI

- [x] 8.1 `lib/features/llm_summary/presentation/llm_summary_panel.dart` を作成: TabBar（ネタバレなし/ネタバレあり）+ TabBarView の基本構造
- [x] 8.2 各タブ内の状態表示実装: 単語未選択メッセージ、LLM未設定メッセージ、キャッシュ結果表示、ローディングインジケータ、エラーメッセージ
- [x] 8.3 「解析開始」ボタン実装: 押下でLLM解析トリガー、解析中はボタン無効化、解析完了で再有効化
- [x] 8.4 ネタバレなしキャッシュの位置不一致通知表示（source_fileが現在のファイルと異なる場合）
- [x] 8.5 `search_summary_panel.dart` の上段プレースホルダーを `LlmSummaryPanel` に置き換え
- [x] 8.6 LLM要約パネルのウィジェットテスト作成（タブ切り替え、各状態表示、解析ボタン動作、キャッシュ表示）

## 9. 最終確認

- [x] 9.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 9.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 9.3 `fvm flutter analyze`でリントを実行
- [x] 9.4 `fvm flutter test`でテストを実行
