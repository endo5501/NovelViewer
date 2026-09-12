## Why

LLM設定画面に入力された値は、前後の空白も末尾のスラッシュも落とさずにそのまま保存される。エンドポイントURLの先頭に空白が1つ混ざるだけで `Uri.parse` が `FormatException: Scheme not starting with alphabetic character` を投げ、解析はその不透明なエラーで失敗する。原因が入力欄の空白1文字であることは、エラー文からは読み取れない。

設定が不足している場合の案内も粗い。APIキーだけが未設定のとき、実行すると「設定画面でLLMを設定してください」と出る。設定は済ませているつもりの読者に、何を直せばよいかを伝えていない。さらにエンドポイントURLやモデル名が空の場合はクライアントが作られてしまい、実行時のHTTPエラーとして初めて表面化する。

いずれも解析が始まる直前の入口で起きる問題で、直前のchange `failure-detail-dialog` が整えた「失敗をどう見せるか」の手前にある「そもそも失敗しにくくする・早く名指しする」側にあたる。

## What Changes

- LLM設定値を保存時と読み出し時の両方で正規化する。
  - エンドポイントURL: 前後の空白を除去し、末尾のスラッシュを除去する。
  - モデル名: 前後の空白を除去する。
  - APIキー: 前後の空白を除去する（ペースト時に紛れ込む改行が `Authorization` ヘッダを壊すため）。
  - 読み出し側でも正規化することで、既に空白付きで保存済みの設定はマイグレーションなしに救済され、設定画面を次に開いた時点で表示も直る。
- サーバ系プロバイダ（Ollama / OpenAI互換API）の設定不足を、リクエストを送る前に判定する。
  - 不足判定を純粋関数 `findLlmConfigProblem` に切り出し、クライアント生成の可否と利用者に見せる文言の双方を同じ判定から導く。
  - 設定が不足している場合、LLMクライアントは生成されない（現在はAPIキー未設定のみがこの扱い）。
  - 不足している項目（エンドポイントURL / モデル名 / APIキー）を名指しするメッセージを、既存の素のスナックバーで表示する。診断情報もスタックトレースも伴わない短い案内であるため、`failure-detail-dialog` の永続スナックバー経路は使わない。
- 新しいローカライズ文字列を日本語・英語・中国語の3言語に追加する。既存の「設定画面でLLMを設定してください」はプロバイダ未選択時の文言として残す。

本changeにHTTPタイムアウトの導入は含めない。別changeとして扱う。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `llm-settings`: 設定値の永続化に正規化の規定を追加し、クライアント生成の規定にサーバ系プロバイダの必須項目が欠けている場合は null を返すことを追加する。
- `llm-summary-context-menu-trigger`: 解析を開始できないとき、不足している設定項目を名指しするメッセージを表示することを追加する。

## Impact

- `lib/features/settings/data/settings_repository.dart` — `getLlmConfig` / `setLlmConfig` / `getApiKey` / `setApiKey` に正規化を通す。
- `lib/features/llm_summary/domain/llm_config.dart` 付近 — 正規化ヘルパと `findLlmConfigProblem` の置き場所。
- `lib/features/llm_summary/providers/llm_summary_providers.dart` — `llmClientProvider` の null 判定を不足判定に置き換える。
- `lib/features/llm_summary/presentation/analysis_runner.dart` — `_noServiceMessage` を不足判定に基づく分岐に置き換える。
- `lib/l10n/app_ja.arb` / `app_en.arb` / `app_zh.arb` — 不足項目を名指しする文言を追加。
- 設定画面 (`llm_settings_section.dart`) のコントローラへの書き戻しは行わないため、入力中の挙動は変わらない。
