# Proposal

## Why

macOS 向けにビルドすると、自前のプラグイン `packages/foundation_models_llm` の `FoundationModelsLlmPlugin.swift:199` で、非推奨になった `GenerationOptions.init(sampling:temperature:maximumResponseTokens:)` の警告が出る。ビルドログの警告のうち自分たちで直せるのはこれだけで、非推奨 API を使い続けると、将来の SDK で削除されたときにビルドが壊れる。

## What Changes

- 生成オプションを組み立てる箇所で、非推奨の `init(sampling:...)` の代わりに後継の `init(samplingMode:temperature:maximumResponseTokens:)` を使う。
- オプションの組み立て(サンプリング名から `SamplingMode` への変換を含む)を Flutter に依存しないソースファイルに切り出す。既存の `wire_code_tests` パッケージからシンボリックリンクで取り込み、`swift test` で検証できるようにする。
- `wire_code_tests` を警告をエラーとして扱う設定でビルドし、非推奨 API の再混入を検出できるようにする。
- 生成の振る舞い(greedy の指定、レスポンス上限、未知のサンプリング名を指定なしとして扱うこと)は変えない。

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

(なし)。外から見える振る舞いは変わらないため、`.openspec.yaml` で `skip_specs: true` にしている。

## Impact

- 対象コード: `packages/foundation_models_llm/darwin/foundation_models_llm/Sources/foundation_models_llm/` に新しいソースファイルを1つ追加し、`FoundationModelsLlmPlugin.swift` はそれを呼ぶように変える。
- テスト: `packages/foundation_models_llm/darwin/wire_code_tests` にターゲットとテストを追加する。
- ビルド要件: 後継の init は Xcode 27 の SDK にしかないため、iOS / macOS のビルドには Xcode 27 以降が必要になる(開発に使う Mac はすべて Xcode 27 になっている)。実行時は `@backDeployed` により iOS 26 / macOS 26 でも動くので、対応 OS は変わらない。
- 対象外: サードパーティのプラグイン(audio_session、record_darwin、desktop_webview_window、flutter_web_auth_2)の警告と、Flutter Assemble の Run Script の警告。
