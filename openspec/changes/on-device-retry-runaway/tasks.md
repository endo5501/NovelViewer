# Tasks

## 1. 実機計測テストで修正前の挙動を再現する

- [x] 1.0 実機に初めて入れる前に、`scripts/install_ios.sh --backup --device <iPhone>` 相当の手順で iPhone のデータ（小説・参照音声・設定・DB）を `~/Backups/` に取り出し、バックアップのファイルがあることを確認する。実機に入れる前には毎回、ユーザーに確認する
- [x] 1.1 `integration_test/on_device_llm_runaway_test.dart` を追加し、制約付き ×5・スキーマなし（greedy / 既定サンプリング）・`FoundationModelsClient.generate` を `MethodChannelFoundationModelsLlm` 経由で実行して、出力・長さ・所要時間をレポートに残す。macOS で `fvm flutter drive ... -d macos` が通ることで確認する
- [x] 1.2 iPhone 実機（iOS 27.0.1）で 1.1 を実行し、暴走を再現する。結果を `measurements/iphone16-ios27.0.1-before.json` に保存し、design.md の Context に記録する
- [x] 1.3 `docs/ios.md` に計測テストの目的と実行手順（Apple Intelligence が有効な実機が必要なこと、実行後にアプリとデータが消えるので、バックアップと書き戻しが必要なこと）を追記する。手順どおりのコマンドが macOS で実行できることを確認する

## 2. 暴走を元から断てるかの実験（design.md D1）

- [x] 2.1 プラグインに実験用の引数（`summary` フィールドの正規表現の制約、`includeSchemaInPrompt`）を一時的に加え、Dart の `FoundationModelsLlm.generate` から渡せるようにする。既存のチャネルテストが `cd packages/foundation_models_llm && fvm flutter test` で通ること、`scripts/build_app.sh macos` でビルドできることを確認する
- [x] 2.2 計測テストに E1（JSON の例示の行を外したプロンプト）・E2（`[^}]*` の制約）・E3（`includeSchemaInPrompt: false`）を各5回加える。各回答の判定（暴走 = 値が 1300 字を超えた、または `}` を含む）と、出力の先頭・末尾をレポートに残す。macOS で実行して結果を `measurements/macos27.0.1-experiments.json` に保存する
- [x] 2.3 iPhone のデータをバックアップし（実行前にユーザーに確認する）、iPhone で 2.2 を実行して結果を `measurements/iphone16-ios27.0.1-experiments.json` に保存する。release ビルドを入れ直してデータを書き戻し、ファイル数がバックアップと一致することを確認する。効いたものが2つ以上あれば、その組み合わせ（E4）も同じ手順で測る
- [x] 2.4 結果をユーザーに示し、採否を決める。採用したものは spec（`apple-on-device-llm`）と design.md に計測値つきで書き足し、tasks に実装のタスクを加える。採らなかった実験用の引数とテストの条件は削除する。`openspec validate on-device-retry-runaway --strict` が通ることで確認する

## 3. 打ち切りの判定（Swift、Flutter ビルド外）

- [x] 3.1 `packages/foundation_models_llm/darwin/wire_code_tests` に、打ち切り判定の新しいターゲットとテストターゲットを追加する（ソースはプラグイン側に置き、シンボリックリンクで参照する）。先にテストだけを書く。対象は、制約付き: 値に `}` が現れたら暴走、値が予算を超えたら暴走、予算内で `}` がなければ続行。スキーマなし: オブジェクトが閉じたら範囲つきで完成、文字列中の `}` と `\"` では閉じない、フェンスを除いた範囲を返す、閉じないまま予算を超えたら暴走、`{` がないまま予算を超えたら暴走。全文を少しずつ伸ばして与えても結果が同じであること、計測の実例（`measurements/` の5件）が `}` で暴走と判定されること。`swift test --package-path packages/foundation_models_llm/darwin/wire_code_tests` で失敗することを確認してコミットする
- [x] 3.2 判定の型を実装し、3.1 のテストが通ることを `swift test --package-path packages/foundation_models_llm/darwin/wire_code_tests` で確認する

## 4. プラグインの逐次受信と打ち切り

