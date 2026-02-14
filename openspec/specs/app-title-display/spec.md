### Requirement: AppBarに選択中の小説タイトルを表示する
AppBarのタイトル領域は、現在のディレクトリ状態に基づいて動的にテキストを表示しなければならない（SHALL）。小説フォルダ内（またはそのサブディレクトリ内）を閲覧中の場合、その小説のタイトルを表示しなければならない（SHALL）。

#### Scenario: ライブラリルートにいるとき
- **WHEN** 現在のディレクトリがライブラリルートである
- **THEN** AppBarのタイトルは「NovelViewer」と表示される

#### Scenario: 小説フォルダを選択しているとき
- **WHEN** ユーザーがライブラリルート直下の小説フォルダに移動した
- **THEN** AppBarのタイトルはその小説のメタデータに登録されたタイトルを表示する

#### Scenario: 小説フォルダのサブディレクトリにいるとき
- **WHEN** ユーザーが小説フォルダ内のサブディレクトリに移動した
- **THEN** AppBarのタイトルは親の小説のメタデータに登録されたタイトルを表示する

#### Scenario: メタデータが未登録の小説フォルダにいるとき
- **WHEN** ユーザーがデータベースにメタデータが存在しないフォルダに移動した
- **THEN** AppBarのタイトルはフォルダ名を表示する

### Requirement: 選択中の小説タイトルをProviderで提供する
`currentDirectoryProvider` と `libraryPathProvider` のパス情報、および `allNovelsProvider` のメタデータから、現在選択中の小説タイトルを導出するProviderを提供しなければならない（SHALL）。

#### Scenario: ライブラリルートにいるとき
- **WHEN** 現在のディレクトリがライブラリルートと一致する
- **THEN** Providerはnullを返す

#### Scenario: 小説フォルダ内にいるとき
- **WHEN** 現在のディレクトリがライブラリルート配下のフォルダ内である
- **AND** そのフォルダ名に一致するメタデータが存在する
- **THEN** Providerはメタデータの `title` を返す

#### Scenario: メタデータが存在しないフォルダにいるとき
- **WHEN** 現在のディレクトリがライブラリルート配下のフォルダ内である
- **AND** そのフォルダ名に一致するメタデータが存在しない
- **THEN** Providerはフォルダ名を返す

#### Scenario: ディレクトリが未選択のとき
- **WHEN** `currentDirectoryProvider` がnullである
- **THEN** Providerはnullを返す
