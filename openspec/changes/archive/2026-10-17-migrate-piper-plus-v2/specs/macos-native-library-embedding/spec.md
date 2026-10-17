# Spec Delta

## MODIFIED Requirements

### Requirement: 同梱される dylib 集合が期待どおりである

全ネイティブライブラリをビルド済みの状態で macOS ビルドを実行したとき、`Runner.app/Contents/Frameworks/` には `libqwen3_tts_ffi.dylib` / `liblame_enc_ffi.dylib` / `libpiper_plus.dylib` / `libonnxruntime.dylib` / `libaudiocpp_ffi.dylib` の5件が同梱されなければならない (MUST)。これ以外の `.dylib` を同梱してはならない (MUST NOT)。

#### Scenario: 同梱集合の確認

- **WHEN** 全ネイティブライブラリをビルドした状態で `fvm flutter build macos` を実行し、`Runner.app/Contents/Frameworks/*.dylib` を列挙する
- **THEN** 上記5件と一致し、バージョン付きの `libonnxruntime.*.dylib` や `libpiper_plus.*.dylib`、旧名の `libpiper_tts_ffi.dylib` などの余分なファイルが含まれない
