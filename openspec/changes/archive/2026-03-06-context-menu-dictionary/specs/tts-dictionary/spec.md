## MODIFIED Requirements

### Requirement: 辞書エントリのCRUD
システムは辞書エントリの追加・取得・更新・削除操作を提供しなければならない。各エントリは一意のIDを持ち、surface（表記）とreading（読み）のペアで構成される。同一のsurfaceが重複登録されることをDBレベルで防止しなければならない（UNIQUE制約）。

辞書ダイアログは `initialSurface` オプショナルパラメータを受け取り、指定された場合は表記入力欄にプリセット表示しなければならない。

#### Scenario: エントリを追加する
- **WHEN** `TtsDictionaryRepository.addEntry(surface, reading)` が呼ばれる
- **THEN** 新しいエントリがDBに挿入され、割り当てられたIDが返される

#### Scenario: 重複したsurfaceの登録を拒否する
- **WHEN** 既に登録されているsurfaceと同じ値で `addEntry` が呼ばれる
- **THEN** エラーがスローされる（またはUNIQUE制約違反が返される）

#### Scenario: 全エントリを取得する
- **WHEN** `TtsDictionaryRepository.getAllEntries()` が呼ばれる
- **THEN** 登録されている全エントリのリストが返される

#### Scenario: エントリを更新する
- **WHEN** `TtsDictionaryRepository.updateEntry(id, surface, reading)` が呼ばれる
- **THEN** 対象IDのエントリのsurfaceとreadingが更新される

#### Scenario: エントリを削除する
- **WHEN** `TtsDictionaryRepository.deleteEntry(id)` が呼ばれる
- **THEN** 対象IDのエントリがDBから削除される

#### Scenario: 辞書ダイアログにinitialSurfaceが渡された場合
- **WHEN** `TtsDictionaryDialog.show()` が `initialSurface` パラメータ付きで呼ばれる
- **THEN** ダイアログの表記入力欄に `initialSurface` の値がプリセットされた状態で表示される

#### Scenario: 辞書ダイアログにinitialSurfaceが渡されない場合
- **WHEN** `TtsDictionaryDialog.show()` が `initialSurface` なしで呼ばれる
- **THEN** ダイアログの表記入力欄は空の状態で表示される（既存動作と同一）

## ADDED Requirements

### Requirement: 横書き閲覧画面のコンテキストメニューに辞書追加
横書き閲覧画面（`SelectableText.rich`）のコンテキストメニューにFlutter標準のメニュー項目（コピー等）に加えて「辞書追加」メニュー項目を表示しなければならない。テキストが選択されている状態で「辞書追加」を選択すると、選択テキストが表記欄にプリセットされた辞書ダイアログが表示されなければならない。

#### Scenario: 横書きでテキスト選択後に右クリックで辞書追加が表示される
- **WHEN** 横書き閲覧画面でテキストを選択した状態でコンテキストメニューを開く
- **THEN** Flutter標準のメニュー項目に加えて「辞書追加」メニュー項目が表示される

#### Scenario: 横書きで辞書追加を選択するとダイアログが開く
- **WHEN** コンテキストメニューの「辞書追加」を選択する
- **THEN** 選択テキストが表記欄にプリセットされた辞書ダイアログが表示される

#### Scenario: 横書きで辞書ダイアログを閉じると閲覧画面に戻る
- **WHEN** 辞書ダイアログを閉じる
- **THEN** 閲覧画面に戻り、通常の閲覧操作を継続できる

### Requirement: 編集画面のコンテキストメニューに辞書追加
TTS編集画面（`TtsEditDialog`）の全TextFieldのコンテキストメニューにFlutter標準のメニュー項目に加えて「辞書追加」メニュー項目を表示しなければならない。テキストが選択されている状態で「辞書追加」を選択すると、選択テキストが表記欄にプリセットされた辞書ダイアログが表示されなければならない。

#### Scenario: 編集画面でテキスト選択後に右クリックで辞書追加が表示される
- **WHEN** TTS編集画面のTextFieldでテキストを選択した状態でコンテキストメニューを開く
- **THEN** Flutter標準のメニュー項目に加えて「辞書追加」メニュー項目が表示される

#### Scenario: 編集画面で辞書追加を選択するとダイアログが開く
- **WHEN** コンテキストメニューの「辞書追加」を選択する
- **THEN** 選択テキストが表記欄にプリセットされた辞書ダイアログが表示される

#### Scenario: 編集画面で辞書ダイアログを閉じると編集画面に戻る
- **WHEN** 辞書ダイアログを閉じる
- **THEN** TTS編集画面に戻り、通常の編集操作を継続できる
