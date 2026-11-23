# Design

## Context

- 生成オプションは `FoundationModelsLlmPlugin.generate(...)` の中で `GenerationOptions(sampling: samplingMode(named:), maximumResponseTokens:)` として作っている。`samplingMode(named:)` は `"greedy"` を `.greedy` に、それ以外(nil や未知の名前)を nil に変換する。
- Xcode 27.1 の SDK では、後継の init が次のように宣言されている。

  ```
  @available(iOS 26.0, macOS 26.0, ...)
  @backDeployed(before: iOS 27.0, macOS 27.0, ...)
  public init(samplingMode: SamplingMode? = nil, temperature: Double? = nil, maximumResponseTokens: Int? = nil)
  ```

  プロパティ `samplingMode` も同じく back-deploy されている。`GenerationOptions` と `SamplingMode` はどちらも `Equatable`。
- プラグイン本体は FlutterFramework に依存するため、`swift test` で直接は動かせない。Flutter に依存しない部分(`GenerationFailureWireCode.swift`、`AnswerCutoff.swift`)は `wire_code_tests` パッケージにシンボリックリンクで取り込んでテストしている。このパッケージは現在、`-warnings-as-errors` を付けても警告なしでビルドできる。
- podspec の `source_files` と SwiftPM のターゲットは、どちらも `Sources/foundation_models_llm/` 以下の全 `.swift` を拾う。新しいファイルを足してもビルド設定の変更はいらない。

## Goals / Non-Goals

**Goals:**

- 非推奨の init を使わないようにして、プラグインの警告をなくす。
- 置き換え後も、生成オプションの中身(サンプリングモードとレスポンス上限)が以前と同じであることをテストで確かめる。
- 非推奨 API が再び入り込んだら、テストのビルドで気づけるようにする。

**Non-Goals:**

- サンプリングの方針や `temperature` の扱いを変えること。
- `toolCallingMode` など、iOS 27 / macOS 27 で増えた API を取り入れること。
- サードパーティのプラグインの警告と、Flutter Assemble の警告。

## Decisions

### 1. `#available` で分けず、後継の init だけを使う

後継の init は `@backDeployed(before: iOS 27.0, macOS 27.0)` 付きで iOS 26 / macOS 26 から使える。呼び出し元はすでに `@available(iOS 26.0, macOS 26.0, *)` の中なので、分岐はいらない。

- 代替案: `if #available(iOS 27, macOS 27, *)` で新旧を使い分ける。古い側の分岐に非推奨の呼び出しが残るので警告が消えず、採らない。

### 2. オプションの組み立てを Flutter に依存しないファイルに切り出す

`samplingMode(named:)` と `GenerationOptions` の組み立てを、FoundationModels だけを import する新しいファイル(例: `GenerationOptionsFactory.swift`)に移す。プラグインはそれを呼ぶ。既存の2ファイルと同じく、`wire_code_tests/Sources/<Target>/` からシンボリックリンクで参照する新しいターゲットとテストを追加する。

- 代替案: 引数ラベルだけを変えて、テストは書かない。変更自体は1行で済むが、TDD の方針に沿わず、置き換えで振る舞いが変わっていないことを確かめる手段もない。
- テストで確かめること: `"greedy"` なら `samplingMode == .greedy`、nil や未知の名前なら `samplingMode == nil`、`maximumResponseTokens` がそのまま入ること(nil も含む)。比較には後継のプロパティ `samplingMode` を使う。

### 3. 新しいターゲットは警告をエラーとして扱う

新しいターゲットに `swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]` を付ける。`swift test` を実行すれば、非推奨 API を使っているとビルドが失敗する。`unsafeFlags` は依存パッケージとしては使えないが、`wire_code_tests` はルートパッケージとしてしか使わないので問題ない。

- TDD の Red: 切り出した直後(旧 init のまま)は、このフラグのせいでビルドが失敗する。後継の init に置き換えると Green になる。
- 代替案: 実行のたびに `-Xswiftc -warnings-as-errors` を渡す。CLAUDE.md に書いてあるコマンドで実行しても効かないので、採らない。

## Risks / Trade-offs

- [Xcode 26 でビルドすると、後継の init が見つからずコンパイルエラーになる] → 開発に使う Mac はすべて Xcode 27 になっている。proposal の Impact にビルド要件として書いておく。
- [`-warnings-as-errors` のせいで、将来の SDK で新しい非推奨が増えると、テストのビルドが落ちる] → 新しい非推奨に気づけるのは狙いどおり。対象は切り出したターゲットだけで、アプリのビルドには影響しない。
- [切り出したファイルがシンボリックリンク経由でしか参照されず、リンクが壊れても気づきにくい] → 既存の2ファイルと同じやり方で、`swift test` が対象ファイルを見つけられなければビルドが失敗するので気づける。
