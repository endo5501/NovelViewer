## Purpose

生成済みTTS音声を1つのMP3ファイルへエクスポートする機能。FilePickerで保存先を選択し、DBの全セグメントWAVをPCM連結してLAME FFIで128kbps/24kHz/モノラルにエンコードし、Isolate内で実行する。LAME DLLのビルドスクリプトとCI統合、macOSサンドボックス権限設定も含む。

## Requirements

### Requirement: MP3エクスポートボタンの表示
TTS音声が生成済み（`TtsAudioState.ready`）かつ再生停止中の場合、エクスポートボタンをTTSコントロール行に表示しなければならない（SHALL）。ボタンのアイコンは `Icons.download` を使用する。

#### Scenario: 生成済み音声がある状態でエクスポートボタンが表示される
- **WHEN** TTS音声の状態が `ready` かつ再生状態が `stopped` である
- **THEN** TTSコントロール行に編集・再生・ダウンロード・削除のボタンが表示される

#### Scenario: 音声が未生成の場合はエクスポートボタンが非表示
- **WHEN** TTS音声の状態が `none` である
- **THEN** エクスポートボタンは表示されない

#### Scenario: 音声生成中はエクスポートボタンが非表示
- **WHEN** TTS音声の状態が `generating` である
- **THEN** エクスポートボタンは表示されない

### Requirement: ファイル保存先の選択
エクスポートボタンを押した時、システムはFilePicker（`saveFile`）を表示し、ユーザーにMP3ファイルの保存先とファイル名を選択させなければならない（SHALL）。デフォルトのファイル名はエピソードのファイル名（拡張子を`.mp3`に変更したもの）とする。

#### Scenario: エクスポートボタンを押すとファイル保存ダイアログが開く
- **WHEN** ユーザーがエクスポートボタンをタップする
- **THEN** ファイル保存ダイアログが表示される
- **AND** 許可される拡張子は `.mp3` のみである
- **AND** デフォルトファイル名はエピソードの `file_name` に `.mp3` 拡張子を付けたものである

#### Scenario: ユーザーがファイル保存ダイアログをキャンセルした場合
- **WHEN** ユーザーがファイル保存ダイアログでキャンセルを選択する
- **THEN** エクスポート処理は開始されず、何も起こらない

### Requirement: WAVセグメントのPCM連結
エクスポート時、システムはDBから対象エピソードの全セグメントを `segment_index` 順に取得し、各セグメントのWAV BLOBから44バイトのヘッダをスキップしてPCMデータを抽出し、連結しなければならない（SHALL）。

#### Scenario: 複数セグメントのPCMデータが正しい順序で連結される
- **WHEN** エピソードに3つのセグメント（index 0, 1, 2）が存在する
- **THEN** セグメント0、1、2の順にPCMデータが連結される
- **AND** 各セグメントのWAVヘッダ（先頭44バイト）は連結データに含まれない

#### Scenario: セグメントが1つのみの場合
- **WHEN** エピソードにセグメントが1つのみ存在する
- **THEN** そのセグメントのPCMデータ（WAVヘッダを除く）がそのままエンコードに渡される

### Requirement: MP3エンコード
連結されたPCMデータをLAME FFIエンコーダを使用してMP3形式にエンコードしなければならない（SHALL）。エンコードパラメータはモノラル、サンプルレート24kHz、ビットレート128kbpsとする。

#### Scenario: PCMデータがMP3にエンコードされる
- **WHEN** 連結されたPCMデータ（16-bit モノラル 24kHz）がエンコーダに渡される
- **THEN** MP3形式のバイトデータが生成される
- **AND** 出力MP3はモノラル、24kHz、128kbpsである

#### Scenario: エンコーダの初期化に失敗した場合
- **WHEN** LAME DLLのロードまたは初期化に失敗する
- **THEN** エラーメッセージがユーザーに表示される
- **AND** エクスポート処理は中止される

### Requirement: ファイル書き出し
エンコードされたMP3データをユーザーが選択したパスにファイルとして書き出さなければならない（SHALL）。

#### Scenario: MP3ファイルが正常に保存される
- **WHEN** MP3エンコードが完了し、保存先パスが指定されている
- **THEN** 指定パスにMP3ファイルが書き出される
- **AND** ファイルは有効なMP3形式である

#### Scenario: ファイル書き出しに失敗した場合
- **WHEN** 書き出し先にアクセス権がない、またはディスク容量が不足している
- **THEN** エラーメッセージがユーザーに表示される

