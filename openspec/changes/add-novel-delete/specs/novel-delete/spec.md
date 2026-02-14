## ADDED Requirements

### Requirement: Context menu on novel folder
ライブラリルートでの小説フォルダ表示時、フォルダのListTileを右クリック（セカンダリタップ）すると「削除」オプションを含むコンテキストメニューが表示されなければならない（SHALL）。

#### Scenario: Right-click on novel folder at library root
- **WHEN** ユーザーがライブラリルートで小説フォルダを右クリックする
- **THEN** 「削除」オプションを含むコンテキストメニューが表示される

#### Scenario: No context menu inside novel folder
- **WHEN** ユーザーが小説フォルダ内のエピソードファイルを右クリックする
- **THEN** コンテキストメニューは表示されない

### Requirement: Delete confirmation dialog
「削除」メニュー項目を選択した際、小説タイトルを含む確認ダイアログが表示されなければならない（SHALL）。ダイアログには「削除」（赤色）と「キャンセル」ボタンを配置しなければならない（SHALL）。

#### Scenario: Show confirmation dialog
- **WHEN** ユーザーがコンテキストメニューの「削除」を選択する
- **THEN** 小説タイトルを含む確認ダイアログが表示される
- **AND** 「削除」ボタンが赤色で表示される
- **AND** 「キャンセル」ボタンが表示される

#### Scenario: Cancel deletion
- **WHEN** ユーザーが確認ダイアログで「キャンセル」を選択する
- **THEN** ダイアログが閉じる
- **AND** 小説データは変更されない

### Requirement: Novel deletion cleans up all data
確認ダイアログで「削除」を選択した際、以下の3つのデータソースからデータが削除されなければならない（SHALL）: novelsテーブルのレコード、word_summariesテーブルの該当フォルダの全レコード、ファイルシステムの小説フォルダ。

#### Scenario: Successful deletion
- **WHEN** ユーザーが確認ダイアログで「削除」を選択する
- **THEN** novelsテーブルから該当レコードが削除される
- **AND** word_summariesテーブルから該当folder_nameの全レコードが削除される
- **AND** ファイルシステムから小説フォルダが再帰的に削除される

#### Scenario: Deletion order
- **WHEN** 削除処理が実行される
- **THEN** DBレコードの削除がファイルシステム削除より先に実行される

### Requirement: UI refresh after deletion
削除完了後、ファイルブラウザのUIが自動更新され、削除された小説がリストから消えなければならない（SHALL）。

#### Scenario: File browser updates after deletion
- **WHEN** 小説の削除が完了する
- **THEN** ファイルブラウザの小説一覧が自動的に更新される
- **AND** 削除された小説がリストに表示されない

### Requirement: NovelDeleteService orchestration
削除処理はNovelDeleteServiceに集約されなければならない（SHALL）。このサービスはNovelRepository、LlmSummaryRepository、FileSystemServiceの削除メソッドを呼び出す。

#### Scenario: Service coordinates deletion across layers
- **WHEN** NovelDeleteService.delete(folderName)が呼び出される
- **THEN** NovelRepository.deleteByFolderName()でDBレコードが削除される
- **AND** word_summariesテーブルから該当フォルダの全レコードが削除される
- **AND** FileSystemServiceでフォルダが削除される
