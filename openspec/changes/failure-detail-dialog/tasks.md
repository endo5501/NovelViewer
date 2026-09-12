## 1. 共通の型とコピー書式

- [ ] 1.1 `test/shared/failure/failure_report_test.dart` を作成する。診断項目の挿入順が保たれること、cause と stackTrace が省略可能であることを検証する
- [ ] 1.2 同テストにコピー文字列の書式を追加する。全項目あり / cause と stack なし / 値が空の項目は行ごと落ちる / コードフェンスで囲まれない、の4ケース
- [ ] 1.3 テストを実行して失敗を確認し、コミットする
- [ ] 1.4 `lib/shared/failure/failure_report.dart` に `FailureReport`（headline / cause / stackTrace / diagnostics）と、コピー用プレーンテキストへの整形関数を実装する
- [ ] 1.5 テストが通ることを確認する

## 2. 失敗スナックバー

- [ ] 2.1 `test/features/tts/presentation/tts_failure_snackbar_test.dart` を `test/shared/failure/failure_snackbar_test.dart` へ移し、見出しと原因の連結規則が維持されることを検証する
- [ ] 2.2 同テストに追加する。既定の表示時間を過ぎても表示が残ること、閉じるアイコンで閉じられること、詳細アクションが1つだけ存在すること、連続した失敗で先行のスナックバーが取り除かれること
- [ ] 2.3 テストを実行して失敗を確認し、コミットする
- [ ] 2.4 `lib/shared/failure/failure_snackbar.dart` を実装する。`removeCurrentSnackBar()` の後に `duration: Duration(days: 365)`、`showCloseIcon: true`、詳細アクションを持つスナックバーを表示する
- [ ] 2.5 `formatTtsFailureMessage` 相当の連結規則を本体へ取り込み、スナックバー本文を組み立てる
- [ ] 2.6 表示時に `Navigator.of(context, rootNavigator: true)` を解決して保持し、詳細アクションでは `mounted` を確認してから詳細ダイアログを開く
- [ ] 2.7 テストが通ることを確認する

## 3. 詳細ダイアログ

- [ ] 3.1 `test/shared/failure/failure_detail_dialog_test.dart` を作成する。診断項目 / cause / stackTrace が表示されること、内容がスクロール可能かつ選択可能であること、コピーでクリップボードに全文が入り確認が出ることを検証する
- [ ] 3.2 スナックバーを出した元のウィジェットを破棄した後でも詳細ダイアログが開けることを検証するテストを追加する
- [ ] 3.3 テストを実行して失敗を確認し、コミットする
- [ ] 3.4 `lib/shared/failure/failure_detail_dialog.dart` を実装する
- [ ] 3.5 `app_ja.arb` / `app_en.arb` / `app_zh.arb` に、ダイアログ見出し・詳細・閉じる・コピーのキーを追加する
- [ ] 3.6 全ロケールで空でない翻訳が存在することを検証するテストを追加する
- [ ] 3.7 テストが通ることを確認する

## 4. LLM解析の失敗を共通経路へ載せる

- [ ] 4.1 `test/features/llm_summary/presentation/analysis_runner_test.dart` に追加する。失敗スナックバーが既定時間を過ぎても残ること、詳細アクションを持つこと、診断情報に時刻 / バージョン / プロバイダ / モデル / 語句 / スコープ / ファイル名が含まれること
- [ ] 4.2 診断情報に `baseUrl` が一切含まれないことを検証するテストを追加する
- [ ] 4.3 スタックトレースが詳細ダイアログに現れることを検証するテストを追加する
- [ ] 4.4 成功スナックバーは従来どおり自動で消えることを検証するテストを追加する
- [ ] 4.5 テストを実行して失敗を確認し、コミットする
- [ ] 4.6 `analysis_runner.dart` の `catch (e)` を `catch (e, st)` に変える
- [ ] 4.7 既存の型別メッセージ分岐の結果を headline とし、`e.toString()` を cause として `FailureReport` を構築する。`packageInfoProvider` からバージョンを読む
- [ ] 4.8 失敗時の `showSnackBar` を共通ヘルパー呼び出しへ置き換える。成功時の経路は変更しない
- [ ] 4.9 テストが通ることを確認する

## 5. TTS失敗を共通経路へ載せる

- [ ] 5.1 `tts_controls_bar` の失敗表示テストに、永続表示と詳細アクション、診断情報（時刻 / バージョン / エンジン / モデル / ファイル名）を検証するケースを追加する
- [ ] 5.2 `tts_edit_dialog` の失敗表示テストに、同様のケースとセグメント索引の検証を追加する
- [ ] 5.3 合成失敗の詳細出力にスタックトレースの節が現れないことを検証するテストを追加する
- [ ] 5.4 テストを実行して失敗を確認し、コミットする
- [ ] 5.5 `tts_controls_bar.dart` の失敗表示を `FailureReport` の構築と共通ヘルパー呼び出しへ置き換える
- [ ] 5.6 `tts_edit_dialog.dart` の失敗表示を同様に置き換える
- [ ] 5.7 `lib/features/tts/presentation/tts_failure_snackbar.dart` を削除し、参照を共通ヘルパーへ差し替える
- [ ] 5.8 `tts_modelNeedsRedownload` など、合成失敗ではない既存のスナックバーは変更していないことを確認する
- [ ] 5.9 テストが通ることを確認する

## 6. 最終確認

- [ ] 6.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 6.3 `fvm dart format .`でフォーマットを実行
- [ ] 6.4 `fvm flutter analyze`でリントを実行
- [ ] 6.5 `fvm flutter test`でテストを実行
- [ ] 6.6 iOS実機またはシミュレータで、LLM解析を意図的に失敗させ、スナックバーが残り詳細ダイアログからコピーできることを確認
