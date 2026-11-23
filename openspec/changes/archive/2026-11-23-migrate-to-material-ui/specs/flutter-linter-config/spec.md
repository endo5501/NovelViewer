## MODIFIED Requirements

### Requirement: リンター実行がゼロ警告で完了する

すべての修正が完了した状態で `flutter analyze` を実行した場合、error、warning、info のいずれも0件でなければならない（MUST）。CI の `flutter analyze` は info も失敗として扱うため、info も許容しない。
基準にする Flutter は、CI が使うのと同じ stable チャンネルの最新版とする。CI は stable のバージョンを固定しない（SHALL NOT）。新しい stable で入った非推奨（`deprecated_member_use` など）は、検出された時点で修正の対象になる。

#### Scenario: リンターがクリーンに完了する
- **WHEN** すべてのリント違反を修正したあと、最新の stable で `fvm flutter analyze` を実行する
- **THEN** "No issues found!" と表示される

#### Scenario: 非推奨 API の info も残らない
- **WHEN** 最新の stable で `flutter analyze` を実行する
- **THEN** `deprecated_member_use` を含め、info レベルの issue が1件も報告されない

#### Scenario: CI が最新 stable で analyze する
- **WHEN** `.github/workflows/test.yml` の Flutter のセットアップを確認する
- **THEN** 固定したバージョンではなく `channel: stable` が指定されている

## ADDED Requirements

### Requirement: 生成されたローカライズファイルだけを analyze の対象から外す

`analysis_options.yaml` の `analyzer: exclude` には、`flutter gen-l10n` の生成物 `lib/l10n/app_localizations*.dart` を加えなければならない（MUST）。生成テンプレートは Flutter 3.50 時点でも非推奨の delegate を出力し、手で直しても再生成で上書きされるためである。手書きの Dart ファイルを exclude に加えてはならない（MUST NOT）。

#### Scenario: 生成ファイルが除外されている
- **WHEN** `analysis_options.yaml` を確認する
- **THEN** `analyzer: exclude` に `lib/l10n/app_localizations*.dart` が含まれている

#### Scenario: 手書きコードは除外されていない
- **WHEN** `analysis_options.yaml` の `analyzer: exclude` を確認する
- **THEN** `lib/` と `test/` のうち、生成ファイル以外を除外するパターンが含まれていない
