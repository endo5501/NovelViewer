## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: macOSサンドボックスのファイル書き込み権限
macOSアプリのサンドボックスエンタイトルメントにおいて、ユーザー選択ファイルへの読み書き権限（`com.apple.security.files.user-selected.read-write`）を持たなければならない（SHALL）。これにより `FilePicker.saveFile()` の保存ダイアログが正常に動作する。

#### Scenario: macOSでファイル保存ダイアログが正常に開く
- **WHEN** macOS上でユーザーがエクスポートボタンをタップする
- **THEN** ファイル保存ダイアログ（NSSavePanel）が表示される
- **AND** ユーザーが保存先を選択してMP3ファイルを書き出せる

#### Scenario: Debug/Releaseビルド共に書き込み権限がある
- **WHEN** DebugProfileまたはReleaseのエンタイトルメントを確認する
- **THEN** `com.apple.security.files.user-selected.read-write` が `true` に設定されている
