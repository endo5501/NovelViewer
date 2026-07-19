# ci-tts-dll-build (delta)

## ADDED Requirements

### Requirement: CIパイプラインで audiocpp DLL をビルドする

`scripts/build_irodori_windows.bat` を実行し、Vulkan 対応の `audiocpp_ffi.dll` をビルドしなければならない (MUST)。このステップは `flutter build windows` の前に実行されなければならない (MUST)。ビルドには `/utf-8` および `/openmp:experimental` の MSVC フラグが適用されなければならない (MUST)。`third_party/audio.cpp` サブモジュールは既存の `submodules: recursive` チェックアウトで取得される。

#### Scenario: audiocpp DLL が正常にビルドされる
- **WHEN** audiocpp DLL ビルドステップが完了する
- **THEN** `build/windows/x64/runner/Release/audiocpp_ffi.dll` が存在する

#### Scenario: audiocpp DLL ビルドが flutter build より先に実行される
- **WHEN** CI パイプラインが実行される
- **THEN** audiocpp DLL ビルドステップは `flutter build windows --release` ステップより前に実行される

### Requirement: CIパイプラインで audiocpp DLL と model spec の存在を検証する

audiocpp DLL ビルド後に `audiocpp_ffi.dll` の存在を検証しなければならない (MUST)。model spec を同梱ファイル方式で配布する場合は `model_specs/irodori_tts.json` の配置も検証しなければならない (MUST)。いずれかが存在しない場合、パイプラインをエラー終了しなければならない (MUST)。

#### Scenario: DLL が存在する場合は成功
- **WHEN** 検証ステップが実行され、`audiocpp_ffi.dll` (および同梱方式の場合は model spec) が存在する
- **THEN** ステップは正常終了する

#### Scenario: audiocpp_ffi.dll が存在しない場合はエラー
- **WHEN** 検証ステップが実行され、`audiocpp_ffi.dll` が存在しない
- **THEN** パイプラインはエラー終了する
