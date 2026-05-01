## Purpose

GitHub Actions CIで Windows用TTS DLL（`qwen3_tts_ffi.dll` および `piper_tts_ffi.dll` + `onnxruntime.dll`）をflutter buildに先立ってビルドする。サブモジュールの再帰クローン、Vulkan SDKのインストール、ビルド成果物の存在検証までを含む。

## Requirements

### Requirement: CIパイプラインでサブモジュールを再帰的にクローンする

`actions/checkout` ステップで `submodules: recursive` を指定し、`third_party/qwen3-tts.cpp` とそのサブモジュール（ggml）をクローンしなければならない（MUST）。

#### Scenario: サブモジュールが正常にクローンされる
- **WHEN** CIワークフローがcheckoutステップを実行する
- **THEN** `third_party/qwen3-tts.cpp/` ディレクトリとその中の `ggml/` ディレクトリが存在する

### Requirement: CIパイプラインでVulkan SDKをインストールする

Flutter buildの前にVulkan SDKをサイレントインストールし、環境変数 `VULKAN_SDK` と `PATH` を設定しなければならない（MUST）。

#### Scenario: Vulkan SDKが正常にインストールされる
- **WHEN** Vulkan SDKインストールステップが完了する
- **THEN** `VULKAN_SDK` 環境変数が設定され、`glslc` コマンドがPATH上で利用可能になる

### Requirement: CIパイプラインでTTS DLLをビルドする

`scripts/build_tts_windows.bat` を実行し、Vulkan対応の `qwen3_tts_ffi.dll` をビルドしなければならない（MUST）。このステップは `flutter build windows` の前に実行されなければならない（MUST）。

#### Scenario: DLLが正常にビルドされる
- **WHEN** TTS DLLビルドステップが完了する
- **THEN** `build/windows/x64/runner/Release/qwen3_tts_ffi.dll` が存在する

#### Scenario: DLLビルドがflutter buildより先に実行される
- **WHEN** CIパイプラインが実行される
- **THEN** TTS DLLビルドステップは `flutter build windows --release` ステップより前に実行される

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