### Requirement: エクスポートの非同期実行
エクスポート処理（PCM連結、MP3エンコード、ファイル書き出し）はIsolate内で実行し、メインスレッド（UIスレッド）をブロックしてはならない（SHALL NOT）。

#### Scenario: エクスポート中もUIが応答する
- **WHEN** エクスポート処理が実行中である
- **THEN** UIはフリーズせず、ユーザー操作に応答し続ける

### Requirement: エクスポート進捗の表示
エクスポート処理中、進捗状況をUIに表示しなければならない（SHALL）。進捗はセグメント単位で更新される。

#### Scenario: エクスポート中に進捗が表示される
- **WHEN** エクスポート処理が開始される
- **THEN** エクスポートボタンの代わりに進捗インジケータが表示される

#### Scenario: エクスポートが完了した場合
- **WHEN** MP3ファイルの書き出しが完了する
- **THEN** 進捗インジケータが消え、完了を示すフィードバック（SnackBarなど）がユーザーに表示される
- **AND** エクスポートボタンが再び表示される

### Requirement: LAME DLLのネイティブバインディング
LAME MP3エンコーダをラップしたネイティブライブラリをFFI (`dart:ffi`) 経由でロードし、初期化・エンコード・フラッシュ・クローズの操作を提供しなければならない（SHALL）。Windows では `lame_enc_ffi.dll`、macOS では `liblame_enc_ffi.dylib` をロードしなければならない（SHALL）。

#### Scenario: Windowsでネイティブライブラリのロードと関数バインディングが成功する
- **WHEN** Windows上でアプリケーションがMP3エンコード機能を初めて使用する
- **THEN** `lame_enc_ffi.dll` がロードされる
- **AND** `lame_enc_init`、`lame_enc_encode`、`lame_enc_flush`、`lame_enc_close` 関数がバインドされる

#### Scenario: macOSでネイティブライブラリのロードと関数バインディングが成功する
- **WHEN** macOS上でアプリケーションがMP3エンコード機能を初めて使用する
- **THEN** `liblame_enc_ffi.dylib` がアプリバンドルの `Frameworks/` ディレクトリからロードされる
- **AND** `lame_enc_init`、`lame_enc_encode`、`lame_enc_flush`、`lame_enc_close` 関数がバインドされる

#### Scenario: ネイティブライブラリが見つからない場合
- **WHEN** ネイティブライブラリがアプリケーションのディレクトリに存在しない
- **THEN** エラーメッセージがユーザーに表示される
- **AND** エクスポート機能は利用不可として扱われる

### Requirement: ネイティブDLLのビルドとCI統合
LAME MP3エンコーダをラップするネイティブライブラリのビルドスクリプトを提供し、CIパイプラインに統合しなければならない（SHALL）。macOSではXcodeビルドフェーズで `liblame_enc_ffi.dylib` をアプリバンドルに埋め込まなければならない（SHALL）。

#### Scenario: Windowsでビルドスクリプトによりネイティブライブラリがビルドされる
- **WHEN** ビルドスクリプト（`scripts/build_lame_windows.bat`）を実行する
- **THEN** `lame_enc_ffi.dll` が `build/windows/x64/runner/Release/` に生成される

#### Scenario: macOSでビルド時にdylibがアプリバンドルに埋め込まれる
- **WHEN** macOSでFlutterビルドを実行する
- **THEN** `liblame_enc_ffi.dylib` がアプリバンドルの `Frameworks/` ディレクトリにコピーされる
- **AND** コピーされたdylibにcodesignが適用される

#### Scenario: CIでDLLが自動ビルドされる
- **WHEN** GitHub Actionsのリリースワークフローが実行される
- **THEN** `lame_enc_ffi.dll` がビルドされ、リリースアーカイブに含まれる

### Requirement: macOSサンドボックスのファイル書き込み権限
macOSアプリのサンドボックスエンタイトルメントにおいて、ユーザー選択ファイルへの読み書き権限（`com.apple.security.files.user-selected.read-write`）を持たなければならない（SHALL）。これにより `FilePicker.saveFile()` の保存ダイアログが正常に動作する。

#### Scenario: macOSでファイル保存ダイアログが正常に開く
- **WHEN** macOS上でユーザーがエクスポートボタンをタップする
- **THEN** ファイル保存ダイアログ（NSSavePanel）が表示される
- **AND** ユーザーが保存先を選択してMP3ファイルを書き出せる

#### Scenario: Debug/Releaseビルド共に書き込み権限がある
- **WHEN** DebugProfileまたはReleaseのエンタイトルメントを確認する
- **THEN** `com.apple.security.files.user-selected.read-write` が `true` に設定されている
