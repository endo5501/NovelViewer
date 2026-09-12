## Why

Apple のオンデバイスモデルで小説を解析すると、無害な場面でも `guardrailViolation` で解析そのものが成立しないケースが多発している。実測で原因を特定した。判定は入力文ではなくモデル自身の出力にかかっており、登場人物への否定的な記述を生成した時点で弾かれる。暴力表現に限った話ではない。

同じ本文でも、`SystemLanguageModel` を `permissiveContentTransformations` ガードレールで作り、かつ `GenerationSchema` を外せば通る。両方が必要で、片方だけでは効かない。構造化生成の経路はガードレール設定を無視しているように見える。

スキーマを外すと今度はモデルが同じ文を繰り返して応答トークン上限に当たり、JSON が閉じないまま切れる。これは `GenerationOptions.sampling` に `.greedy` を指定すると解消する。

現在このプロバイダは、ガードレール拒否を「同じ要求を投げ直しても答えは変わらない」失敗として一度で諦める。その判断は正しいが、要求を変えれば答えは変わる。

## What Changes

- `SystemLanguageModel` を常に `permissiveContentTransformations` ガードレールで生成する。スキーマの併用に不利益はなく、通過率と出力の詳しさはむしろ向上する。
- `guardrailViolation` を受けたとき、`FoundationModelsClient` がスキーマなし・`.greedy` サンプリングで一度だけ投げ直す。再試行の方針は Dart 側が持ち、プラグインはガードレールとサンプリングを引数で受ける薄い橋のままにする。
- プラグインの `generate` に、スキーマ制約を外した生成とサンプリング方式の指定を渡せるようにする。
- 退化した経路を通ったことは読者に伝えない。読者に取れる回避手段がないため。
- 再試行も拒否された場合は、これまで通りそのファイルの失敗として扱い、他のファイルの解析は続行する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `apple-on-device-llm`: 3点が変わる。(1) モデル生成時のガードレール設定を明示し、緩和側を選ぶ。(2) スキーマ制約は第一候補にとどめ、ガードレール拒否時は制約を外した再生成に切り替える。(3) ガードレール拒否は「再試行しない失敗」ではなくなる。ただし投げ直すのは同一の要求ではなく条件を変えた要求であり、「同じ要求を投げ直しても無駄」という原則自体は維持される。

## Impact

- `packages/foundation_models_llm/darwin/.../FoundationModelsLlmPlugin.swift`: モデル生成にガードレール指定を追加。`generate` がサンプリング方式を受ける。
- `packages/foundation_models_llm/lib/src/foundation_models_llm.dart`: `generate` の引数追加。`MethodChannelFoundationModelsLlm` のメソッドチャネル引数を拡張。
- `lib/features/llm_summary/data/foundation_models_client.dart`: 二段構えの生成方針を実装。
- `lib/features/llm_summary/data/llm_summary_pipeline.dart`: 変更しない見込み。既存の `_stripCodeFence` と配列正規化が、制約なし生成の返答形をそのまま吸収することを実測で確認済み。
- 配列形の返答とコードフェンス付き返答が従来より増えるため、その経路のテストを増やす。
- アプリのデプロイメントターゲットは変わらない。`permissiveContentTransformations` は iOS 26.0 / macOS 26.0 から利用でき、既存の `#available` ガードがそのまま覆う。
