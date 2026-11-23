## Purpose

`analysis_options.yaml` に追加のFlutter/Dartリントルール（const 推奨, 単一引用符, build_context_synchronously 等）を有効化し、既存違反の修正と `flutter analyze` のゼロ警告達成、既存テストの維持を保証する。

## Requirements

### Requirement: analysis_options.yaml に追加リントルールを設定する

`analysis_options.yaml` の `linter: rules:` セクションに、`flutter_lints` のデフォルトルールセットに加えて以下の追加ルールを有効化（`true` に設定）しなければならない（SHALL）:

- `prefer_const_constructors`
- `prefer_const_declarations`
- `prefer_final_locals`
- `avoid_print`
- `prefer_single_quotes`
- `sort_child_properties_last`
- `use_build_context_synchronously`

既存の `include: package:flutter_lints/flutter.yaml` と `analyzer: exclude:` 設定は維持しなければならない（MUST）。

#### Scenario: 追加ルールが有効化されている
- **WHEN** `analysis_options.yaml` を確認する
- **THEN** `linter: rules:` セクションに上記7つのルールがすべて `true` で設定されている

#### Scenario: 既存設定が維持されている
- **WHEN** `analysis_options.yaml` を確認する
- **THEN** `include: package:flutter_lints/flutter.yaml` が含まれている
- **THEN** `analyzer: exclude:` に `memo/**` と `openspec/**` が含まれている

### Requirement: 既存のリント違反を修正する

追加ルール適用前に検出されている既存の警告をすべて修正しなければならない（MUST）:
- `unused_import`（`lib/features/file_browser/presentation/file_browser_panel.dart`）
- `unused_field`（`lib/features/text_download/data/sites/kakuyomu_site.dart`）

追加ルール適用後に新たに検出される違反もできる限り修正しなければならない（SHALL）。修正が既存の機能テストを破壊する場合や、修正の影響範囲が大きすぎる場合は `// ignore` コメントで個別に抑制してもよい。

#### Scenario: 既存の警告がゼロになる
- **WHEN** `fvm flutter analyze` を実行する
- **THEN** 既存の `unused_import` と `unused_field` の警告が表示されない

#### Scenario: 追加ルールによる違反が修正されている
- **WHEN** 追加リントルールを有効化した状態で `fvm flutter analyze` を実行する
- **THEN** warning と error の件数がゼロである、または修正不可能な箇所のみ `// ignore` コメントで抑制されている

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

### Requirement: 既存テストがすべてパスする

リント違反の修正はコードのロジックを変更してはならない（MUST NOT）。すべての既存テストが修正後もパスしなければならない（MUST）。

#### Scenario: テストが全件パスする
- **WHEN** リント違反修正後に `fvm flutter test` を実行する
- **THEN** すべてのテストが成功する（失敗件数がゼロ）

### Requirement: 生成されたローカライズファイルだけを analyze の対象から外す

`analysis_options.yaml` の `analyzer: exclude` には、`flutter gen-l10n` の生成物 `lib/l10n/app_localizations*.dart` を加えなければならない（MUST）。生成テンプレートは Flutter 3.50 時点でも非推奨の delegate を出力し、手で直しても再生成で上書きされるためである。手書きの Dart ファイルを exclude に加えてはならない（MUST NOT）。

#### Scenario: 生成ファイルが除外されている
- **WHEN** `analysis_options.yaml` を確認する
- **THEN** `analyzer: exclude` に `lib/l10n/app_localizations*.dart` が含まれている

#### Scenario: 手書きコードは除外されていない
- **WHEN** `analysis_options.yaml` の `analyzer: exclude` を確認する
- **THEN** `lib/` と `test/` のうち、生成ファイル以外を除外するパターンが含まれていない
