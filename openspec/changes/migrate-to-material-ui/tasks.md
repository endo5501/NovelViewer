# Tasks

## 1. 準備（Red の確認）

- [x] 1.1 作業用ブランチ `chore/migrate-to-material-ui` を作成する。完了条件：`git branch --show-current` で確認できる
- [x] 1.2 ローカルの stable を最新にする（実際には `fvm flutter upgrade` で更新した。チャンネル版は `fvm install stable` では更新されない）。完了条件：`fvm flutter --version` が 3.50.1 以上を表示する
- [x] 1.3 `fvm flutter pub get` のあと `fvm flutter analyze` を実行する。完了条件：CI と同じ196件の `deprecated_member_use` がローカルで再現する。これがこの change の Red であり、5.1 で0件になれば Green
- [x] 1.4 移行前の時点で 3.50.1 のテストを流しておく。`fvm flutter test` を実行し、失敗があれば移行とは関係のないフレームワーク起因のものとして一覧にする。完了条件：結果を記録する（ここでは直さない）
  - 記録（2026-11-23, 3.50.1）：+4587 ~10 -1。失敗は `test/features/novel_reference/presentation/reference_sources_dialog_test.dart` の「while saving the dialog cannot be dismissed until the save settles」（`A Timer is still pending even after the widget tree was disposed`、sqflite の txnSynchronized が作る10秒の Timer）。単独実行で3回とも再現する

## 2. ローカライズの回帰テスト（テストファースト）

- [x] 2.1 ローカライズのテストを追加し、コミットする。テストでは、アプリと同じ import（移行後は `material_ui`）とアプリと同じ delegate リストで `MaterialApp` を組み、ja / en / zh それぞれで、その `MaterialApp` の下から `MaterialLocalizations.of(context)` と `CupertinoLocalizations.of(context)` が取得でき、`okButtonLabel` などがその言語の文字列になることを確かめる。これは、material_ui のアプリに旧ライブラリの delegate がつながったまま、という状態を検出するためのテストである。完了条件：テストを追加してコミットする。移行前は通るはずで、3章の import 移行のあと（4章の前）に失敗し、4章で再び通ることを確かめる

## 3. 依存と import の移行

- [x] 3.1 `pubspec.yaml` に `material_ui` を追加する。`environment.sdk` は据え置く（design D3。上げると言語バージョンが変わり、無関係な lint と format の変更が出るため）。完了条件：`fvm flutter pub get` が成功する
- [x] 3.2 `fvm dart fix --apply --code=migrate_design_widgets` を実行し、続けて `fvm dart fix --apply` を実行する。生成ファイル `lib/l10n/app_localizations*.dart` が書き換えられた場合は、元に戻す。完了条件：`grep -rl "package:flutter/material.dart" lib test` の出力が0件になる
- [x] 3.3 fix が取りこぼした分を手で直し、`fvm dart format lib test` を実行する。手書きコードが `package:cupertino_ui/...` を import するようになった場合は、`cupertino_ui` を直接の依存に加える（design D3）。完了条件：`fvm flutter analyze` に import 起因の issue が残らない

## 4. ローカライズ delegate の移行

- [x] 4.1 非生成ファイル（例：`lib/l10n/app_localization_delegates.dart`）に、`AppLocalizations.delegate` と material_ui の `GlobalMaterialLocalizations.delegates` を合わせた delegate リストを定義する（design D2）。完了条件：2.1 のテストの参照先をこのリストに変え、テストが通る
- [x] 4.2 `lib/app.dart` と、テスト103ファイルにある `AppLocalizations.localizationsDelegates` の参照を、4.1 のリストに置き換える。完了条件：`grep -rn "AppLocalizations.localizationsDelegates" lib test` の結果が、生成ファイル `lib/l10n/app_localizations.dart` の中だけになる
- [x] 4.3 `analysis_options.yaml` の `analyzer: exclude` に `lib/l10n/app_localizations*.dart` を加え、生成物を除外する理由をコメントで残す。完了条件：`fvm flutter analyze` に l10n 起因の issue がなく、除外対象が生成ファイルだけである

## 5. 型の不一致と analyze ゼロ

- [x] 5.1 `fvm flutter analyze` で残った error / warning / info を直す。サードパーティとの型の不一致は design D4 の順に対応し、解決しなければ作業を止めてユーザーに相談する。完了条件：`fvm flutter analyze` が "No issues found!" を表示する

## 6. テスト（Green）

- [x] 6.1 `fvm flutter test` を全件実行し、失敗したテストを1件ずつ原因から直す。テストの期待値は安易に変えない。1.4 で記録したフレームワーク起因の失敗も、ここで直す。完了条件：全件成功する
- [x] 6.2 アプリを Windows で起動し、目視で確かめる（`run` スキル）。確認するのは、ホーム画面、設定ダイアログ、ダークモード、ja / en / zh の切り替え、ダイアログの OK / キャンセルの表示。完了条件：表示崩れや missing-localization のエラーがない

## 7. ドキュメントとコミット

- [x] 7.1 `.claude/CLAUDE.md` の開発コマンドに注記を加える。内容は「Flutter は stable に追随する（CI も同じ）。CI で analyze が落ちたら `fvm install stable` でローカルを更新して再現する」の2点。完了条件：差分をレビューで確認する
- [ ] 7.2 変更を英語のコミットメッセージでコミットする。依存と import の移行、l10n、修正、ドキュメントで分ける。完了条件：`git log` で確認できる

## 8. 最終確認

- [ ] 8.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 8.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 8.3 `fvm dart format lib test`でフォーマットを実行
- [ ] 8.4 `fvm flutter analyze`でリントを実行
- [ ] 8.5 `fvm flutter test`でテストを実行
- [ ] 8.6 ブランチを push して PR を作り、GitHub Actions の Test ワークフローが緑になることを確かめる。macOS / iOS の開発機で `fvm install stable` が必要なことを PR 本文に書く
