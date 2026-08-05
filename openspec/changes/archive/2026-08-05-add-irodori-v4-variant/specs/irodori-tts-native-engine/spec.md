## MODIFIED Requirements

### Requirement: C API によるコンテキストライフサイクル
共有ライブラリは `audiocpp_c_api.h` で C ABI を公開しなければならない (SHALL)。`audiocpp_init(model_dir, n_threads, abort_handle)` は **`model_dir` 直下の単一 GGUF から Irodori-TTS モデル一式 (モデル重み / tokenizer / DACVAE codec)** をロードし、成功時に不透明な `audiocpp_ctx` ポインタ、失敗時に NULL を返さなければならない (SHALL)。

`model_dir` は variant ごとのディレクトリであり、兄弟ディレクトリ (`llm-jp-3-150m`, `Semantic-DACVAE-Japanese-32dim`) を要求してはならない (MUST NOT)。model spec (`model_specs/irodori_tts.json`) は実行ファイル相対の同梱ファイル、GGUF 埋め込み、またはビルド時埋め込みにより解決しなければならない (SHALL)。

`audiocpp_free(ctx)` は全リソースを解放し、`audiocpp_is_loaded(ctx)` はロード済みなら非ゼロを返さなければならない (SHALL)。バックエンドは Windows では Vulkan、macOS では Metal を優先し、GPU 初期化に失敗した場合は CPU にフォールバックしなければならない (MUST)。

#### Scenario: v3 の GGUF ディレクトリで初期化する
- **WHEN** `audiocpp_init("<models>/Irodori-TTS-600M-v3-VoiceDesign-GGUF", 4, handle)` を呼ぶ
- **THEN** 非 NULL のコンテキストが返り、`audiocpp_is_loaded()` が非ゼロを返す

#### Scenario: v4 の GGUF ディレクトリで初期化する
- **WHEN** `audiocpp_init("<models>/Irodori-TTS-v4-Small-GGUF", 4, handle)` を呼ぶ
- **THEN** 非 NULL のコンテキストが返り、`audiocpp_is_loaded()` が非ゼロを返す

#### Scenario: 兄弟ディレクトリなしでロードできる
- **WHEN** `.gguf` 1本のみを含むディレクトリを指定して `audiocpp_init` を呼ぶ
- **THEN** 初期化が成功する

#### Scenario: 無効なモデルパスで初期化する
- **WHEN** 存在しないディレクトリを指定して `audiocpp_init` を呼ぶ
- **THEN** NULL が返り、クラッシュしない

#### Scenario: GPU 初期化失敗時の CPU フォールバック
- **WHEN** Vulkan/Metal デバイスが利用できない環境で `audiocpp_init` を呼ぶ
- **THEN** CPU バックエンドで初期化が完了し、合成が可能である

## ADDED Requirements

### Requirement: upstream マージ後も既存のフォーク独自機能が維持されること
`third_party/audio.cpp` を upstream/main へマージした後も、フォークが独自に持つ以下の機能は維持されなければならない (MUST):

- `AUDIOCPP_BUILD_SHARED` による `audiocpp_ffi` 共有ライブラリのビルド
- abort ハンドルによる合成中断 (チャンク境界および RF サンプリングステップの双方で中断が効くこと)
- 参照音声の WAV / MP3 フォーマットスニッフィング読み込み
- 参照音声のコンテキスト単位キャッシュ
- codec デコードのタイル分割 (`irodori_tts.codec_decode_tile_frames` / `irodori_tts.codec_decode_overlap_frames`)
- guidance scale に明示的なゼロを指定したときの、エンジンへのゼロ転送

マージ後は weight context の既定値が upstream 側で変更されているため、Irodori の合成が従来と同等に動作することを確認しなければならない (MUST)。

#### Scenario: マージ後に abort が両方の中断点で効く
- **WHEN** マージ後のビルドで長文合成を開始し、チャンク処理中および RF サンプリング中にそれぞれ abort する
- **THEN** いずれの時点でも合成が中断される

#### Scenario: マージ後も MP3 参照音声が読める
- **WHEN** マージ後のビルドで MP3 の参照音声を指定して合成する
- **THEN** 拡張子ではなく内容のスニッフィングにより MP3 として読み込まれ、合成が成功する

#### Scenario: マージ後もタイル分割デコードが有効
- **WHEN** マージ後のビルドで長い発話を合成する
- **THEN** codec デコードがタイル分割され、発話長に依存しない有界メモリで完了する

#### Scenario: マージ後の合成品質が従来と同等
- **WHEN** マージ後のビルドで v3 モデルを用い、マージ前と同一の入力・同一 seed で合成する
- **THEN** 合成が成功し、音声の長さと内容が従来と同等である
