## 1. 設定値の正規化 — テスト

TDDのため、まずテストのみを用意して失敗を確認し、赤の状態でコミットする。

- [x] 1.1 正規化ヘルパのテストを作成する（エンドポイントURL: 前後の空白除去、末尾スラッシュの連続除去、空白のみの入力が空になる、内部のスラッシュは触らない）
- [x] 1.2 正規化ヘルパのテストを作成する（モデル名: 前後の空白除去、`org/model` の形が保たれる、末尾スラッシュは除去しない）
- [x] 1.3 正規化ヘルパのテストを作成する（APIキー: 前後の空白と改行の除去、内部は触らない）
- [x] 1.4 `settings_repository_test.dart` に書き込み時の正規化のテストを追加する（`setLlmConfig` / `setApiKey` に空白付きの値を渡し、保存先の中身が正規化済みであることを確認）
- [x] 1.5 `settings_repository_test.dart` に読み出し時の正規化のテストを追加する（保存先に空白付きの値を直接仕込み、`getLlmConfig` / `getApiKey` が正規化済みの値を返すことを確認）
- [x] 1.6 テストを実行し、意図した理由で失敗することを確認する
- [x] 1.7 赤の状態でコミットする

## 2. 設定値の正規化 — 実装

- [x] 2.1 正規化ヘルパを実装する（エンドポイントURL用・モデル名用・APIキー用）
- [x] 2.2 `setLlmConfig` / `setApiKey` に正規化を通す
- [x] 2.3 `getLlmConfig` / `getApiKey` に正規化を通す
- [x] 2.4 1章のテストがすべて通ることを確認する
- [x] 2.5 設定画面のコントローラへの書き戻しが発生していないことを確認する（`llm_settings_section.dart` を変更しない）
- [x] 2.6 コミットする

## 3. 不足判定 — テスト

- [x] 3.1 `findLlmConfigProblem` のテストを作成する（プロバイダ未設定 → `noProvider`）
- [x] 3.2 `findLlmConfigProblem` のテストを作成する（Ollama: エンドポイントURL欠落 / モデル名欠落 / 両方揃っていれば null）
- [x] 3.3 `findLlmConfigProblem` のテストを作成する（OpenAI互換API: エンドポイントURL欠落 / モデル名欠落 / APIキー欠落 / すべて揃っていれば null）
- [x] 3.4 `findLlmConfigProblem` のテストを作成する（オンデバイス: サーバ設定が空でも null）
- [x] 3.5 `findLlmConfigProblem` のテストを作成する（複数欠落時の優先順位: エンドポイントURL → モデル名 → APIキー）
- [x] 3.6 テストを実行し、意図した理由で失敗することを確認する
- [x] 3.7 赤の状態でコミットする

## 4. 不足判定 — 実装

- [x] 4.1 `LlmConfigProblem` enum と `findLlmConfigProblem` を実装する
- [x] 4.2 3章のテストがすべて通ることを確認する
- [x] 4.3 コミットする

## 5. クライアント生成への接続 — テスト

- [x] 5.1 `llm_summary_providers_test.dart` に、Ollamaでエンドポイントが空のときクライアントが生成されないテストを追加する
- [x] 5.2 `llm_summary_providers_test.dart` に、Ollamaでモデル名が空のときクライアントが生成されないテストを追加する
- [x] 5.3 `llm_summary_providers_test.dart` に、OpenAI互換APIでエンドポイントまたはモデル名が空のときクライアントが生成されないテストを追加する
- [x] 5.4 既存のAPIキー欠落時のテストが引き続き通ることを確認する
- [x] 5.5 オンデバイスプロバイダがサーバ設定の判定を受けないテストを追加する
- [x] 5.6 テストを実行し、意図した理由で失敗することを確認する
- [x] 5.7 赤の状態でコミットする

## 6. クライアント生成への接続 — 実装

- [x] 6.1 `llmClientProvider` の分岐を `findLlmConfigProblem` に置き換える
- [x] 6.2 オンデバイスの可用性判定を変更していないことを確認する
- [x] 6.3 5章のテストがすべて通ることを確認する
- [x] 6.4 コミットする

## 7. 不足を名指しするメッセージ — テスト

- [x] 7.1 `app_ja.arb` / `app_en.arb` / `app_zh.arb` に3つの文言（エンドポイントURL・モデル名・APIキー）を追加する
- [x] 7.2 `fvm flutter gen-l10n` 相当の生成を行い、キーが利用可能になることを確認する
- [x] 7.3 `analysis_runner_test.dart` に、APIキーのみ欠落時に汎用文言ではなくAPIキーを名指しする文言が出るテストを追加する
- [x] 7.4 `analysis_runner_test.dart` に、エンドポイントURL欠落時・モデル名欠落時のテストを追加する
- [x] 7.5 `analysis_runner_test.dart` に、プロバイダ未設定時は既存の汎用文言が出るテストを追加する
- [x] 7.6 `analysis_runner_test.dart` に、これらのスナックバーが詳細アクションを持たないテストを追加する
- [x] 7.7 `analysis_runner_test.dart` に、空白のみのエンドポイントURLで `FormatException` が読者に届かないテストを追加する
- [x] 7.8 テストを実行し、意図した理由で失敗することを確認する
- [x] 7.9 赤の状態でコミットする

## 8. 不足を名指しするメッセージ — 実装

- [x] 8.1 `_noServiceMessage` を `findLlmConfigProblem` に基づく分岐に置き換える
- [x] 8.2 オンデバイスの可用性メッセージを既存のまま残す
- [x] 8.3 表示経路が既存の `_snack` のままであることを確認する（`showFailureSnackBar` は使わない）
- [x] 8.4 7章のテストがすべて通ることを確認する
- [x] 8.5 コミットする

## 9. 3言語の文言確認

- [x] 9.1 日本語・英語・中国語の3ファイルにキーが揃っていることを確認する
- [x] 9.2 既存の `llmAnalysis_noLlmConfigured` が削除されずプロバイダ未設定用として残っていることを確認する

## 10. 最終確認

- [ ] 10.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 10.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 10.3 `fvm dart format .`でフォーマットを実行
- [ ] 10.4 `fvm flutter analyze`でリントを実行
- [ ] 10.5 `fvm flutter test`でテストを実行
