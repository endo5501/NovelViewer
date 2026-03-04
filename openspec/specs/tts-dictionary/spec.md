## Purpose

小説ごとのTTS読み上げ辞書機能。表記と読みのペアを `tts_dictionary.db` に永続化し、TTS入力テキスト生成時に自動変換を提供する。

## Requirements

### Requirement: 辞書データベースの初期化
システムは小説フォルダ内に `tts_dictionary.db` という名前のSQLiteデータベースを作成し、`tts_dictionary` テーブルで表記（surface）と読み（reading）のペアを管理しなければならない。テーブルが存在しない場合は自動的に作成されなければならない。

#### Scenario: 初回アクセスでDBが作成される
- **WHEN** `TtsDictionaryDatabase` がまだ存在しないフォルダパスで初期化される
- **THEN** `tts_dictionary.db` が当該フォルダに作成され、`tts_dictionary` テーブルが生成される

#### Scenario: 既存DBへの再接続
- **WHEN** `TtsDictionaryDatabase` が既存の `tts_dictionary.db` を持つフォルダで初期化される
- **THEN** 既存のデータを失わずにDBに接続される

### Requirement: 辞書エントリのCRUD
システムは辞書エントリの追加・取得・更新・削除操作を提供しなければならない。各エントリは一意のIDを持ち、surface（表記）とreading（読み）のペアで構成される。同一のsurfaceが重複登録されることをDBレベルで防止しなければならない（UNIQUE制約）。

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

### Requirement: テキスト変換
システムは辞書エントリを使ってテキスト文字列の変換を行う `applyDictionary(text)` メソッドを提供しなければならない。変換は最長一致優先で行い、辞書エントリのsurface長の降順でテキストを走査して置換しなければならない。

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
