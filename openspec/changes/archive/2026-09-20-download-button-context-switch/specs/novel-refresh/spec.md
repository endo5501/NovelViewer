## MODIFIED Requirements

### Requirement: Refresh triggers download with stored URL

「更新」を選択した際、システムはフォルダ名から`NovelMetadata`を検索し、保存済みURLを使用して`DownloadNotifier.startDownload()`を呼び出さなければならない（SHALL）。再ダウンロードの保存先（`outputPath`）は、対象小説が現在物理的に存在するフォルダの親ディレクトリに解決されなければならない（SHALL）。すなわち更新は、ライブラリルート固定ではなく、対象小説の現在の物理位置へ上書きされなければならない（SHALL）。これにより、整理用サブフォルダへ保存・移動された小説を更新しても、ライブラリルート直下へ重複してダウンロードされてはならない（SHALL NOT）。

更新の呼び出し元は、対象小説フォルダの物理パスを保持しているため、その親ディレクトリを保存先として渡さなければならない（SHALL）。

更新は2つの入口から開始できる（SHALL）。ファイルブラウザで小説フォルダを右クリックして選ぶ「更新」と、表示中の小説に対する AppBar のボタンである。いずれの入口から開始されたかにかかわらず、更新の処理・保存先の解決・進捗の提示・完了後のUI再読込は同一でなければならない（SHALL）。AppBar から開始する場合の対象小説の解決規則は `download-entry-points` が定める。

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
- **THEN** システムは進捗ダイアログにエラーメッセージ「小説のメタデータが見つかりません」を表示し、ダウンロードは開始しない
- **AND** この経路はコンテキストメニューにのみ存在する。AppBar のボタンは、メタデータのある小説を表示しているときにしか更新を意味しないため（`download-entry-points` 参照）、そこから到達することはない

#### Scenario: Refresh from the app bar takes the same path

- **WHEN** ユーザーが、整理用サブフォルダ内の小説のエピソードを表示した状態で AppBar の更新ボタンを押す
- **THEN** システムは右クリックの「更新」と同じ保存先（そのサブフォルダ内の元の位置）へ上書き再ダウンロードし、同じ進捗ダイアログを表示する

### Requirement: Refresh shows progress dialog

更新処理中、進捗状況を表示するモーダルダイアログが表示されなければならない（SHALL）。ダイアログはダウンロード状態の変化に応じてリアルタイムに更新されなければならない（SHALL）。

ダウンロードの進行中、ダイアログはキャンセルアクションを提示しなければならない（SHALL）。更新は AppBar のワンタップで開始できるため、誤って開始した処理を止める手段が必要である。キャンセルの機構・状態・表示は、ダウンロードダイアログのものと同一でなければならない（SHALL）: 実行中のトークンにキャンセルを要求し、ユーザー起因のキャンセルはエラーと区別された状態として扱われ、赤いエラー表示ではなくローカライズされたキャンセルメッセージが表示される。既にダウンロード済みのエピソードは保持され、次回の更新で再開できなければならない（SHALL）。

キャンセルに用いる文字列は既存のものを再利用する。

更新は、対象小説のURLを引くために一度データベースを参照してからダウンロードを開始する。その待ち時間の間もダイアログは表示されているため、システムはこの時点でのキャンセル要求を保持し、ダウンロードを開始しないまま中断しなければならない（SHALL）。キャンセルされないまま終わった更新の要求が、次の更新に持ち越されてはならない（SHALL NOT）。

#### Scenario: Progress display during refresh
- **WHEN** 更新処理が実行中である
- **THEN** モーダルダイアログに現在のエピソード番号、総エピソード数、スキップ数が表示される

#### Scenario: Completion display
- **WHEN** 更新処理が正常に完了する
- **THEN** ダイアログに完了メッセージが表示され、ユーザーが閉じることができる

#### Scenario: Error display
- **WHEN** 更新処理中にエラーが発生する
- **THEN** ダイアログにエラーメッセージが表示され、ユーザーが閉じることができる

#### Scenario: Cancel action is offered while refreshing
- **WHEN** 更新処理が実行中である
- **THEN** ダイアログに有効なキャンセルボタンが表示される

#### Scenario: Cancelling a refresh stops it
- **WHEN** ユーザーが更新中にキャンセルボタンを押す
- **THEN** システムは実行中のダウンロードにキャンセルを要求し、ダイアログはエラーではなくキャンセルメッセージを表示し、ユーザーが閉じることができる

#### Scenario: A cancelled refresh keeps what it downloaded
- **WHEN** N話を保存した時点で更新がキャンセルされ、その後同じ小説を再度更新する
- **THEN** そのN話は再ダウンロードされずスキップされ、続きから取得される

#### Scenario: Cancelling before the download begins stops it too
- **WHEN** 更新の開始直後、対象URLの参照が完了する前にキャンセルボタンを押す
- **THEN** ダウンロードは一度も開始されず、ダイアログはキャンセルメッセージを表示する

#### Scenario: A cancel does not carry over to the next refresh
- **WHEN** 上記のキャンセルの後にダイアログを閉じ、あらためて更新を開始する
- **THEN** その更新は中断されずに進む

#### Scenario: The listing is reloaded however the refresh ended
- **WHEN** 更新がキャンセルまたは失敗で終わり、ユーザーがダイアログを閉じる
- **THEN** ファイル一覧とメタデータが再読込され、中断までに保存されたエピソードが表示される

### Requirement: Concurrent operation guard

ダウンロードまたは更新が既に実行中の場合、新たな更新を開始してはならない（SHALL NOT）。このガードは更新の入口によらず適用されなければならない（SHALL）: 右クリックの「更新」からも、AppBar のボタンからも、実行中の処理を横取りしてはならない（SHALL NOT）。

#### Scenario: Refresh while download is in progress
- **WHEN** ダウンロードまたは別の更新が実行中に「更新」を選択する
- **THEN** システムはSnackBarで「ダウンロード中です。完了後に再度お試しください」と表示し、新たな更新は開始しない

#### Scenario: App bar refresh while a download is in progress
- **WHEN** ダウンロードまたは別の更新が実行中に AppBar の更新ボタンを押す
- **THEN** システムは同じ警告をSnackBarで表示し、新たな更新は開始しない
