## ADDED Requirements

### Requirement: リリーススクリプトによる一括リリース実行
リポジトリは、リリース手順（バージョン更新・commit・タグ付け・push）を一括実行するスクリプトを提供しなければならない（SHALL）。PowerShell 用 `scripts/release.ps1` と bash 用 `scripts/release.sh` の双方を提供しなければならない（SHALL）。両スクリプトは唯一の必須引数として対象バージョン `X.Y.Z`（SemVer の major.minor.patch）を受け取らなければならない（MUST）。

#### Scenario: 正常なリリース実行
- **WHEN** clean な作業ツリーかつ `main` ブランチで `scripts/release.ps1 1.2.0`（または `scripts/release.sh 1.2.0`）を実行する
- **THEN** `pubspec.yaml` の `version` が `1.2.0+<N+1>` に更新され、その変更が commit され、タグ `v1.2.0` が作成され、main ブランチとタグが push される

#### Scenario: 引数なしで実行
- **WHEN** バージョン引数を与えずにスクリプトを実行する
- **THEN** スクリプトは使用方法を表示して非ゼロ終了コードで終了し、リポジトリに変更を加えない

### Requirement: リリース前の事前検証
スクリプトは、いずれかの変更を加える前に以下をすべて検証しなければならない（MUST）。検証に 1 つでも失敗した場合、`pubspec.yaml` の変更・commit・タグ付け・push のいずれも行わず、原因を示すメッセージとともに非ゼロ終了コードで終了しなければならない（MUST）。

- 引数が `X.Y.Z` 形式（各要素が整数）であること
- 作業ツリーが clean（未コミットの変更・ステージ済み変更がない）であること
- 現在のブランチが `main` であること
- タグ `vX.Y.Z` がローカル・リモートのいずれにも未使用であること
- 新バージョンが現 `pubspec.yaml` の version より大きい（後退でない）こと

#### Scenario: バージョン形式が不正
- **WHEN** `scripts/release.sh 1.2`（または `v1.2.0`、`1.2.0-beta` 等）を実行する
- **THEN** 形式エラーを表示して非ゼロ終了し、リポジトリに変更を加えない

#### Scenario: 作業ツリーが dirty
- **WHEN** 未コミットの変更がある状態でスクリプトを実行する
- **THEN** 作業ツリーが clean でない旨を表示して非ゼロ終了し、commit やタグ付けを行わない

#### Scenario: main 以外のブランチ
- **WHEN** `main` 以外のブランチでスクリプトを実行する
- **THEN** ブランチが `main` でない旨を表示して非ゼロ終了し、変更を加えない

#### Scenario: タグが既に存在する
- **WHEN** すでに `v1.2.0` タグが存在する状態で `scripts/release.sh 1.2.0` を実行する
- **THEN** タグが既存である旨を表示して非ゼロ終了し、変更を加えない

#### Scenario: バージョンの後退
- **WHEN** `pubspec.yaml` の version が `1.2.0+3` の状態で `scripts/release.sh 1.1.0` を実行する
- **THEN** バージョンが後退している旨を表示して非ゼロ終了し、変更を加えない

### Requirement: ビルド番号の単調増加
スクリプトは `pubspec.yaml` の version を `X.Y.Z+N` 形式で書き込み、ビルド番号 `N` は現在の `pubspec.yaml` のビルド番号に 1 を加えた値でなければならない（MUST）。ビルド番号は更新判定には影響しない（表示用）。

#### Scenario: ビルド番号のインクリメント
- **WHEN** 現 `pubspec.yaml` が `version: 1.1.0+3` で `scripts/release.sh 1.2.0` を実行する
- **THEN** `pubspec.yaml` の version は `1.2.0+4` に更新される