- [x] 4.1 Dart プラグインのテストを先に書く（`packages/foundation_models_llm/test/foundation_models_llm_generate_channel_test.dart`）。`generate` に応答予算と「スキーマなしの回答を打ち切る」指定を渡すとチャネルの引数に載ること、省略時は載らないこと、エラーコード `runawayOutput` が `OnDeviceGenerationFailure.runawayOutput` に読まれること。`cd packages/foundation_models_llm && fvm flutter test` で失敗することを確認してコミットする
- [x] 4.2 `packages/foundation_models_llm/lib/src/` に引数と `OnDeviceGenerationFailure.runawayOutput` を追加し、4.1 のテストが通ることを確認する。ドキュメントコメントも更新する
- [x] 4.3 `FoundationModelsLlmPlugin.swift` で、予算が渡された呼び出しは `streamResponse` で受け、3.2 の判定で打ち切るようにする。制約付きは `runawayOutput` を返し、スキーマなしはオブジェクトか `runawayOutput` を返す。予算が渡されない呼び出しは従来どおり `respond` を使う。`scripts/build_app.sh macos` でビルドが通ること、macOS で計測テストが通ることで確認する

## 5. クライアントの切り替え

- [x] 5.1 クライアントのテストを先に書く（`test/features/llm_summary/data/`）。制約付きの要求に応答予算（`maxResponseSize`）が渡されること。制約付きの `runawayOutput` は、拒否と同じくスキーマなし・greedy・打ち切りあり・同じ予算の要求を1回だけ出すこと。拒否のときのスキーマなしの要求にも、打ち切りと予算が付くこと。スキーマなしの要求の `runawayOutput` はそのまま報告されること。最大2回であること。`LlmOnDeviceGenerationFailure(runawayOutput).isWorthRetrying` が true であること。`fvm flutter test test/features/llm_summary` で失敗することを確認してコミットする
- [x] 5.2 `foundation_models_client.dart` と `llm_analysis_failure.dart` を実装し、ドキュメントコメントを新しい挙動と計測（iPhone 16 / iOS 27.0.1 で制約付きが5回とも暴走、スキーマなしは約1秒で正常）に合わせて書き直す。5.1 のテストが通ることを確認する

## 6. 読めない最終要約を失敗にする（全プロバイダ）

- [x] 6.1 パイプラインのテストを先に書く（`test/features/llm_summary/data/`）。2回とも読めない最終要約で `LlmAnalysisUnreadableSummaryFailure` が投げられ、3回目の要求がないこと。2回目の要求が失敗した場合も同じ失敗になること。2回目が読めればそれを使うこと。Stage 1 の生テキストへのフォールバックは従来どおりであること。サービスのテストで、この失敗のときにスナップショットが保存されないこと。既存のテスト「2回とも読めなければ1回目を残す」「2回目が失敗したら1回目を残す」は、新しい仕様に合わせて書き換える。`fvm flutter test test/features/llm_summary` で失敗することを確認してコミットする
- [x] 6.2 `llm_analysis_failure.dart` に `LlmAnalysisUnreadableSummaryFailure` を追加し、`llm_summary_pipeline.dart` の最終要約の処理を実装する（2回目の失敗はログに残す）。ドキュメントコメントを新しい挙動に合わせて書き直す。6.1 のテストが通ることを確認する
- [x] 6.3 presentation のテストを先に書き、その失敗のときに `llmAnalysis_unreadableSummary` の SnackBar が出ることを確かめて、失敗を確認する。`analysis_runner.dart` に分岐を加え、`lib/l10n/app_{ja,en,zh}.arb` に文言を追加して、`fvm flutter test test/features/llm_summary/presentation` が通ることを確認する

## 7. 統合確認

- [x] 7.1 計測テストに、修正後の経路（`FoundationModelsClient.generate` を5回）を加える。iPhone のデータをバックアップし（実行前にユーザーに確認する）、iPhone で実行して、5回とも `summary` を持つ JSON を返すこと、それぞれの所要時間が修正前（約20秒）より明らかに短いことを確かめる。結果を `measurements/iphone16-ios27.0.1-after.json` に保存し、design.md に記録したうえで、入れ直しと書き戻しを行う。時間が縮まない場合は、生成の `Task` を cancel するように 4.3 を直して、もう一度測る
- [ ] 7.2 `scripts/install_ios.sh --device <iPhone>` で release ビルドを入れ（データは残る）、アプリで「記憶人シィー」と「キャロル」を再解析する。正しい要約が保存されることを確かめる。macOS と iPad mini（26.6.2）でも同じ単語を解析し、従来どおり要約できることを確かめる

## 8. 最終確認

- [ ] 8.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 8.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 8.3 `fvm dart format lib test`でフォーマットを実行
- [ ] 8.4 `fvm flutter analyze`でリントを実行
- [ ] 8.5 `fvm flutter test`でテストを実行
