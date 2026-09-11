## Why

用語解析はこれまで、読者が自分で用意した LLM サーバに本文の抜粋を送ることでしか動かなかった。iPad ではそのサーバが手元になく、あったとしてもローカルネットワークへの到達許可が要る。その結果、iPad 単体では実質的に使えない機能になっている。

iPadOS 26 / macOS 26 の Apple Foundation Models なら、端末の中で完結する。サーバの用意も、ネットワーク許可も、本文の外部送信も要らない。対応端末であれば、設定を一つ選ぶだけで解析が動くようになる。

## What Changes

- 社内 Flutter プラグイン `packages/foundation_models_llm` を新設する。iOS と macOS が同じ Swift 実装を共有する `darwin/` 構成とする。プラグインが公開するのは二つだけ: オンデバイスモデルの可用性の問い合わせと、スキーマ付きのテキスト生成。
- Dart 側に三つ目の `LlmClient` 実装を追加する。`LlmResponseSchema.singleStringField` を Swift の `DynamicGenerationSchema` に写し、構造化出力をモデルの努力目標ではなく文法上の保証にする。
- `LlmProvider` に値を追加し、設定のプロバイダ選択に第三の選択肢を出す。この選択肢には接続先 URL も API キーもモデル名もない。
- 可用性を三層に分けて扱う。Apple プラットフォームかどうかは既存の純粋な能力モデルが答える。端末が非対応か、Apple Intelligence が無効か、モデルが未用意かは、ネイティブへの非同期な問い合わせが答える。
- 使えない理由が一時的なとき（Apple Intelligence が無効、モデル準備中）は、選択肢を隠さずに理由を添えて選択不可にする。待てば使える状態を読者に伝える手段がほかにないため。恒久的なとき（端末が非対応、OS が古い）は選択肢自体を出さない。伝えるべき中身がなく、死んだ項目が残るだけになる。
- 自動フォールバックはしない。オンデバイスを選ぶ動機は本文を外に出さないことなので、使えなくなった瞬間に黙ってサーバへ送るのは利便性ではなく事故になる。
- **BREAKING** ではないが契約の変更: `LlmClient` に文脈予算を持たせ、`LlmSummaryService` がそれを読んで `LlmSummaryPipeline` を組むようにする。オンデバイスの窓は入出力あわせて 4096 トークンしかなく、現行の 4000 文字固定では最初の一回で溢れる。既存の二クライアントは既定値を返すため挙動は変わらない。
- Swift の `GenerationError` を読者が読める失敗として Dart に写す。とくに `guardrailViolation` は小説の内容次第で普通に起きるため、原因が分かる形で伝える。

## Capabilities

### New Capabilities
- `apple-on-device-llm`: Apple Foundation Models をオンデバイスの LLM プロバイダとして提供する能力。プラグイン境界、可用性の問い合わせと三つの不可理由、動的スキーマによる構造化生成、生成エラーの写像、自動フォールバックを行わない方針を含む。

### Modified Capabilities
- `llm-settings`: プロバイダ選択に第三の選択肢が加わる。接続設定を持たないプロバイダという新しい形が入り、その選択肢を出すかどうかと選べるかどうかは `apple-on-device-llm` に委ねる。
- `platform-capabilities`: 能力モデルが名指しする任意機能にオンデバイス LLM が加わる。ただし純粋関数が答えるのはプラットフォームの層までで、端末と実行時状態の層はモデルの外に置く。
- `llm-summary-pipeline`: チャンク幅が固定の 4000 文字ではなく、クライアントが申告する文脈予算になる。再帰的な畳み込みの閾値も同じ値に従う。

## Impact

- 新規: `packages/foundation_models_llm/`（Dart、`darwin/` の Swift、iOS と macOS の podspec）。このプロジェクト初の MethodChannel となる。既存のネイティブ連携はすべて FFI。
- 変更: `lib/features/llm_summary/data/llm_client.dart`（文脈予算）、`llm_summary_service.dart`（予算の受け渡し）、`domain/llm_config.dart`（プロバイダ値）、`providers/llm_summary_providers.dart`（クライアント生成）、設定の LLM セクション、`shared/providers/platform_capabilities_provider.dart` 周辺。
- ビルド: iOS と macOS のデプロイメントターゲットは 13.0 と 10.15 のままとし、Swift 側を `if #available(iOS 26.0, macOS 26.0, *)` で囲む。macOS はサンドボックス有効のため、専用の entitlement が要るかを実装時に確認する。
- 非対象プラットフォーム（Windows、Linux）ではプラグインの実装が存在しないため、そもそも呼ばれない経路にする。
- スコープ外: `fact_cache` がどのモデルの抽出した事実かを区別しない問題。オンデバイスが加わると品質差として見えやすくなるが、スキーマ移行を伴うため別の変更として扱う。
