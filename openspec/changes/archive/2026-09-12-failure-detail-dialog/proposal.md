## Why

LLM解析やTTS合成が失敗したとき、原因はスナックバー1行に `e.toString()` として流れるだけで、約4秒で消えてしまう。読み切る前に消えるため、何が起きたのかを把握できない。

macOSとWindowsでは `<ApplicationSupport>/logs/app.log` を開けば追えるが、iOSではそれができない。`Info.plist` の `UIFileSharingEnabled` が公開するのは `Documents` だけで、ログの置き場である `Library/Application Support` はファイルアプリからもFinder共有からも見えない。Xcodeを接続する以外にログへ到達する手段がない。

失敗の内容をその場で落ち着いて読め、かつそのまま報告に貼れる形でコピーできるようにする。将来ユーザーから不具合報告を受け取る際の導線にもなる。

## What Changes

- 失敗の内容を運ぶ共通の型 `FailureReport` を新設する。ローカライズ済みの見出し、生の原因文字列、任意のスタックトレース、順序を保った診断項目のキーバリューを持つ。
- 失敗スナックバーを、手動で閉じるまで残る表示に変える。`[詳細]` と `[閉じる]` の2つのアクションを持つ。
- `[詳細]` から開くエラー詳細ダイアログを新設する。診断情報をスクロール可能な選択可能テキストで表示し、`[コピー]` でクリップボードへ全文をコピーできる。
- LLM解析の失敗（`analysis_runner.dart`）とTTS合成の失敗（`tts_controls_bar.dart` / `tts_edit_dialog.dart`）の両方を、この共通経路に載せる。既存の `showTtsFailureSnackBar` は共通ヘルパーに吸収する。
- LLM解析の `catch (e)` を `catch (e, st)` に変え、スタックトレースを診断情報に含める。
- 診断項目は 発生時刻 / プロバイダ種別 / モデル名 / 語句 / スコープ / 対象ファイル / アプリバージョン / 例外全文 / スタックトレース とする。項目名は英語固定とし、ダイアログの見出しとボタンのみローカライズする。
- エンドポイントURLは診断情報に含めない。宅内のプライベートIPを含みうるため。APIキーは `LlmConfig` に存在せず、もとより混入しない。
- `llmAnalysis_failed` と `llmAnalysis_partialFailure` から `{error}` プレースホルダを外す。エラー本文は cause として共通ヘルパーが連結するため、残すとスナックバーに二重に出る。

### 対象外

- 見逃した失敗へ後から再到達する手段（直近エラーの保持、設定画面からの閲覧）。手順を再現すれば再現できるため、今回は扱わない。
- ログファイルの配置変更、アプリ内ログビューア、共有シートによる送信。

## Capabilities

### New Capabilities
- `failure-detail-dialog`: 失敗の診断情報を運ぶ共通の型、手動クローズ型の失敗スナックバー、診断情報を表示しコピーできる詳細ダイアログ、コピー文字列の書式

### Modified Capabilities
- `llm-summary-context-menu-trigger`: 解析失敗の通知が自動で消えなくなり、`[詳細]` から診断情報を開けるようになる
- `tts-streaming-pipeline`: 合成失敗のスナックバーが自動で消えなくなり、`[詳細]` から診断情報を開けるようになる
- `tts-edit-screen`: セグメント合成失敗のスナックバーが自動で消えなくなり、`[詳細]` から診断情報を開けるようになる

## Impact

**新規**
- `lib/shared/failure/failure_report.dart`（診断情報の型とコピー文字列の整形）
- `lib/shared/failure/failure_snackbar.dart`（共通の失敗スナックバー）
- `lib/shared/failure/failure_detail_dialog.dart`（詳細ダイアログ）

**変更**
- `lib/features/llm_summary/presentation/analysis_runner.dart`（`catch (e, st)` 化、`FailureReport` の組み立て）
- `lib/features/tts/presentation/tts_failure_snackbar.dart`（共通ヘルパーへ吸収）
- `lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart`
- `lib/features/tts/presentation/tts_edit_dialog.dart`
- `lib/l10n/app_ja.arb` / `app_en.arb` / `app_zh.arb`（詳細・閉じる・コピー・ダイアログ見出し）

**依存**
- `package_info_plus`（導入済み）をアプリバージョンの取得に使う。新規パッケージの追加はない。

**既存テスト**
- `test/features/tts/presentation/tts_failure_snackbar_test.dart` は共通ヘルパー側へ移す。見出しと原因の連結規則は維持する。
