# Tasks

## 1. 実機計測テストで修正前の挙動を再現する

- [x] 1.1 `integration_test/on_device_llm_runaway_test.dart` を追加する。design.md D7 の 1〜3 と 5（制約付きを5回、スキーマなし・greedy・打ち切りなし、スキーマなし・既定サンプリング・打ち切りなし、`FoundationModelsClient.generate`）を `MethodChannelFoundationModelsLlm` 経由で実行し、出力の先頭・長さ・所要時間・拒否の回数をログに残す。4（打ち切りあり）は 3.x で引数ができてから足す。`fvm flutter analyze` が通ることで確認する
- [x] 1.0 実機に初めて入れる前に、`scripts/install_ios.sh --backup --device <iPhone>` 相当の手順で iPhone のデータ（小説・参照音声・設定・DB）を `~/Backups/` に取り出し、バックアップのファイルがあることを確認する。実機に入れる前（1.2・3.4・6.1・6.2）には毎回、ユーザーに確認する
- [x] 1.2 iPhone 実機（iOS 27.0.1）で `fvm flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/on_device_llm_runaway_test.dart -d <デバイス ID>` を実行する。スキーマなし・greedy で「支援者: Appleです。」の繰り返しが再現し、応答上限まで走ることをログで確かめ、結果（所要時間を含む）を design.md の Context に追記する。再現しない場合は先へ進まず、ユーザーと方針を相談する
- [ ] 1.3 `docs/ios.md` に計測テストの目的と実行手順（Apple Intelligence が有効な実機が必要なこと）を追記し、手順どおりのコマンドで 1.2 が実行できることを確認する

## 2. 打ち切りの判定（Swift、Flutter ビルド外）

- [ ] 2.1 `packages/foundation_models_llm/darwin/wire_code_tests` に、打ち切り判定の新しいターゲットとテストターゲットを追加する（ソースはプラグイン側に置き、`GenerationFailureWireCode` と同じくシンボリックリンクで参照する）。先にテストだけを書く。対象は、オブジェクトが閉じたら範囲つきで完成を返す、文字列中の `}` とエスケープされた `\"` では閉じない、前置きのフェンスを除いた範囲を返す、同じ文が3回続いたら繰り返しを返す、2回では返さない、`」}` で閉じない iPhone の実例では、前の文とつながる1回目を除いて数え、4回目の「支援者: Appleです。」で繰り返しと判定する（3回目では判定しない）、増分を少しずつ与えても結果が同じ、の各ケース。`swift test --package-path packages/foundation_models_llm/darwin/wire_code_tests` で失敗することを確認してコミットする
- [ ] 2.2 判定の型を実装し、2.1 のテストが通ることを `swift test --package-path packages/foundation_models_llm/darwin/wire_code_tests` で確認する

## 3. プラグインの逐次受信と打ち切り

- [ ] 3.1 Dart プラグインのテストを先に書く（`packages/foundation_models_llm/test/foundation_models_llm_generate_channel_test.dart`）。`generate` に打ち切りを要求する引数を渡すとメソッドチャネルの引数に載ること、省略時は載らない（従来と同じ）こと、エラーコード `repetitiveOutput` が `OnDeviceGenerationFailure.repetitiveOutput` に読まれること。`cd packages/foundation_models_llm && fvm flutter test` で失敗することを確認してコミットする
- [ ] 3.2 `packages/foundation_models_llm/lib/src/` に引数と `OnDeviceGenerationFailure.repetitiveOutput` を追加し、3.1 のテストが通ることを確認する
- [ ] 3.3 `FoundationModelsLlmPlugin.swift` で、打ち切りを要求された呼び出しだけ `streamResponse` で受け、2.2 の判定でオブジェクトを返すか、`repetitiveOutput` の FlutterError を返すようにする。要求されていない呼び出しは従来どおり `respond` を使う。ストリームの各要素がその時点までの全文か差分かを最初に確かめ、判定に渡す増分の取り方をそれに合わせる。`scripts/build_app.sh macos` でビルドが通ることで確認する
- [ ] 3.4 計測テスト（1.1）に design.md D7 の 4（スキーマなし・greedy・打ち切りあり）を追加する。iPhone 実機で、オブジェクトか `repetitiveOutput` が返ること、所要時間が打ち切りなしより明らかに短いことを確かめる。ループを抜けても生成が止まらず時間が縮まらない場合は、生成の `Task` を cancel するように 3.3 を直して、もう一度測る。結果を design.md に追記する

