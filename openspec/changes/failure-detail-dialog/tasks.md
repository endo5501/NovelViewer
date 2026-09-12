## 1. 共通の型とコピー書式

- [x] 1.1 `test/shared/failure/failure_report_test.dart` を作成する。診断項目の挿入順が保たれること、cause と stackTrace が省略可能であることを検証する
- [x] 1.2 同テストにコピー文字列の書式を追加する。全項目あり / cause と stack なし / 値が空の項目は行ごと落ちる / コードフェンスで囲まれない、の4ケース
- [x] 1.3 テストを実行して失敗を確認し、コミットする
- [x] 1.4 `lib/shared/failure/failure_report.dart` に `FailureReport`（headline / cause / stackTrace / diagnostics）と、コピー用プレーンテキストへの整形関数を実装する
- [x] 1.5 テストが通ることを確認する

## 2. 失敗スナックバー

- [x] 2.1 `test/features/tts/presentation/tts_failure_snackbar_test.dart` を `test/shared/failure/failure_snackbar_test.dart` へ移し、見出しと原因の連結規則が維持されることを検証する
- [x] 2.2 同テストに追加する。既定の表示時間を過ぎても表示が残ること、閉じるアイコンで閉じられること、詳細アクションが1つだけ存在すること、連続した失敗で先行のスナックバーが取り除かれること
- [x] 2.3 テストを実行して失敗を確認し、コミットする
- [x] 2.4 `lib/shared/failure/failure_snackbar.dart` を実装する。`removeCurrentSnackBar()` の後に `duration: Duration(days: 365)`、`showCloseIcon: true`、詳細アクションを持つスナックバーを表示する
- [x] 2.5 `formatTtsFailureMessage` 相当の連結規則を本体へ取り込み、スナックバー本文を組み立てる
- [x] 2.6 表示時に `Navigator.of(context, rootNavigator: true)` を解決して保持し、詳細アクションでは `mounted` を確認してから詳細ダイアログを開く
- [x] 2.7 テストが通ることを確認する

## 3. 詳細ダイアログ

- [x] 3.1 `test/shared/failure/failure_detail_dialog_test.dart` を作成する。診断項目 / cause / stackTrace が表示されること、内容がスクロール可能かつ選択可能であること、コピーでクリップボードに全文が入り確認が出ることを検証する
- [x] 3.2 スナックバーを出した元のウィジェットを破棄した後でも詳細ダイアログが開けることを検証するテストを追加する
- [x] 3.3 テストを実行して失敗を確認し、コミットする
- [x] 3.4 `lib/shared/failure/failure_detail_dialog.dart` を実装する
- [x] 3.5 `app_ja.arb` / `app_en.arb` / `app_zh.arb` に、ダイアログ見出し・詳細・閉じる・コピーのキーを追加する
- [x] 3.6 全ロケールで空でない翻訳が存在することを検証するテストを追加する
- [x] 3.7 テストが通ることを確認する

## 4. LLM解析の失敗を共通経路へ載せる

- [x] 4.1 `test/features/llm_summary/presentation/analysis_runner_test.dart` に追加する。失敗スナックバーが既定時間を過ぎても残ること、詳細アクションを持つこと、診断情報に時刻 / バージョン / プロバイダ / モデル / 語句 / スコープ / ファイル名が含まれること
- [x] 4.2 診断情報に `baseUrl` が一切含まれないことを検証するテストを追加する
- [x] 4.3 スタックトレースが詳細ダイアログに現れることを検証するテストを追加する
- [x] 4.4 成功スナックバーは従来どおり自動で消えることを検証するテストを追加する
- [x] 4.5 テストを実行して失敗を確認し、コミットする
- [x] 4.6 `analysis_runner.dart` の `catch (e)` を `catch (e, st)` に変える
- [x] 4.7 既存の型別メッセージ分岐の結果を headline とし、`e.toString()` を cause として `FailureReport` を構築する。`packageInfoProvider` からバージョンを読む
- [x] 4.8 失敗時の `showSnackBar` を共通ヘルパー呼び出しへ置き換える。成功時の経路は変更しない
- [x] 4.9 テストが通ることを確認する

## 5. TTS失敗を共通経路へ載せる

- [x] 5.1 `buildTtsFailureReport` のテストを作成し、診断情報（時刻 / バージョン / エンジン / モデル名 / ファイル名）を検証する。`_startStreaming` が実物の isolate と音声プレイヤをその場で組み立てるため、失敗経路をウィジェットテストから駆動できない。旧 `showTtsFailureSnackBar` と同じ層で検証する
- [x] 5.2 同テストにセグメント索引の検証を追加する（渡されたときだけ出ること）
- [x] 5.3 合成失敗の詳細出力にスタックトレースの節が現れないことを検証するテストを追加する
- [x] 5.4 テストを実行して失敗を確認し、コミットする
- [x] 5.5 `tts_controls_bar.dart` の失敗表示を `FailureReport` の構築と共通ヘルパー呼び出しへ置き換える
- [x] 5.6 `tts_edit_dialog.dart` の失敗表示を同様に置き換える
- [x] 5.7 `lib/features/tts/presentation/tts_failure_snackbar.dart` を削除し、参照を共通ヘルパーへ差し替える
- [x] 5.8 `tts_modelNeedsRedownload` など、合成失敗ではない既存のスナックバーは変更していないことを確認する
- [x] 5.9 テストが通ることを確認する

## 7. 生テキストの伏せ字 (codexレビュー指摘)

- [x] 7.1 `test/shared/failure/sensitive_redaction_test.dart` を作成する。URL全体の置換、userinfo内の認証情報、POSIX絶対パス、Windows絶対パス、置換しない普通の文字列、の各ケース
- [x] 7.2 `renderFailureReport` と `formatFailureSnackBarBody` の出力が伏せ字を通ることを検証するテストを追加する
- [x] 7.3 テストを実行して失敗を確認し、コミットする
- [x] 7.4 `lib/shared/failure/sensitive_redaction.dart` に `redactSensitive` を実装する
- [x] 7.5 `renderFailureReport` と `formatFailureSnackBarBody` から適用する
- [x] 7.6 テストが通ることを確認する

## 6. 最終確認

- [ ] 6.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm dart format .`でフォーマットを実行
- [x] 6.4 `fvm flutter analyze`でリントを実行
- [x] 6.5 `fvm flutter test`でテストを実行
- [ ] 6.6 iOS実機またはシミュレータで、LLM解析を意図的に失敗させ、スナックバーが残り詳細ダイアログからコピーできることを確認
