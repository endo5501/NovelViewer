## MODIFIED Requirements

### Requirement: Runner.app に dylib を同梱する

`macos/Runner.xcodeproj` の `Embed Native Libraries` ビルドフェーズは、`libaudiocpp_ffi.dylib` を `Runner.app/Contents/Frameworks/` へコピーし、コード署名しなければならない (MUST)。

同梱の仕組み自体 — `macos/Frameworks/` ディレクトリのグロブによる対象決定、静的リストの不使用、未ビルド dylib に対する耐性 — は `macos-native-library-embedding` capability が規定する。本要件はビルドフェーズがライブラリ名を明示列挙することを要求しない。`libaudiocpp_ffi.dylib` が `macos/Frameworks/` に配置されていれば、グロブによって自動的に同梱対象となる。

#### Scenario: リリースビルドでの同梱

- **WHEN** `fvm flutter build macos` を実行する
- **THEN** ビルドが成功し、`Runner.app/Contents/Frameworks/libaudiocpp_ffi.dylib` が存在する

#### Scenario: codesign が成功する

- **WHEN** `fvm flutter build macos` の CodeSign フェーズが実行される
- **THEN** `code object is not signed at all` エラーが発生せずに署名が完了する

#### Scenario: デバッグ実行での同梱

- **WHEN** `fvm flutter run -d macos` を実行する
- **THEN** 生成された `Runner.app` にも dylib が同梱され、`DynamicLibrary.open('libaudiocpp_ffi.dylib')` が成功する

#### Scenario: dylib 未ビルドでもビルドが壊れない

- **WHEN** `macos/Frameworks/libaudiocpp_ffi.dylib` が存在しない状態で macOS ビルドを実行する
- **THEN** `Embed Native Libraries` フェーズは当該ファイルのコピーをスキップし、ビルド自体は成功する

#### Scenario: 既存ライブラリの同梱に影響しない

- **WHEN** macOS ビルドを実行する
- **THEN** `libqwen3_tts_ffi.dylib` / `liblame_enc_ffi.dylib` / `libpiper_tts_ffi.dylib` / `libonnxruntime.dylib` は従来どおり同梱・署名される
