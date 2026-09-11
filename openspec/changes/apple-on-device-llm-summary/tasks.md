## 1. プラグインの骨格と可用性の問い合わせ

- [x] 1.1 `packages/foundation_models_llm` を作成する。`lib/` と共有 `darwin/`、iOS と macOS の podspec が `darwin/` を指す構成にする
- [x] 1.2 ルートの `pubspec.yaml` にパス依存として追加し、`fvm flutter pub get` が通ることを確認する
- [x] 1.3 macOS のサンドボックスで Foundation Models に entitlement が要るかを確認する。要る場合は `DebugProfile.entitlements` と `Release.entitlements` の両方に追加する
- [x] 1.4 可用性の戻り値を表す Dart の値型（利用可、または三つの不可理由のいずれか）を書き、その単体テストを先に書く
- [x] 1.5 プラグインの Dart 側でチャンネルの応答を値型に写すコードを、モックしたチャンネルに対するテストを先に書いてから実装する
- [x] 1.6 未知の応答文字列や応答なしを「不可」として扱うことをテストで固定する
- [x] 1.7 Swift 側で `SystemLanguageModel.default.availability` を問い合わせ、`deviceNotEligible` / `appleIntelligenceNotEnabled` / `modelNotReady` を区別して返す。全体を `if #available(iOS 26.0, macOS 26.0, *)` で囲み、満たさない環境では不可を返す
- [x] 1.8 macOS で疎通を確認する（Apple Intelligence を切った状態の確認は、設定の切り替えが要るため 7.5 に寄せる）

## 2. 構造化生成

- [x] 2.1 `LlmResponseSchema` をチャンネル引数へ写す変換のテストを先に書く（フィールド名がそのまま渡ること、null のときは渡らないこと）
- [x] 2.2 Swift 側で `DynamicGenerationSchema` に文字列プロパティ一つを組み、`GenerationSchema(root:dependencies:)` 経由で `respond(to:schema:)` を呼び、`GeneratedContent.jsonString` を返す
- [x] 2.3 スキーマなしの呼び出しでは `respond(to:)` を使い、生成テキストをそのまま返す
- [x] 2.4 呼び出しごとに新しい `LanguageModelSession` を作る。`GenerationOptions.maximumResponseTokens` で出力側を抑える
- [x] 2.5 `GenerationError` を Dart 側の失敗に写す。`guardrailViolation` / `exceededContextWindowSize` / `rateLimited` / `unsupportedLanguageOrLocale` / `assetsUnavailable` を区別する
- [x] 2.6 エラー写像の単体テストを、モックしたチャンネルに対して書く

## 3. `LlmClient` 実装

- [x] 3.1 `FoundationModelsClient` のテストを先に書く。スキーマ付きの応答が `{"facts": "..."}` の形で返ること、スキーマなしで生テキストが返ること、各エラーが対応する失敗になること
- [x] 3.2 `FoundationModelsClient implements LlmClient` を実装する
- [x] 3.3 `releaseResources()` が保持しているセッション参照を捨てることをテストで固定する
- [x] 3.4 `guardrailViolation` がファイル単位の抽出失敗として既存の部分失敗経路を流れることを、`LlmSummaryService` のテストで確認する

## 4. 文脈予算

- [x] 4.1 `LlmClient` に文脈予算を表す値を足し、既定を 4000 とする。既定値が返ることのテストを先に書く
- [x] 4.2 `LlmSummaryService` が予算を読んで `LlmSummaryPipeline` に渡すことのテストを先に書く
- [x] 4.3 サービスの実装を変更する。既存二クライアントの挙動が変わらないことを既存テストで確認する
- [x] 4.4 予算 2000 のクライアントでチャンク数がおよそ倍になることのテストを書く
- [x] 4.5 予算 2000 のとき、3000 文字の事実が再帰的な畳み込みに入ることのテストを書く
- [x] 4.6 `FoundationModelsClient` の予算を 2000 とする

## 5. 能力モデル

- [x] 5.1 `PlatformCapabilities.forPlatform` が `isMacOS` を取り、オンデバイス LLM を導出することのテストを先に書く
- [x] 5.2 iOS と macOS で可、それ以外で不可になることをテストで固定する
- [x] 5.3 オンデバイス LLM を足しても他の三機能の答えが変わらないことをテストで固定する
- [x] 5.4 `PlatformCapabilities` と `platformCapabilitiesProvider` を変更する
- [x] 5.5 層1 が偽のときネイティブへの問い合わせを行わないことを、プロバイダのテストで固定する

## 6. 設定とクライアント生成

- [x] 6.1 `LlmProvider` に値を追加する。既存の保存値が読めること、未知の名前が `none` に落ちることをテストで確認する
- [x] 6.2 設定セクションのウィジェットテストを先に書く。可用のとき選択できること、不可のとき項目が出て選択できず理由がセクション本体に出ること、層1 が偽のとき項目自体が出ないこと
- [x] 6.3 オンデバイスを選んでも接続先 URL・API キー・モデル名の入力欄が出ないことをテストで固定する
- [x] 6.4 理由の文面を三種類、多言語リソースに追加する
- [x] 6.5 設定セクションを実装する
- [x] 6.6 `llmClientProvider` のテストを先に書く。可用ならオンデバイスクライアントを返し、不可なら null を返し、保存済みのサーバ設定からクライアントを作らないこと
- [x] 6.7 `llmClientProvider` を実装する
- [x] 6.8 可用性が失われても保存済みの選択値が書き換わらないことをテストで固定する

## 7. 実機確認

- [x] 7.1 macOS で解析を一本通す。要約が生成され保存されることを確認する
- [x] 7.2 `supportedLanguages` に日本語が含まれることを確認する。表示言語を英語・中国語に切り替えたときの挙動も見る
- [ ] 7.3 iPad mini (A17 Pro) で解析を一本通し、所要時間を記録する
- [x] 7.4 `exceededContextWindowSize` が出ない文脈予算の上限を実測し、必要なら 4.6 の値を調整する
- [ ] 7.5 Apple Intelligence を切った状態で、設定の表示と解析の失敗文面を確認する
- [x] 7.6 `guardrailViolation` が起きる作品で、他のファイルの解析が続行され部分失敗として報告されることを確認する
- [x] 7.7 確認に使ったテストデータを削除する

## 8. 最終確認

- [x] 8.1 code-reviewスキルを使用してコードレビューを実施
- [x] 8.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 8.3 `fvm dart format .`でフォーマットを実行
- [ ] 8.4 `fvm flutter analyze`でリントを実行
- [ ] 8.5 `fvm flutter test`でテストを実行
