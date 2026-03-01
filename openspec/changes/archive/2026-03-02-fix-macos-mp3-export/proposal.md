## Why

TTS音声MP3エクスポート機能がmacOSで動作しない。エクスポートボタンを押しても何も起きない。原因は2つ: (1) macOSサンドボックスのエンタイトルメントが `read-only` のため `FilePicker.saveFile()` の保存ダイアログが開かない、(2) Xcodeビルドフェーズで `liblame_enc_ffi.dylib` がアプリバンドルにコピーされていないためランタイムでDLLロードが失敗する。

## What Changes

- macOSエンタイトルメント（DebugProfile / Release）の `files.user-selected` を `read-only` から `read-write` に変更し、ファイル保存ダイアログを有効にする
- Xcodeビルドフェーズ「Embed TTS Library」のスクリプトに `liblame_enc_ffi.dylib` のコピーとcodesignを追加し、アプリバンドルにLAME dylibを含める

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-audio-export`: macOSでのネイティブライブラリ（dylib）のバンドルとロードをサポートする。既存specのDLLロード要件にmacOS対応を追加。

## Impact

- **macOS entitlements**: `DebugProfile.entitlements` と `Release.entitlements` の2ファイルを変更。`read-only` → `read-write` は既存のファイル読み取り操作（設定画面のディレクトリ選択など）に影響なし（上位互換）。
- **Xcodeプロジェクト**: `project.pbxproj` 内のビルドフェーズスクリプトを変更。既存の `libqwen3_tts_ffi.dylib` のコピー処理に `liblame_enc_ffi.dylib` を追加。
- **Dartコード**: 変更不要。`lame_enc_bindings.dart` は既に `Platform.isMacOS` 対応済み。
- **dylib**: `macos/Frameworks/liblame_enc_ffi.dylib` は既にビルド済みで配置済み。
