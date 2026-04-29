## Why

OpenAI互換APIキーが平文で `SharedPreferences` に保存されており、アプリデータディレクトリへの読み取りアクセスがあれば誰でも取得できる状態にある (`lib/features/settings/data/settings_repository.dart:20,128`)。実害のある攻撃面であり、Flutterエコシステムには既に `flutter_secure_storage` が標準的解として存在する。同じスプリントで、READMEに記載された Ollama デフォルトエンドポイント (`http://localhost:11334`) がコード実装 (`http://localhost:11434`) と100違っており、READMEに従うとユーザーが Ollama に接続できない問題も合わせて修正する。

## What Changes

- LLM API キー (`llm_api_key`) を `SharedPreferences` から `flutter_secure_storage` に移管する
- 起動時マイグレーション: 既存の `SharedPreferences` 上のキーを読み出して `flutter_secure_storage` に書き込み、元の `SharedPreferences` キーを削除する。冪等であり、失敗してもアプリ起動を阻害しない
- `LlmConfig.apiKey` の永続化責務を `SettingsRepository` から分離し、API キーのみは secure storage 経由で取得・保存する (F018 一部対応)
- `pubspec.yaml` に `flutter_secure_storage: ^9.0.0` を追加
- README.md の Ollama エンドポイント記載を `http://localhost:11334` → `http://localhost:11434` に修正

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `llm-settings`: API キーの保存先を `SharedPreferences` から `flutter_secure_storage` に変更。`LLM settings persistence` 要件の分割と、起動時マイグレーション要件の追加。

## Impact

- **Code**:
  - `lib/features/settings/data/settings_repository.dart` (API key 保存先変更、`getApiKey` / `setApiKey` 非同期化)
  - `lib/features/settings/data/llm_config.dart` (apiKey の取り扱い再考)
  - `lib/features/settings/providers/settings_providers.dart` または起動シーケンス (マイグレーション呼び出し)
  - `lib/features/llm_summary/data/llm_summary_pipeline.dart` 等の LLM クライアント生成箇所 (API key を on-demand 取得へ)
  - `lib/main.dart` または起動時フック (マイグレーション実行)
- **Dependencies**: `flutter_secure_storage: ^9.0.0` 追加
- **Tests**:
  - `test/features/settings/data/settings_repository_test.dart` (secure storage 連携、マイグレーションロジック)
  - 既存 LLM 関連テストの API key 取得が非同期化することへの追従
- **Docs**: `README.md` Ollama ポート修正
- **Migration risk**: 既存ユーザーのキー移行が静かに失敗するとユーザーから「LLM が動かない」状態が見える。debugPrint で痕跡を残し、ユーザーは設定画面で再入力可能。
- **Platforms**: macOS / Windows / Linux のいずれでも `flutter_secure_storage` がサポートされる。Linux はバックエンドに `libsecret` を必要とするため、CI とドキュメントでの確認が必要。
