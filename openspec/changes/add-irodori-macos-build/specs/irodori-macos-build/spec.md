## ADDED Requirements

### Requirement: macOS ビルドスクリプトが libomp を静的リンクする

`scripts/build_irodori_macos.sh` は Homebrew の `libomp` 静的ライブラリ (`$(brew --prefix libomp)/lib/libomp.a`) を OpenMP 実装として CMake に指定しなければならない (MUST)。具体的には `OpenMP_C_FLAGS` / `OpenMP_CXX_FLAGS` に `-Xclang -fopenmp -I<libomp prefix>/include` を、`OpenMP_C_LIB_NAMES` / `OpenMP_CXX_LIB_NAMES` に `libomp` を、`OpenMP_libomp_LIBRARY` に `libomp.a` の絶対パスを与えることで、`third_party/audio.cpp/CMakeLists.txt` の `find_package(OpenMP REQUIRED COMPONENTS CXX)` を成功させなければならない (MUST)。`ENGINE_ENABLE_OPENMP` は `ON` のまま維持しなければならない (MUST)。

#### Scenario: libomp 導入済み環境で configure が成功する

- **WHEN** `brew install libomp` 済みの macOS で `scripts/build_irodori_macos.sh` を実行する
- **THEN** CMake の configure が `Could NOT find OpenMP_CXX` エラーを出さずに完了する

#### Scenario: OpenMP が有効なままビルドされる

- **WHEN** ビルドが完了する
- **THEN** 生成された `libaudiocpp_ffi.dylib` に OpenMP ランタイムのシンボルが静的に埋め込まれ、未解決の OpenMP シンボルが存在しない

### Requirement: 成果物 dylib が外部ライブラリに依存しない

ビルドされた `libaudiocpp_ffi.dylib` は、実行時に macOS システムフレームワークおよびシステムライブラリ以外へ依存してはならない (MUST NOT)。特に `/opt/homebrew` 配下など Homebrew が提供するパスへの依存を含んではならない (MUST NOT)。

#### Scenario: otool による依存確認

- **WHEN** `otool -L macos/Frameworks/libaudiocpp_ffi.dylib` を実行する
- **THEN** 出力に `libomp.dylib` を含む `/opt/homebrew` 配下のパスが1件も現れない

#### Scenario: 自身の install name が @rpath である

- **WHEN** `otool -L macos/Frameworks/libaudiocpp_ffi.dylib` を実行する
- **THEN** 自身の install name が `@rpath/libaudiocpp_ffi.dylib` である

### Requirement: libomp 未導入時に原因を示して失敗する

`scripts/build_irodori_macos.sh` は CMake を起動する前に Homebrew `libomp` の利用可能性を検証しなければならない (MUST)。`brew --prefix libomp` が失敗する、または `libomp.a` が存在しない場合、`brew install libomp` の実行を促すメッセージを出力し、非ゼロの終了コードで終了しなければならない (MUST)。

#### Scenario: libomp が未インストールの場合

- **WHEN** `libomp` が未インストールの macOS で `scripts/build_irodori_macos.sh` を実行する
- **THEN** `brew install libomp` を案内するメッセージが表示され、CMake の生エラーを出さずに非ゼロで終了する

### Requirement: Metal バックエンドを有効にしてビルドする

`scripts/build_irodori_macos.sh` は `ENGINE_ENABLE_METAL=ON` を指定し、Metal バックエンド有効な `libaudiocpp_ffi.dylib` を生成しなければならない (MUST)。Metal シェーダライブラリは ggml の既定挙動 (`GGML_METAL_EMBED_LIBRARY` が `GGML_METAL` に追従) により dylib へ埋め込まれ、`default.metallib` を別ファイルとして同梱してはならない (MUST NOT)。

#### Scenario: Metal バックエンドがリンクされる

- **WHEN** ビルドが完了する
- **THEN** `otool -L` の出力に `Metal.framework` と `MetalKit.framework` が含まれる

