# Tasks

## 1. テスト(Red)

- [x] 1.1 `packages/foundation_models_llm/darwin/foundation_models_llm/Sources/foundation_models_llm/` に `GenerationOptionsFactory.swift` を作り、`samplingMode(named:)` と `GenerationOptions` の組み立てを今の形(旧 init `init(sampling:...)`)のまま移す。移したことは、ファイルの中身で確かめる
- [x] 1.2 `wire_code_tests/Sources/GenerationOptionsFactory/` にシンボリックリンクを置き、`Package.swift` に `-warnings-as-errors` 付きのターゲットとテストターゲットを追加する。ターゲットがリンク先のファイルを拾うことは、1.4 のビルドで確かめる
- [x] 1.3 `wire_code_tests/Tests/GenerationOptionsFactoryTests/` に、`"greedy"` なら `samplingMode == .greedy`、nil や未知の名前なら `samplingMode == nil`、`maximumResponseTokens` がそのまま入ること(nil も含む)を確かめるテストを書く
- [x] 1.4 `swift test --package-path packages/foundation_models_llm/darwin/wire_code_tests` を実行し、非推奨の警告がエラーになってビルドが失敗する(Red)ことを確かめてから、テストをコミットする

## 2. 実装(Green)

- [x] 2.1 `GenerationOptionsFactory.swift` で、後継の `init(samplingMode:temperature:maximumResponseTokens:)` を使うように変える。`swift test --package-path packages/foundation_models_llm/darwin/wire_code_tests` が全件通ることで確かめる
- [x] 2.2 `FoundationModelsLlmPlugin.swift` の `generate(...)` で、切り出した関数を呼ぶように変え、元の `samplingMode(named:)` を消す。`grep -n "GenerationOptions(" FoundationModelsLlmPlugin.swift` で直接の組み立てが残っていないことを確かめる
- [x] 2.3 CLAUDE.md の `swift test` コマンドの説明に、生成オプションのテストも含まれることを書き足す。書いたコマンドがそのまま実行できることで確かめる

## 3. 統合確認

- [x] 3.1 `scripts/build_app.sh macos` でビルドし、ログに `FoundationModelsLlmPlugin.swift` の `deprecated` 警告が出ないことを確かめる
- [x] 3.2 `scripts/build_app.sh ios` でビルドし、同じ警告が出ないことを確かめる(iOS のビルド環境が無ければ、そのことを記録して省く)
- [ ] 3.3 macOS 版のアプリでオンデバイス LLM の要約を1回実行し、以前と同じように結果が返ることを確かめる

## 4. 最終確認

- [x] 4.1 code-reviewスキルを使用してコードレビューを実施
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm dart format lib test`でフォーマットを実行
- [x] 4.4 `fvm flutter analyze`でリントを実行
- [x] 4.5 `fvm flutter test`でテストを実行
