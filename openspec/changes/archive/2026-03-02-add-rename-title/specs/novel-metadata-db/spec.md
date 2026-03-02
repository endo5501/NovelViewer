## ADDED Requirements

### Requirement: Update novel title by folder name
NovelRepositoryはフォルダ名を指定してタイトルのみを更新するメソッドを提供しなければならない（SHALL）。

#### Scenario: Update title for existing novel
- **WHEN** NovelRepository.updateTitle(folderName, newTitle)が呼び出される
- **AND** 指定されたfolder_nameのレコードが存在する
- **THEN** 該当レコードのtitleフィールドが新しいタイトルに更新される
- **AND** updated_atフィールドが現在日時に更新される

#### Scenario: Update title for non-existent novel
- **WHEN** NovelRepository.updateTitle(folderName, newTitle)が呼び出される
- **AND** 指定されたfolder_nameのレコードが存在しない
- **THEN** 例外がスローされる
