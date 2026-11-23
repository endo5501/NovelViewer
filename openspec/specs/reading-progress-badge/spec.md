## Purpose

Surface each registered novel's reading progress directly in the file browser's folder listing, so the user can see at a glance how far they have read each novel without opening it. A progress badge (progress bar plus episode count) is rendered under each registered novel folder name, derived solely from the global `novel_metadata.db` (no folder-DB access, no filesystem scan). Manually placed organizational folders are excluded.

## Requirements

### Requirement: 小説フォルダ一覧での読書進捗バッジ表示

ファイルブラウザが子フォルダ一覧を表示するとき、システムは登録済み小説フォルダ（`novels` に登録され `📖` として分類されるフォルダ）に対し、読書進捗を示す進捗バッジ（進捗バー＋話数表示）を表示しなければならない (SHALL)。バッジは小説フォルダ名の下部（`ListTile` の `subtitle` 領域）に表示しなければならない (SHALL)。手動配置フォルダ（`novels` 未登録の整理フォルダ）にはバッジを表示してはならない (MUST NOT)。

進捗バッジの分母（全話数）は `novels.episode_count` を用いなければならない (SHALL)。分子（読んだ話数）は当該小説の `reading_progress.file_name` の先頭の数字（ダウンロード命名規則 `{1始まりの話数}_{タイトル}.txt` に由来する話数）から導出しなければならない (SHALL)。進捗の意味は「現在地（最後に開いた話）」とし、到達した最大話数ではない (SHALL)。

進捗データの取得はグローバル `novel_metadata.db` のみを参照し、フォルダDB（`novel_data.db`）へアクセスしてはならず (MUST NOT)、各フォルダのファイルシステム走査を行ってはならない (MUST NOT)。

#### Scenario: 読みかけの登録済み小説に進捗が表示される
- **WHEN** ファイルブラウザに登録済み小説（`episode_count` = 120）が表示され、その `reading_progress.file_name` が `003_chapter3.txt` である
- **THEN** その小説フォルダタイルの名前の下に進捗バーと `3 / 120` が表示される
- **AND** 進捗バーは 3/120 の割合を示す

#### Scenario: 手動配置フォルダにはバッジを表示しない
- **WHEN** ファイルブラウザに `novels` 未登録の手動配置フォルダ（整理フォルダ）が表示される
- **THEN** そのフォルダタイルには進捗バッジが表示されない

#### Scenario: 前の話に戻ると現在地も戻る
- **WHEN** 登録済み小説で `reading_progress.file_name` が `010_...txt` から `002_...txt` に更新される（ユーザーが第2話を開き直す）
- **THEN** 進捗バッジは `2 / N` を表示する（最大到達話数の 10 ではない）

### Requirement: 未読の登録済み小説の進捗表示

`reading_progress` 行が存在しない登録済み小説について、システムは分母に `novels.episode_count` を用いて「`0 / N`」を表示しなければならない (SHALL)。進捗バーは 0% を示さなければならない (SHALL)。

#### Scenario: 一度も開いていない小説は 0 / N
- **WHEN** 登録済み小説（`episode_count` = 80）に `reading_progress` 行が存在しない
- **THEN** その小説フォルダタイルに `0 / 80` と 0% の進捗バーが表示される

#### Scenario: 話数情報が無い場合の堅牢性
- **WHEN** `reading_progress.file_name` の先頭から数字を取得できない
- **THEN** 分子は 0 として扱われ、表示は破綻せずクラッシュしない

### Requirement: 新着ありの小説に印を表示する

ファイルブラウザが登録済み小説の進捗バッジを表示するとき、その小説が更新チェックで「新着あり」と判定されていれば、システムはバッジに新着の印を表示しなければならない（SHALL）。判定の規則は `novel-update-check` が定める。保存された総話数が `novels.episode_count` より大きいときに限り「新着あり」になる。

印は新着の有無だけを示し、新着の話数を表示してはならない（SHALL NOT）。進捗の表示（進捗バーと `読んだ話数 / episode_count`）は、印の有無によって変わってはならない（SHALL NOT）。

印の判定は、既存のバッジと同じくグローバル `novel_metadata.db` だけを使わなければならない（SHALL）。フォルダDBへのアクセスとファイルシステムの走査をしてはならない（MUST NOT）。手動配置フォルダ（整理フォルダ）には、その中に新着ありの小説があっても印を表示してはならない（SHALL NOT）。

一度もチェックされていない小説と、チェックの対象外の小説（汎用Web、青空文庫）には、印を表示してはならない（SHALL NOT）。

更新チェックの結果が保存されたとき、または小説の更新（再ダウンロード）で `episode_count` が変わったときは、ファイル一覧を開き直さなくても印の表示が追随しなければならない（SHALL）。

#### Scenario: 新着ありの小説に印が出る
- **WHEN** `episode_count` = 120 の登録済み小説について、更新チェックで総話数 125 が保存されている
- **THEN** その小説フォルダのバッジに新着の印が表示される
- **AND** 進捗の表示は従来どおり `読んだ話数 / 120` のままである

#### Scenario: 新着が無ければ印は出ない
- **WHEN** `episode_count` = 120 の登録済み小説について、保存された総話数が 120 である
- **THEN** その小説フォルダのバッジに新着の印は表示されない

#### Scenario: 未チェックの小説には印が出ない
- **WHEN** 一度も更新チェックで総話数を取得していない登録済み小説を表示する
- **THEN** その小説フォルダのバッジに新着の印は表示されない

#### Scenario: 更新すると印が消える
- **WHEN** 新着の印が出ている小説を更新し、`episode_count` が保存された総話数に追いつく
- **THEN** ファイル一覧を開き直さなくても、その小説の印は消える

#### Scenario: チェック後すぐに印が出る
- **WHEN** ファイルブラウザを表示したまま更新チェックを実行し、ある小説が新着ありと判定される
- **THEN** ファイル一覧を開き直さなくても、その小説のバッジに印が表示される

#### Scenario: 整理フォルダには印を出さない
- **WHEN** 整理フォルダ `連載中` の中に新着ありの小説があり、ライブラリルートを表示する
- **THEN** `連載中` のフォルダタイルには新着の印が表示されない