#### Scenario: metallib の外出しが発生しない

- **WHEN** ビルドが完了する
- **THEN** `macos/Frameworks/` に `default.metallib` が生成されない

### Requirement: 成果物と model spec を macos/Frameworks に配置する

`scripts/build_irodori_macos.sh` はビルド成果物 `libaudiocpp_ffi.dylib` を `macos/Frameworks/` へ、`third_party/audio.cpp/model_specs/irodori_tts.json` を `macos/Frameworks/model_specs/` へ配置しなければならない (MUST)。

#### Scenario: スクリプト完走後の配置

- **WHEN** `scripts/build_irodori_macos.sh` が正常終了する
- **THEN** `macos/Frameworks/libaudiocpp_ffi.dylib` と `macos/Frameworks/model_specs/irodori_tts.json` が存在する

### Requirement: Runner.app に dylib と model spec を同梱する

`macos/Runner.xcodeproj` の `Embed Native Libraries` ビルドフェーズは、既存の4ライブラリに加えて `libaudiocpp_ffi.dylib` を `Runner.app/Contents/Frameworks/` へコピーし、コード署名しなければならない (MUST)。あわせて `macos/Frameworks/model_specs/` を `Runner.app/Contents/Frameworks/model_specs/` へコピーしなければならない (MUST)。これにより `audiocpp_c_api.cpp` の model spec 解決 (dylib と同じディレクトリの `model_specs/irodori_tts.json` を優先) が Windows 版と同一の経路で成立する。

#### Scenario: リリースビルドでの同梱

- **WHEN** `fvm flutter build macos` を実行する
- **THEN** `Runner.app/Contents/Frameworks/libaudiocpp_ffi.dylib` と `Runner.app/Contents/Frameworks/model_specs/irodori_tts.json` が存在する

#### Scenario: デバッグ実行での同梱

- **WHEN** `fvm flutter run -d macos` を実行する
- **THEN** 生成された `Runner.app` にも同じ2ファイルが同梱され、`DynamicLibrary.open('libaudiocpp_ffi.dylib')` が成功する

#### Scenario: dylib 未ビルドでもビルドが壊れない

- **WHEN** `macos/Frameworks/libaudiocpp_ffi.dylib` が存在しない状態で macOS ビルドを実行する
- **THEN** `Embed Native Libraries` フェーズは当該ファイルのコピーをスキップし、ビルド自体は成功する

#### Scenario: 既存ライブラリの同梱に影響しない

- **WHEN** macOS ビルドを実行する
- **THEN** `libqwen3_tts_ffi.dylib` / `liblame_enc_ffi.dylib` / `libpiper_tts_ffi.dylib` / `libonnxruntime.dylib` は従来どおり同梱・署名される

### Requirement: macOS ビルド前提条件を README に明記する

`README.md` の macOS ビルド手順は、`scripts/build_irodori_macos.sh` の実行前に `brew install libomp` が必要であることを明記しなければならない (MUST)。

#### Scenario: README の確認

- **WHEN** README の macOS 向け Release ビルド節を読む
- **THEN** `brew install libomp` が前提条件として記載されている

### Requirement: macOS 実機で Irodori-TTS の合成が成立する

`Runner.app` に同梱された `libaudiocpp_ffi.dylib` を用いて、macOS 実機で Irodori-TTS による音声合成が完了しなければならない (MUST)。Metal バックエンドの初期化に失敗した場合は、既存要件どおり CPU にフォールバックして合成を完了しなければならない (MUST)。

#### Scenario: 実機での合成

- **WHEN** macOS でアプリを起動し、TTS エンジンに Irodori を選択して1文を合成する
- **THEN** エラーなく音声が生成され、再生できる

#### Scenario: model spec が解決される

- **WHEN** `audiocpp_init` が呼ばれる
- **THEN** `Runner.app/Contents/Frameworks/model_specs/irodori_tts.json` が model spec として解決され、初期化エラーが発生しない
