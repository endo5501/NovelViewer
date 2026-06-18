## MODIFIED Requirements

### Requirement: Refresh triggers download with stored URL

「更新」を選択した際、システムはフォルダ名から`NovelMetadata`を検索し、保存済みURLを使用して`DownloadNotifier.startDownload()`を呼び出さなければならない（SHALL）。再ダウンロードの保存先（`outputPath`）は、対象小説が現在物理的に存在するフォルダの親ディレクトリに解決されなければならない（SHALL）。すなわち更新は、ライブラリルート固定ではなく、対象小説の現在の物理位置へ上書きされなければならない（SHALL）。これにより、整理用サブフォルダへ保存・移動された小説を更新しても、ライブラリルート直下へ重複してダウンロードされてはならない（SHALL NOT）。

更新の呼び出し元は、対象小説フォルダの物理パスを保持しているため、その親ディレクトリを保存先として渡さなければならない（SHALL）。

#### Scenario: Successful refresh initiation

- **WHEN** ユーザーがメタデータが存在する小説フォルダの「更新」を選択する
- **THEN** システムは保存済みURLを使用してダウンロード処理を開始する

#### Scenario: Refresh of a novel at library root

- **WHEN** ライブラリルート直下にある小説フォルダ（`<library_root>/{siteType}_{novelId}/`）の「更新」を選択する
- **THEN** システムは同じ場所（ライブラリルート直下）へ上書き再ダウンロードする

#### Scenario: Refresh of a novel inside a subfolder writes back to that subfolder

- **WHEN** 整理用サブフォルダ内の小説フォルダ（`<library_root>/完結済み/異世界/{siteType}_{novelId}/`）の「更新」を選択する
- **THEN** システムは同じサブフォルダ内の元の位置へ上書き再ダウンロードし、ライブラリルート直下に重複フォルダを作成しない

#### Scenario: Metadata not found

- **WHEN** ユーザーがメタデータが存在しない小説フォルダの「更新」を選択する
- **THEN** システムはエラーメッセージ「小説のメタデータが見つかりません」をSnackBarで表示し、ダウンロードは開始しない
