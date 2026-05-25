## ADDED Requirements

### Requirement: 隣接ファイル導出 Provider
システムは、現在の閲覧ディレクトリ内のテキストファイル並びと選択中ファイルから、「次のファイル」「前のファイル」を導出する Riverpod provider を提供しなければならない（SHALL）。並びは `file-browser` capability の数値プレフィックスソート（`sortByNumericPrefix`）と一致しなければならない（SHALL）。導出結果はテキスト拡張子（`.txt`）のファイルのみを対象とし、サブディレクトリは含まない。

#### Scenario: 中間ファイルが選択されているとき
- **WHEN** 同一ディレクトリ内に 5 つのテキストファイル（数値プレフィックスでソート済み）があり、3 番目が選択されている
- **THEN** Provider は「次のファイル」として 4 番目の `FileEntry` を返し、「前のファイル」として 2 番目の `FileEntry` を返す

#### Scenario: 先頭ファイルが選択されているとき
- **WHEN** 同一ディレクトリ内に 5 つのテキストファイルがあり、1 番目が選択されている
- **THEN** Provider は「次のファイル」として 2 番目の `FileEntry` を返し、「前のファイル」として `null` を返す

#### Scenario: 末尾ファイルが選択されているとき
- **WHEN** 同一ディレクトリ内に 5 つのテキストファイルがあり、5 番目が選択されている
- **THEN** Provider は「次のファイル」として `null` を返し、「前のファイル」として 4 番目の `FileEntry` を返す

#### Scenario: 唯一のファイルが選択されているとき
- **WHEN** 同一ディレクトリ内にテキストファイルが 1 つしかなく、それが選択されている
- **THEN** Provider は「次のファイル」「前のファイル」ともに `null` を返す

#### Scenario: ファイルが選択されていないとき
- **WHEN** `selectedFileProvider` が `null` である
- **THEN** Provider は「次のファイル」「前のファイル」ともに `null` を返す

#### Scenario: 選択ファイルがディレクトリ内に見つからないとき
- **WHEN** `selectedFileProvider` の値が `directoryContentsProvider` のファイル一覧に含まれていない（例: ディレクトリが切り替わった直後の過渡状態）
- **THEN** Provider は「次のファイル」「前のファイル」ともに `null` を返す

### Requirement: ファイル切替時の開始位置 Intent Provider
システムは、ファイル切替時の開始位置ヒント（コンテンツ冒頭から開始するか、末尾から開始するか）を一時的に保持する Riverpod `NotifierProvider` を提供しなければならない（SHALL）。ヒントは列挙型 `FileEntryStartIntent` で表現し、少なくとも `fromStart`（冒頭）と `fromEnd`（末尾）の 2 値を持たなければならない（SHALL）。初期値は `null` でなければならない（SHALL）。

Provider は、開始位置ヒントの設定（set）、取得（read）、クリア（clear → `null` に戻す）の操作を提供しなければならない（SHALL）。ヒントは「次回のファイル開始時にビューア側で 1 度だけ消費される」ワンショットセマンティクスを持ち、消費後はビューア側が明示的にクリアする責務を負う（SHALL）。

#### Scenario: 初期状態
- **WHEN** アプリケーション起動直後で Provider に対する操作がまだ行われていない
- **THEN** Provider の値は `null` である

#### Scenario: 末尾から開始ヒントを設定
- **WHEN** `pendingFileEntryIntentProvider.notifier.set(FileEntryStartIntent.fromEnd)` が呼ばれる
- **THEN** Provider の値は `FileEntryStartIntent.fromEnd` に更新される

#### Scenario: ヒントのクリア
- **WHEN** `FileEntryStartIntent.fromEnd` が設定された状態で `pendingFileEntryIntentProvider.notifier.clear()` が呼ばれる
- **THEN** Provider の値は `null` に戻る

#### Scenario: ヒントの上書き
- **WHEN** `FileEntryStartIntent.fromStart` が設定された状態で `FileEntryStartIntent.fromEnd` を新たに設定する
- **THEN** Provider の値は `FileEntryStartIntent.fromEnd` で上書きされる

### Requirement: 隣接ファイルへの遷移は intent と選択を同時に更新する
システムは、隣接ファイル（次／前）へ遷移するためのヘルパー関数または Notifier 操作を提供しなければならない（SHALL）。当該操作は、`pendingFileEntryIntentProvider` への開始位置ヒント設定と `selectedFileProvider` のファイル選択を、ビューアが選択変化を検知する前に同期的に完了させなければならない（SHALL）。これは、ビューアが新しいファイルの最初の build 時点で intent を読み取れることを保証するためである。

#### Scenario: 次話への遷移（冒頭開始）
- **WHEN** 次話遷移操作が呼ばれ、次のファイルが存在する
- **THEN** `pendingFileEntryIntentProvider` に `FileEntryStartIntent.fromStart` が設定され、その後 `selectedFileProvider` が次のファイルに切り替わる

#### Scenario: 前話への遷移（末尾開始）
- **WHEN** 前話遷移操作が呼ばれ、前のファイルが存在する
- **THEN** `pendingFileEntryIntentProvider` に `FileEntryStartIntent.fromEnd` が設定され、その後 `selectedFileProvider` が前のファイルに切り替わる

#### Scenario: 隣接ファイルが存在しないとき
- **WHEN** 末尾ファイルを開いた状態で次話遷移操作が呼ばれる
- **THEN** `pendingFileEntryIntentProvider` も `selectedFileProvider` も変化しない（no-op）
