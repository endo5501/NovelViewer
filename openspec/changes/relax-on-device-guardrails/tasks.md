## 1. プラグインのDart境界

- [x] 1.1 `packages/foundation_models_llm/test/foundation_models_llm_generate_channel_test.dart` に、`generate` が `sampling` をメソッドチャネル引数に載せることを確認するテストを追加する(未指定時は null、`greedy` 指定時は `'greedy'`)
- [x] 1.2 同テストに、`schemaFieldName` を null にしたときスキーマ引数が送られないことの確認を追加する
- [x] 1.3 テストが失敗することを確認してコミットする
- [x] 1.4 `FoundationModelsLlm.generate` に `sampling` 引数を追加し、`MethodChannelFoundationModelsLlm` が送るようにする。抽象側のdocコメントで、値は不透明な名前でありネイティブ側が解釈できない値は未指定と同じ扱いになることを書く
- [x] 1.5 テストが通ることを確認してコミットする

## 2. ネイティブ実装

- [x] 2.1 `FoundationModelsLlmPlugin.swift` の `generate` で `SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)` を作り、そのモデルで `LanguageModelSession` を開くようにする。既存の `#available(iOS 26.0, macOS 26.0, *)` の内側に収まることをコメントで明示する
- [x] 2.2 `availability` の判定も同じモデル構成で行うか、`SystemLanguageModel.default` のままとするかを決めて、選んだ理由をコメントに残す
- [x] 2.3 `sampling` 引数を読み、`'greedy'` のとき `GenerationOptions(sampling: .greedy, maximumResponseTokens:)` を渡す。解釈できない値は未指定として扱う
- [x] 2.4 `scripts/` を使わず `fvm flutter build macos` でビルドが通ることを確認する

## 3. クライアントの再試行方針

- [x] 3.1 `test/features/llm_summary/data/foundation_models_client_test.dart` に、スキーマ付き生成が `guardrailViolation` で失敗したとき、スキーマなし・`greedy` で二回目が呼ばれることを確認するテストを追加する
- [x] 3.2 同テストに、スキーマなしの生成が拒否されたときは二回目が呼ばれないことのテストを追加する
- [x] 3.3 同テストに、二回目も拒否されたとき `LlmOnDeviceRefusedFailure` が投げられることのテストを追加する
- [x] 3.4 同テストに、生成要求が一つのプロンプトにつき最大2回であることのテストを追加する
- [x] 3.5 同テストに、`guardrailViolation` 以外の失敗では二回目が呼ばれないことのテストを追加する
- [x] 3.6 テストが失敗することを確認してコミットする
- [x] 3.7 `FoundationModelsClient.generate` に二段構えを実装する。なぜ制約を外すのか、なぜ `greedy` なのかをdocコメントに残す
- [x] 3.8 テストが通ることを確認してコミットする

## 4. 返答形の受け入れ確認

- [x] 4.1 `test/features/llm_summary/data/llm_parsed_response_test.dart` に、コードフェンスで囲まれ `facts` が文字列であるオブジェクトが読めることのテストを追加する(既存のカバレッジがあれば確認のみ)
- [x] 4.2 同テストに、コードフェンスで囲まれ `facts` が文字列配列であるオブジェクトが読めることのテストを追加する
- [x] 4.3 同テストに、閉じていないJSONが生テキストとして扱われ解析が止まらないことのテストを追加する
- [x] 4.4 パイプライン側の変更が不要であることを確認する。必要になった場合は理由を design.md に追記する

## 5. 実機検証

- [ ] 5.1 macOSビルドで `narou_n9669bk/017_第十五話「職員会議と日曜日」.txt` の「エドナ」を解析し、成功することを確認する
- [ ] 5.2 同じ小説の戦闘描写を含む話数で解析し、挙動を記録する
- [ ] 5.3 ガードレールに関係しない通常の単語で解析し、従来通りスキーマ制約経路が使われて退行がないことを確認する
- [ ] 5.4 iPad実機またはシミュレータでビルドが通り、解析が動くことを確認する

## 6. 最終確認

- [ ] 6.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 6.3 `fvm dart format .`でフォーマットを実行
- [ ] 6.4 `fvm flutter analyze`でリントを実行
- [ ] 6.5 `fvm flutter test`でテストを実行
