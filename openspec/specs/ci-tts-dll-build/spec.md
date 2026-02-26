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
