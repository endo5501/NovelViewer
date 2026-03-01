## 1. ネイティブライブラリのセットアップ

- [x] 1.1 LAMEソースコードを `third_party/lame/` に追加する（gitサブモジュールまたはソース配置）
- [x] 1.2 LAME をラップする C API (`lame_enc_ffi.h` / `lame_enc_ffi.c`) を作成する。`lame_enc_init`、`lame_enc_encode`、`lame_enc_flush`、`lame_enc_close` の4関数を実装
- [x] 1.3 `lame_enc_ffi.dll` 用の `CMakeLists.txt` を作成する
- [x] 1.4 Windows向けビルドスクリプト `scripts/build_lame_windows.bat` を作成し、`lame_enc_ffi.dll` を `build/windows/x64/runner/Release/` に出力する
- [x] 1.5 ビルドスクリプトを実行して `lame_enc_ffi.dll` が正常に生成されることを確認する

## 2. Dart FFI バインディング

- [x] 2.1 `lib/features/tts/data/lame_enc_bindings.dart` を作成し、`DynamicLibrary.open()` で `lame_enc_ffi.dll` をロードするバインディングクラスを実装する
- [x] 2.2 `lame_enc_init`、`lame_enc_encode`、`lame_enc_flush`、`lame_enc_close` の FFI 関数バインディングを実装する
- [x] 2.3 DLLが見つからない場合のエラーハンドリングを実装する
- [x] 2.4 FFI バインディングのユニットテストを作成する（DLLのロード、関数呼び出しの正常系・異常系）

## 3. WAV セグメント連結とMP3エンコードサービス

- [x] 3.1 `lib/features/tts/data/tts_audio_export_service.dart` を作成する
- [x] 3.2 WAV BLOBからPCMデータを抽出する関数を実装する（先頭44バイトのヘッダをスキップ）
- [x] 3.3 複数セグメントのPCMデータを `segment_index` 順に連結する関数を実装する
- [x] 3.4 連結PCMデータをLAME FFI経由でMP3にエンコードする関数を実装する（モノラル、24kHz、128kbps）
- [x] 3.5 エンコード結果をファイルに書き出す関数を実装する
- [x] 3.6 Isolate内でエクスポート処理を実行する仕組みを実装する（進捗通知のSendPort付き）
- [x] 3.7 PCM連結のユニットテストを作成する（WAVヘッダスキップ、複数セグメント連結、単一セグメント）
- [x] 3.8 MP3エンコード→ファイル書き出しの統合テストを作成する

## 4. エクスポートプロバイダー

- [x] 4.1 エクスポート状態を管理する Riverpod プロバイダーを作成する（idle / exporting / completed / error）
- [x] 4.2 エクスポート進捗（処理済みセグメント数/全セグメント数）を管理するプロバイダーを作成する
- [x] 4.3 エクスポート実行のトリガーとFilePicker呼び出しを行うプロバイダーメソッドを実装する

## 5. UI統合

- [x] 5.1 `text_viewer_panel.dart` の `TtsAudioState.ready` + `stopped` 状態のボタン行に `Icons.download` のエクスポートボタンを追加する
- [x] 5.2 エクスポートボタンのタップで `FilePicker.platform.saveFile()` を呼び出し、デフォルトファイル名をエピソードの `file_name.mp3` にする
- [x] 5.3 エクスポート中は進捗インジケータ（CircularProgressIndicator等）をエクスポートボタンの代わりに表示する
- [x] 5.4 エクスポート完了時に SnackBar で完了メッセージを表示する
- [x] 5.5 エラー発生時にエラーメッセージを SnackBar で表示する（DLL未検出、エンコード失敗、ファイル書き出し失敗）
- [x] 5.6 エクスポートボタン表示条件のウィジェットテストを作成する（ready+stopped時のみ表示）

## 6. CI統合

- [x] 6.1 `.github/workflows/release.yml` に `scripts/build_lame_windows.bat` の実行ステップを追加する
- [x] 6.2 `lame_enc_ffi.dll` がリリースアーカイブに含まれることを確認する
- [x] 6.3 LAMEのLGPLライセンスファイルをリリースに同梱する

## 7. 最終確認

- [x] 7.1 simplifyスキルを使用してコードレビューを実施
- [x] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 7.3 `fvm flutter analyze`でリントを実行
- [x] 7.4 `fvm flutter test`でテストを実行
