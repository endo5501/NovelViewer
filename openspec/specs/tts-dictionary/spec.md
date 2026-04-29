## Purpose

小説ごとのTTS読み上げ辞書機能。表記と読みのペアを `tts_dictionary.db` に永続化し、TTS入力テキスト生成時に自動変換を提供する。

## Requirements

### Requirement: 辞書データベースの初期化
システムは小説フォルダ内に `tts_dictionary.db` という名前のSQLiteデータベースを作成し、`tts_dictionary` テーブルで表記（surface）と読み（reading）のペアを管理しなければならない (MUST)。テーブルが存在しない場合は自動的に作成されなければならない。

#### Scenario: 初回アクセスでDBが作成される
- **WHEN** `TtsDictionaryDatabase` がまだ存在しないフォルダパスで初期化される
- **THEN** `tts_dictionary.db` が当該フォルダに作成され、`tts_dictionary` テーブルが生成される

#### Scenario: 既存DBへの再接続
- **WHEN** `TtsDictionaryDatabase` が既存の `tts_dictionary.db` を持つフォルダで初期化される
- **THEN** 既存のデータを失わずにDBに接続される

### Requirement: 辞書エントリのCRUD
システムは辞書エントリの追加・取得・更新・削除操作を提供しなければならない (MUST)。各エントリは一意のIDを持ち、surface（表記）とreading（読み）のペアで構成される。同一のsurfaceが重複登録されることをDBレベルで防止しなければならない（UNIQUE制約）。

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

### Requirement: 横書き閲覧画面のコンテキストメニューに辞書追加
横書き閲覧画面（`SelectableText.rich`）のコンテキストメニューにFlutter標準のメニュー項目（コピー等）に加えて「辞書追加」メニュー項目を表示しなければならない (MUST)。テキストが選択されている状態で「辞書追加」を選択すると、選択テキストが表記欄にプリセットされた辞書ダイアログが表示されなければならない。

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
TTS編集画面（`TtsEditDialog`）の全TextFieldのコンテキストメニューにFlutter標準のメニュー項目に加えて「辞書追加」メニュー項目を表示しなければならない (MUST)。テキストが選択されている状態で「辞書追加」を選択すると、選択テキストが表記欄にプリセットされた辞書ダイアログが表示されなければならない。

#### Scenario: 編集画面でテキスト選択後に右クリックで辞書追加が表示される
- **WHEN** TTS編集画面のTextFieldでテキストを選択した状態でコンテキストメニューを開く
- **THEN** Flutter標準のメニュー項目に加えて「辞書追加」メニュー項目が表示される

#### Scenario: 編集画面で辞書追加を選択するとダイアログが開く
- **WHEN** コンテキストメニューの「辞書追加」を選択する
- **THEN** 選択テキストが表記欄にプリセットされた辞書ダイアログが表示される

#### Scenario: 編集画面で辞書ダイアログを閉じると編集画面に戻る
- **WHEN** 辞書ダイアログを閉じる
- **THEN** TTS編集画面に戻り、通常の編集操作を継続できる

### Requirement: テキスト変換
システムは辞書エントリを使ってテキスト文字列の変換を行う `applyDictionary(text)` メソッドを提供しなければならない (MUST)。変換は最長一致優先で行い、辞書エントリのsurface長の降順でテキストを走査して置換しなければならない。

#### Scenario: 辞書エントリが適用される
- **WHEN** `applyDictionary("山田太郎は強い")` が呼ばれ、辞書に `{surface: "山田太郎", reading: "やまだたろう"}` が登録されている
- **THEN** `"やまだたろうは強い"` が返される

#### Scenario: 最長一致が優先される
- **WHEN** `applyDictionary("山田太郎")` が呼ばれ、辞書に `{surface: "山田", reading: "やまだ"}` と `{surface: "山田太郎", reading: "やまだたろう"}` の両方が登録されている
- **THEN** `"やまだたろう"` が返される（「山田」の短い方ではなく「山田太郎」の長い方が優先される）

#### Scenario: 辞書が空の場合はテキストをそのまま返す
- **WHEN** 辞書にエントリが存在しない状態で `applyDictionary(text)` が呼ばれる
- **THEN** 入力テキストがそのまま返される

#### Scenario: 複数のエントリが1つのテキストに適用される
- **WHEN** `applyDictionary("シャルロット姫とアルベルト王")` が呼ばれ、辞書に `{surface: "シャルロット", reading: "しゃるろっと"}` と `{surface: "アルベルト", reading: "あるべると"}` が登録されている
- **THEN** `"しゃるろっと姫とあるべると王"` が返される
