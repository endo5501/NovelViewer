## Purpose

GitHub Actions CIで Windows用TTS DLL（`qwen3_tts_ffi.dll`、`piper_plus.dll` + `onnxruntime.dll`、および `audiocpp_ffi.dll`）をflutter buildに先立ってビルドする。サブモジュールの再帰クローン、Vulkan SDKのインストール、ビルド成果物の存在検証までを含む。

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

`scripts/build_piper_windows.bat` を実行し、CPU onlyの `piper_plus.dll` と `onnxruntime.dll` をビルドしなければならない（MUST）。このステップは `flutter build windows` の前に実行されなければならない（MUST）。

#### Scenario: Piper DLLが正常にビルドされる
- **WHEN** Piper TTS DLLビルドステップが完了する
- **THEN** `build/windows/x64/runner/Release/piper_plus.dll` と `build/windows/x64/runner/Release/onnxruntime.dll` が存在する

#### Scenario: Piper DLLビルドがflutter buildより先に実行される
- **WHEN** CIパイプラインが実行される
- **THEN** Piper TTS DLLビルドステップは `flutter build windows --release` ステップより前に実行される

### Requirement: CIパイプラインで audiocpp DLL をビルドする

`scripts/build_irodori_windows.bat` を実行し、Vulkan 対応の `audiocpp_ffi.dll` をビルドしなければならない (MUST)。このステップは `flutter build windows` の前に実行されなければならない (MUST)。ビルドには `/utf-8` および `/openmp:experimental` の MSVC フラグが適用されなければならない (MUST)。`third_party/audio.cpp` サブモジュールは既存の `submodules: recursive` チェックアウトで取得される。

#### Scenario: audiocpp DLL が正常にビルドされる
- **WHEN** audiocpp DLL ビルドステップが完了する
- **THEN** `build/windows/x64/runner/Release/audiocpp_ffi.dll` が存在する

#### Scenario: audiocpp DLL ビルドが flutter build より先に実行される
- **WHEN** CI パイプラインが実行される
- **THEN** audiocpp DLL ビルドステップは `flutter build windows --release` ステップより前に実行される

### Requirement: CIパイプラインで audiocpp DLL と model spec の存在を検証する

audiocpp DLL ビルド後に `audiocpp_ffi.dll` と `model_specs/irodori_tts.json` (実行ファイル隣接の同梱ファイル) の存在を検証しなければならない (MUST)。いずれかが存在しない場合、パイプラインをエラー終了しなければならない (MUST)。

#### Scenario: DLL と model spec が存在する場合は成功
- **WHEN** 検証ステップが実行され、`audiocpp_ffi.dll` と model spec が存在する
- **THEN** ステップは正常終了する

#### Scenario: audiocpp_ffi.dll が存在しない場合はエラー
- **WHEN** 検証ステップが実行され、`audiocpp_ffi.dll` が存在しない
- **THEN** パイプラインはエラー終了する

### Requirement: CIパイプラインでpiper-plus DLLの存在を検証する

Piper TTS DLLビルド後に `piper_plus.dll` と `onnxruntime.dll` の存在を検証しなければならない（MUST）。いずれかが存在しない場合、パイプラインをエラー終了しなければならない（MUST）。

#### Scenario: 両DLLが存在する場合は成功
- **WHEN** Piper DLL検証ステップが実行され、`piper_plus.dll` と `onnxruntime.dll` が両方存在する
- **THEN** ステップは正常終了する

#### Scenario: piper_plus.dllが存在しない場合はエラー
- **WHEN** Piper DLL検証ステップが実行され、`piper_plus.dll` が存在しない
- **THEN** パイプラインはエラー終了する

#### Scenario: onnxruntime.dllが存在しない場合はエラー
- **WHEN** Piper DLL検証ステップが実行され、`onnxruntime.dll` が存在しない
- **THEN** パイプラインはエラー終了する

### Requirement: Windows用 ONNX Runtime を NuGet から版とハッシュを固定して取得する

