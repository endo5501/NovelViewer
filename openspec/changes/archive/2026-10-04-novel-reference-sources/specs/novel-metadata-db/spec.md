# Spec Delta

## ADDED Requirements

### Requirement: v10→v11 で参照元関係のテーブルを追加する

システムは、`novel_metadata.db` をスキーマバージョン 11 に上げなければならない（SHALL）。v10→v11 の昇格では、参照元関係を保存するテーブルを作成しなければならない（SHALL）。このテーブルは子と親の `folder_name` の組を保持し、同じ組が重複しない一意性を持つ。

既存のテーブル（`novels`、`reading_progress` など）とその行には、一切手を触れてはならない（SHALL NOT）。新規作成と昇格は、同じテーブル定義を経由しなければならない（SHALL）。昇格後のスキーマは、新規作成した v11 のスキーマと一致しなければならない（SHALL）。

#### Scenario: v10 のDBが昇格される
- **WHEN** `user_version=10` の `novel_metadata.db` でアプリを起動する
- **THEN** 参照元関係のテーブルが作成され、`user_version` は 11 になる
- **AND** `novels` と `reading_progress` の行はすべて保持される

#### Scenario: 昇格後のスキーマが新規作成と一致する
- **WHEN** v10 から昇格した DB と、新規作成した v11 の DB のスキーマを比較する
- **THEN** 参照元関係のテーブルの定義と一意インデックスが一致する

#### Scenario: 同じ組は重複しない
- **WHEN** 同じ子と親の組を2回保存しようとする
- **THEN** テーブルには1行だけが存在する
