## Purpose

ライブラリ画面の右クリックメニューから小説タイトルを変更する機能。現在のタイトルがプリフィルされたダイアログでバリデーション（空文字禁止）を行い、novels テーブルの `title` カラムだけを更新（フォルダ名は変えない）し、ファイルブラウザを自動更新する。

## Requirements

### Requirement: Rename title dialog
ユーザーがコンテキストメニューから「タイトル変更」を選択した際、タイトル変更ダイアログが表示されなければならない（SHALL）。ダイアログには現在のタイトルがプリフィルされたTextFieldと、「変更」「キャンセル」ボタンを配置しなければならない（SHALL）。

#### Scenario: Show rename dialog with current title
- **WHEN** ユーザーがコンテキストメニューの「タイトル変更」を選択する
- **THEN** ダイアログが表示される
- **AND** TextFieldに現在のタイトルが入力された状態で表示される
- **AND** 「変更」ボタンと「キャンセル」ボタンが表示される

#### Scenario: Cancel rename
- **WHEN** ユーザーがタイトル変更ダイアログで「キャンセル」を選択する
- **THEN** ダイアログが閉じる
- **AND** タイトルは変更されない

### Requirement: Title validation
空文字列のタイトルは許可してはならない（SHALL NOT）。TextFieldが空の場合、「変更」ボタンは無効化されなければならない（SHALL）。

#### Scenario: Empty title disables submit button
- **WHEN** ユーザーがTextFieldの内容をすべて削除する
- **THEN** 「変更」ボタンが無効化（グレーアウト）される

#### Scenario: Non-empty title enables submit button
- **WHEN** ユーザーがTextFieldに1文字以上入力する
- **THEN** 「変更」ボタンが有効化される

### Requirement: Title update persists to database
「変更」ボタンを押した際、新しいタイトルがnovelsテーブルのtitleフィールドに保存されなければならない（SHALL）。フォルダ名は変更されない。

#### Scenario: Successful title update
- **WHEN** ユーザーが新しいタイトルを入力し「変更」ボタンを押す
- **THEN** novelsテーブルの該当レコードのtitleフィールドが新しいタイトルに更新される
- **AND** folder_nameフィールドは変更されない

### Requirement: UI refresh after title change
タイトル変更後、ファイルブラウザの表示が自動的に更新され、新しいタイトルが即座に反映されなければならない（SHALL）。

#### Scenario: File browser shows updated title
- **WHEN** タイトル変更が完了する
- **THEN** ファイルブラウザの小説一覧が自動的に更新される
- **AND** 変更された小説のタイトルが新しいタイトルで表示される
