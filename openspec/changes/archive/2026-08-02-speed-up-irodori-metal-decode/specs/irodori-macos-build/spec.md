## MODIFIED Requirements

### Requirement: 成果物を macos/Frameworks に配置する

`scripts/build_irodori_macos.sh` はビルド成果物 `libaudiocpp_ffi.dylib` を `macos/Frameworks/` へ配置しなければならない (MUST)。model spec は埋め込み済みのため、`macos/Frameworks/model_specs/` を作成してはならない (MUST NOT)。

測定用にビルドされる `audiocpp_cli` は `macos/Frameworks/` へ配置してはならない (MUST NOT)。`Runner.app/Contents/Frameworks/` は codesign の封印対象であり、実行ファイルを追加すると署名要件が変わるためである。`audiocpp_cli` は CMake のビルドディレクトリ (`third_party/audio.cpp/build/ffi-metal/`) に留めなければならない (MUST)。

#### Scenario: スクリプト完走後の配置

- **WHEN** `scripts/build_irodori_macos.sh` が正常終了する
- **THEN** `macos/Frameworks/libaudiocpp_ffi.dylib` が存在し、`macos/Frameworks/model_specs/` は存在しない

#### Scenario: 測定用 CLI が Frameworks に混入しない

- **WHEN** `scripts/build_irodori_macos.sh` が正常終了する
- **THEN** `macos/Frameworks/audiocpp_cli` は存在せず、`third_party/audio.cpp/build/ffi-metal/` 配下に `audiocpp_cli` が存在する

#### Scenario: 検証スクリプトが CLI の生成と配置を確認する

- **WHEN** `scripts/test/verify_irodori_macos.sh` を実行する
- **THEN** `audiocpp_cli` がビルドディレクトリに存在すること、および `macos/Frameworks/` に存在しないことが検証項目として報告される