## 4. クライアントの再試行の順序

- [ ] 4.1 `test/features/llm_summary/data/` のクライアントのテストを先に書く。拒否されたら同じスキーマ・サンプリング指定なしでもう1回、それも拒否されたらスキーマなし・greedy・打ち切りありで1回、の順に呼ぶこと。最大3回であること。2回目が拒否以外で失敗したらその原因を報告し、3回目は呼ばないこと。3回目の `repetitiveOutput` がその原因で報告されること。すべての要求が同じ応答上限を持つこと。`LlmOnDeviceGenerationFailure(repetitiveOutput).isWorthRetrying` が true であること。`fvm flutter test test/features/llm_summary` で失敗することを確認してコミットする
- [ ] 4.2 `foundation_models_client.dart` と `llm_analysis_failure.dart` を実装し、ドキュメントコメントを新しい順序と測定（macOS 27.0.1 で3回中2回拒否、iPhone 27.0.1 で止まらない）に合わせて書き直す。4.1 のテストが通ることを確認する

## 5. 読めない最終要約を失敗にする（全プロバイダ）

- [ ] 5.1 `test/features/llm_summary/data/` のパイプラインのテストを先に書く。2回とも読めない最終要約で `LlmAnalysisUnreadableSummaryFailure` が投げられ、3回目の要求がないこと。2回目の要求が失敗した場合も同じ失敗になること。2回目が読めればそれを使うこと。Stage 1 の生テキストへのフォールバックは従来どおり（`isStructured: false` で値を返す）であること。サービスのテストで、この失敗のときにスナップショットが保存されないこと。既存のテスト「2回とも読めなければ1回目を残す」「2回目が失敗したら1回目を残す」は、新しい仕様に合わせて書き換える。`fvm flutter test test/features/llm_summary` で失敗することを確認してコミットする
- [ ] 5.2 `llm_analysis_failure.dart` に `LlmAnalysisUnreadableSummaryFailure` を追加し、`llm_summary_pipeline.dart` の `_readableOr` と最終要約の処理を実装する（2回目の失敗はログに残す）。ドキュメントコメントを新しい挙動に合わせて書き直す。5.1 のテストが通ることを確認する
- [ ] 5.3 `analysis_runner.dart` の失敗の振り分けに分岐を加え、`lib/l10n/app_{ja,en,zh}.arb` に `llmAnalysis_unreadableSummary` を追加する。先に presentation のテストで、その失敗のときにこの文言の SnackBar が出ることを書いて失敗を確認し、実装後に `fvm flutter test test/features/llm_summary/presentation` が通ることを確認する

## 6. 統合確認

- [ ] 6.1 iPhone 実機で計測テスト（1.1 の全項目）を実行し、修正後の `FoundationModelsClient.generate` が、`summary` を持つ JSON を返すか、例外で終わることを確かめる（壊れたテキストを返さない）。結果を design.md に追記する
- [ ] 6.2 iPhone 実機のアプリで、「記憶人」を再解析する。読める要約が保存されるか、「要約を読み取れなかった」旨の表示で終わる（壊れた要約が保存されない）ことを確かめる。macOS と iPad mini（26.6.2）でも同じ単語を解析し、従来どおり要約できることを確かめる

## 7. 最終確認

- [ ] 7.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 7.3 `fvm dart format lib test`でフォーマットを実行
- [ ] 7.4 `fvm flutter analyze`でリントを実行
- [ ] 7.5 `fvm flutter test`でテストを実行
