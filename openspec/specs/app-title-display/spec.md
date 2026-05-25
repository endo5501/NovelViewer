## Purpose

AppBarのタイトルを現在のディレクトリ状態に応じて動的に切り替える。小説フォルダ（およびそのサブディレクトリ）配下では小説メタデータの `title` を表示し、メタデータがなければフォルダ名、ライブラリルートでは「NovelViewer」を表示する。

## Requirements

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

### Requirement: AppBar に現在ファイル名と話数進捗を表示する
小説フォルダ配下を閲覧中、かつテキストファイルが選択されている場合、AppBar のタイトル領域は「小説タイトル — `ファイル名` (`現在話数`/`総話数`)」形式で表示しなければならない（SHALL）。

- `小説タイトル` は既存の「Requirement: AppBarに選択中の小説タイトルを表示する」と同じく `selectedNovelTitleProvider` から導出する。
- `ファイル名` は `selectedFileProvider` の `FileEntry.name` をそのまま使う（拡張子を含む）。
- `現在話数` は、現在ディレクトリの数値プレフィックスソート済みファイル一覧における選択ファイルの 1-based インデックス。
- `総話数` は、現在ディレクトリのテキストファイル数。
- セパレータは em-dash `—`（U+2014）、進捗は半角括弧 ` (N/M)` を使う。

ファイル一覧が空、または `selectedFileProvider` が `null` の場合、AppBar タイトルは既存挙動（小説タイトルまたは「NovelViewer」のみ）を維持しなければならない（SHALL）。

タイトル全体は単一行で表示し、長さがウィンドウ幅を超える場合は省略記号（`TextOverflow.ellipsis`）で末尾を切り詰めなければならない（SHALL）。

#### Scenario: 小説フォルダ内でファイルを選択しているとき
- **WHEN** ユーザーが小説タイトル「異世界転生」のフォルダ内で `049-戦闘.txt`（並び順 49 番目、総数 200 ファイル）を選択している
- **THEN** AppBar のタイトルは「異世界転生 — 049-戦闘.txt (49/200)」と表示される

#### Scenario: 小説フォルダ内でファイル未選択のとき
- **WHEN** ユーザーが小説タイトル「異世界転生」のフォルダ内でファイルを選択していない
- **THEN** AppBar のタイトルは「異世界転生」のみが表示される

#### Scenario: メタデータ未登録フォルダ内でファイルを選択しているとき
- **WHEN** ユーザーがメタデータ未登録のフォルダ「unknown_novel」内で `001-序章.txt`（並び順 1 番目、総数 3 ファイル）を選択している
- **THEN** AppBar のタイトルは「unknown_novel — 001-序章.txt (1/3)」と表示される

#### Scenario: ライブラリルートにいるとき
- **WHEN** 現在のディレクトリがライブラリルートである
- **THEN** AppBar のタイトルは「NovelViewer」と表示される（ファイル名や進捗は付与されない）

#### Scenario: タイトルがウィンドウ幅を超えるとき
- **WHEN** 小説タイトル＋ファイル名＋進捗の合計文字数が AppBar の表示幅を超える
- **THEN** タイトルは単一行で表示され、末尾が省略記号で切り詰められる

### Requirement: ファイル進捗付きタイトルを Provider で提供する
システムは、`selectedNovelTitleProvider`、`directoryContentsProvider`、`selectedFileProvider` を組み合わせて、上記の「小説タイトル — ファイル名 (N/M)」形式の文字列を導出する派生 Provider を提供しなければならない（SHALL）。AppBar の Widget はこの派生 Provider のみを参照し、組み立てロジックを Widget 内に持ってはならない（SHALL NOT）。

#### Scenario: 派生 Provider が組み立てを担う
- **WHEN** AppBar の Widget がタイトル表示用 Provider を watch する
- **THEN** Widget はその文字列値をそのまま `Text` ウィジェットに渡すだけでよく、ファイル名や進捗の合成を Widget 内で行わない

#### Scenario: 依存 Provider の変化で派生 Provider が再計算される
- **WHEN** `selectedFileProvider` の値が変わる
- **THEN** 派生 Provider は新しいファイル名と進捗インデックスを反映した文字列を返す
