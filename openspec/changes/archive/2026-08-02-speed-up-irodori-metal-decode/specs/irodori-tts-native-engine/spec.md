## MODIFIED Requirements

### Requirement: audio.cpp フォークの submodule 追加と共有ライブラリビルド

システムは endo5501/audio.cpp フォーク (https://github.com/endo5501/audio.cpp) を `third_party/audio.cpp/` に git submodule として含めなければならない (SHALL)。フォークの CMake は `AUDIOCPP_BUILD_SHARED` オプションを提供し、有効時に `src/audiocpp_c_api.cpp` から共有ライブラリターゲット `audiocpp_ffi` (Windows: `audiocpp_ffi.dll`, macOS: `libaudiocpp_ffi.dylib`) をビルドしなければならない (SHALL)。`engine_runtime` 静的ライブラリおよび ggml は共有ライブラリに静的リンクしなければならない (SHALL)。Windows ビルドは Vulkan バックエンド有効 (`ENGINE_ENABLE_VULKAN=ON`) かつ MSVC フラグ `/utf-8` と `/openmp:experimental` を指定し、macOS ビルドは Metal バックエンド有効 (`ENGINE_ENABLE_METAL=ON`) としなければならない (MUST)。

ビルドスクリプトは `audiocpp_ffi` に加えて、性能測定用の CLI ターゲット `audiocpp_cli` も同一の CMake 構成でビルドしなければならない (MUST)。両ターゲットを同一の configure から建てることで、測定対象と配布対象が同じバックエンド設定・同じ `engine_runtime` を共有することを保証する。`audiocpp_cli` はアプリケーションに同梱してはならない (MUST NOT)。

#### Scenario: Windows で共有ライブラリをビルドする
- **WHEN** `scripts/build_irodori_windows.bat` を MSVC 環境で実行する
- **THEN** Vulkan 対応の `audiocpp_ffi.dll` がビルドされ、`build/windows/x64/runner/Release/` 配下に配置される

#### Scenario: macOS で共有ライブラリをビルドする
- **WHEN** `scripts/build_irodori_macos.sh` を macOS で実行する
- **THEN** Metal 対応の `libaudiocpp_ffi.dylib` がビルドされ、`macos/Frameworks/` に配置される

#### Scenario: 日本語ロケール Windows でビルドが成功する
- **WHEN** コードページ 932 の Windows 上でビルドスクリプトを実行する
- **THEN** `/utf-8` フラグにより日本語文字列リテラルを含むソース (chunking.cpp 等) がエラーなくコンパイルされる

#### Scenario: Windows で測定用 CLI もビルドされる
- **WHEN** `scripts/build_irodori_windows.bat` を実行する
- **THEN** `audiocpp_ffi.dll` と同じ CMake ビルドディレクトリに Vulkan 対応の `audiocpp_cli.exe` が生成される

#### Scenario: macOS で測定用 CLI もビルドされる
- **WHEN** `scripts/build_irodori_macos.sh` を実行する
- **THEN** `libaudiocpp_ffi.dylib` と同じ CMake ビルドディレクトリに Metal 対応の `audiocpp_cli` が生成される

#### Scenario: 測定用 CLI が配布物に混入しない
- **WHEN** ビルドスクリプトが正常終了する
- **THEN** `audiocpp_cli` は CMake のビルドディレクトリに留まり、`macos/Frameworks/` および Windows の配布レイアウトへコピーされない
