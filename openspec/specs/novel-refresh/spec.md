## ADDED Requirements

### Requirement: Context menu displays refresh option
ライブラリルートにおいて、小説フォルダを右クリックした際のコンテキストメニューに「更新」オプションが表示されなければならない（SHALL）。「更新」は「削除」の上に配置されなければならない（SHALL）。

#### Scenario: Right-click on novel folder at library root
- **WHEN** ユーザーがライブラリルートの小説フォルダを右クリックする
- **THEN** コンテキストメニューに「更新」と「削除」の2つのオプションが表示される

#### Scenario: Not shown outside library root
- **WHEN** ユーザーがライブラリルート以外のディレクトリ内のフォルダを右クリックする
- **THEN** コンテキストメニューは表示されない（既存動作と同一）

### Requirement: Refresh triggers download with stored URL
「更新」を選択した際、システムはフォルダ名から`NovelMetadata`を検索し、保存済みURLを使用して`DownloadNotifier.startDownload()`を呼び出さなければならない（SHALL）。

#### Scenario: Successful refresh initiation
- **WHEN** ユーザーがメタデータが存在する小説フォルダの「更新」を選択する
- **THEN** システムは保存済みURLを使用してダウンロード処理を開始する

#### Scenario: Metadata not found
- **WHEN** ユーザーがメタデータが存在しない小説フォルダの「更新」を選択する
- **THEN** システムはエラーメッセージ「小説のメタデータが見つかりません」をSnackBarで表示し、ダウンロードは開始しない

### Requirement: Refresh shows progress dialog
更新処理中、進捗状況を表示するモーダルダイアログが表示されなければならない（SHALL）。ダイアログはダウンロード状態の変化に応じてリアルタイムに更新されなければならない（SHALL）。

#### Scenario: Progress display during refresh
- **WHEN** 更新処理が実行中である
- **THEN** モーダルダイアログに現在のエピソード番号、総エピソード数、スキップ数が表示される

#### Scenario: Completion display
- **WHEN** 更新処理が正常に完了する
- **THEN** ダイアログに完了メッセージが表示され、ユーザーが閉じることができる

#### Scenario: Error display
- **WHEN** 更新処理中にエラーが発生する
- **THEN** ダイアログにエラーメッセージが表示され、ユーザーが閉じることができる

### Requirement: UI refreshes after completion
更新処理完了後、ファイル一覧とメタデータが自動的にリフレッシュされなければならない（SHALL）。

#### Scenario: File list updates after refresh
- **WHEN** 更新処理が完了し、新しいエピソードが追加された
- **THEN** ファイルブラウザのディレクトリ内容が自動的に再読み込みされ、新しいエピソードが表示される

#### Scenario: Metadata updates after refresh
- **WHEN** 更新処理が完了する
- **THEN** `allNovelsProvider`がinvalidateされ、小説メタデータ（エピソード数、更新日時）が最新の状態に更新される

### Requirement: Concurrent operation guard
ダウンロードまたは更新が既に実行中の場合、新たな更新を開始してはならない（SHALL NOT）。

#### Scenario: Refresh while download is in progress
- **WHEN** ダウンロードまたは別の更新が実行中に「更新」を選択する
- **THEN** システムはSnackBarで「ダウンロード中です。完了後に再度お試しください」と表示し、新たな更新は開始しない
