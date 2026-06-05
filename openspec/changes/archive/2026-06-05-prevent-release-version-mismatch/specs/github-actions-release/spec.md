## ADDED Requirements

### Requirement: タグと pubspec.yaml の version 整合性を検証する
リリースワークフローは、ビルドを開始する前に、トリガとなったタグと `pubspec.yaml` の `version` が一致することを検証しなければならない（SHALL）。比較は、タグ名の先頭 `v` を除いた値（例: `v1.2.0` → `1.2.0`）と、`pubspec.yaml` の `version` からビルドメタ（`+N`）を除いた値（例: `1.2.0+4` → `1.2.0`）で行わなければならない（MUST）。両者が一致しない場合、ワークフローは非ゼロ終了コードで失敗し、それ以降のビルド・パッケージング・Release 公開を一切行ってはならない（MUST NOT）。この検証ステップは、ビルドを伴ういずれのステップよりも前に配置しなければならない（MUST）。

#### Scenario: タグと version が一致する場合は続行
- **WHEN** タグ `v1.2.0` が push され、`pubspec.yaml` が `version: 1.2.0+4` である
- **THEN** 検証ステップは成功し、ワークフローはビルドステップへ進む

#### Scenario: タグと version が不一致の場合は失敗
- **WHEN** タグ `v1.2.0` が push されたが、`pubspec.yaml` が `version: 1.1.0+3` のままである
- **THEN** 検証ステップが非ゼロ終了コードで失敗し、ビルド・Release 公開は行われず、GitHub Actions の UI で不一致が原因と確認できる

#### Scenario: 検証はビルドより前に実行される
- **WHEN** ワークフローが発火する
- **THEN** タグと version の整合性検証は `flutter build windows` を含むいかなるビルドステップよりも前に実行される