`scripts/build_piper_windows.bat` は cmake の実行前に ONNX Runtime を準備しなければならない（MUST）。
- 取得元: NuGet の `Microsoft.ML.OnnxRuntime`。GitHub Releases は使ってはならない（MUST NOT）。
- 版: piper-plus の CMake（`cmake/find_onnxruntime_windows.cmake` の `ONNXRUNTIME_VERSION`）が指定する版と同一でなければならない（MUST）。
- 照合: 取得したパッケージの SHA256 を、版ごとに固定した値と照合しなければならない（MUST）。
- 置き方: win-x64 のヘッダー・`onnxruntime.lib`・`onnxruntime.dll`・`LICENSE` を `onnxruntime-win-x64-<版>/{include,lib,LICENSE}` のレイアウトにまとめる。これを zip にし、`third_party/piper-plus/build/onnxruntime/onnxruntime.zip` として置かなければならない（MUST）。

取得を省略してよいのは、この zip が既に存在し、かつ zip として読めて、その版の `onnxruntime-win-x64-<版>/` の必要なファイルを含む場合だけでなければならない（MUST）。
それ以外の場合（空ファイル、壊れた zip、別の版の zip）は、作り直さなければならない（MUST）。
`third_party/piper-plus/build/onnxruntime/` 配下に別の版の展開ディレクトリが残っている場合は、それを削除しなければならない（MUST）。
x64 以外のアーキテクチャの DLL を `third_party/piper-plus/build` 配下に置いてはならない（MUST NOT）。

#### Scenario: NuGet から取得して既存レイアウトで置く
- **WHEN** `third_party/piper-plus/build/onnxruntime/onnxruntime.zip` が存在しない状態で Piper TTS DLL ビルドステップを実行する
- **THEN** zip が作られ、中に `onnxruntime-win-x64-<版>/include/onnxruntime_cxx_api.h`、`lib/onnxruntime.lib`、`lib/onnxruntime.dll`、`LICENSE` が含まれる
- **AND** cmake の configure は GitHub からの ONNX Runtime ダウンロードを行わない

#### Scenario: 版は piper-plus の CMake に従う
- **WHEN** piper-plus の `ONNXRUNTIME_VERSION` が `X.Y.Z` である
- **THEN** 取得するパッケージの版は `X.Y.Z` であり、zip 内のディレクトリ名は `onnxruntime-win-x64-X.Y.Z` である

#### Scenario: ハッシュが一致しない場合はエラー
- **WHEN** 取得したパッケージの SHA256 が固定値と一致しない
- **THEN** ビルドステップはエラー終了し、`onnxruntime.zip` は作られない

#### Scenario: ハッシュが未登録の版はエラー
- **WHEN** piper-plus の `ONNXRUNTIME_VERSION` に対応する SHA256 が登録されていない
- **THEN** ビルドステップはエラー終了し、ハッシュの追加が必要であることを示す

#### Scenario: その版の zip が既にあれば取得しない
- **WHEN** `third_party/piper-plus/build/onnxruntime/onnxruntime.zip` が既に存在し、その版の必要なファイルを含む
- **THEN** パッケージの取得を行わずに次の処理へ進む

#### Scenario: 使えない zip は作り直す
- **WHEN** 既存の `onnxruntime.zip` が空、zip として読めない、または別の版のものである
- **THEN** パッケージから zip を作り直し、別の版の展開ディレクトリは削除される

### Requirement: Piper TTS DLL ビルドスクリプトは途中の失敗で止まる

`scripts/build_piper_windows.bat` は、ONNX Runtime の準備、cmake configure、cmake build のいずれかが失敗した場合、ただちに非0で終了しなければならない（MUST）。

#### Scenario: ONNX Runtime の準備に失敗するとビルドしない
- **WHEN** ONNX Runtime の準備が失敗する
- **THEN** スクリプトは cmake を実行せずに非0で終了する
