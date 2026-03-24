## ADDED Requirements

### Requirement: CIパイプラインでPiper TTS DLLをビルドする

`scripts/build_piper_windows.bat` を実行し、CPU onlyの `piper_tts_ffi.dll` と `onnxruntime.dll` をビルドしなければならない（MUST）。このステップは `flutter build windows` の前に実行されなければならない（MUST）。

#### Scenario: Piper DLLが正常にビルドされる
- **WHEN** Piper TTS DLLビルドステップが完了する
- **THEN** `build/windows/x64/runner/Release/piper_tts_ffi.dll` と `build/windows/x64/runner/Release/onnxruntime.dll` が存在する

#### Scenario: Piper DLLビルドがflutter buildより先に実行される
- **WHEN** CIパイプラインが実行される
- **THEN** Piper TTS DLLビルドステップは `flutter build windows --release` ステップより前に実行される

### Requirement: CIパイプラインでPiper関連DLLの存在を検証する

Piper TTS DLLビルド後に `piper_tts_ffi.dll` と `onnxruntime.dll` の存在を検証しなければならない（MUST）。いずれかが存在しない場合、パイプラインをエラー終了しなければならない（MUST）。

#### Scenario: 両DLLが存在する場合は成功
- **WHEN** Piper DLL検証ステップが実行され、`piper_tts_ffi.dll` と `onnxruntime.dll` が両方存在する
- **THEN** ステップは正常終了する

#### Scenario: piper_tts_ffi.dllが存在しない場合はエラー
- **WHEN** Piper DLL検証ステップが実行され、`piper_tts_ffi.dll` が存在しない
- **THEN** パイプラインはエラー終了する

#### Scenario: onnxruntime.dllが存在しない場合はエラー
- **WHEN** Piper DLL検証ステップが実行され、`onnxruntime.dll` が存在しない
- **THEN** パイプラインはエラー終了する
