## Purpose

endo5501/audio.cpp フォークを submodule として取り込み、Irodori-TTS (600M-v3-VoiceDesign) のネイティブ推論を行う共有ライブラリ `audiocpp_ffi` (Windows: Vulkan / macOS: Metal) をビルドし、C API・Dart FFI バインディング・`IrodoriTtsEngine` ラッパーを通じて素TTS / ボイスクローン / caption 指定 / 両立の4形態の合成と安全な abort 機構を提供する。
## Requirements
### Requirement: audio.cpp フォークの submodule 追加と共有ライブラリビルド
システムは endo5501/audio.cpp フォーク (https://github.com/endo5501/audio.cpp) を `third_party/audio.cpp/` に git submodule として含めなければならない (SHALL)。フォークの CMake は `AUDIOCPP_BUILD_SHARED` オプションを提供し、有効時に `src/audiocpp_c_api.cpp` から共有ライブラリターゲット `audiocpp_ffi` (Windows: `audiocpp_ffi.dll`, macOS: `libaudiocpp_ffi.dylib`) をビルドしなければならない (SHALL)。`engine_runtime` 静的ライブラリおよび ggml は共有ライブラリに静的リンクしなければならない (SHALL)。Windows ビルドは Vulkan バックエンド有効 (`ENGINE_ENABLE_VULKAN=ON`) かつ MSVC フラグ `/utf-8` と `/openmp:experimental` を指定し、macOS ビルドは Metal バックエンド有効 (`ENGINE_ENABLE_METAL=ON`) としなければならない (MUST)。

#### Scenario: Windows で共有ライブラリをビルドする
- **WHEN** `scripts/build_irodori_windows.bat` を MSVC 環境で実行する
- **THEN** Vulkan 対応の `audiocpp_ffi.dll` がビルドされ、`build/windows/x64/runner/Release/` 配下に配置される

#### Scenario: macOS で共有ライブラリをビルドする
- **WHEN** `scripts/build_irodori_macos.sh` を macOS で実行する
- **THEN** Metal 対応の `libaudiocpp_ffi.dylib` がビルドされ、`macos/Frameworks/` に配置される

#### Scenario: 日本語ロケール Windows でビルドが成功する
- **WHEN** コードページ 932 の Windows 上でビルドスクリプトを実行する
- **THEN** `/utf-8` フラグにより日本語文字列リテラルを含むソース (chunking.cpp 等) がエラーなくコンパイルされる

### Requirement: C API によるコンテキストライフサイクル
共有ライブラリは `audiocpp_c_api.h` で C ABI を公開しなければならない (SHALL)。`audiocpp_init(model_dir, n_threads, abort_handle)` は Irodori-TTS モデル一式 (600M-v3-VoiceDesign / llm-jp トークナイザ / DACVAE codec) をロードし、成功時に不透明な `audiocpp_ctx` ポインタ、失敗時に NULL を返さなければならない (SHALL)。model spec (`model_specs/irodori_tts.json`) は実行ファイル相対の同梱ファイルまたはビルド時埋め込みにより解決しなければならない (SHALL)。`audiocpp_free(ctx)` は全リソースを解放し、`audiocpp_is_loaded(ctx)` はロード済みなら非ゼロを返さなければならない (SHALL)。バックエンドは Windows では Vulkan、macOS では Metal を優先し、GPU 初期化に失敗した場合は CPU にフォールバックしなければならない (MUST)。

#### Scenario: 有効なモデルディレクトリで初期化する
- **WHEN** `audiocpp_init("<models>/Irodori-TTS-600M-v3-VoiceDesign", 4, handle)` を呼ぶ
- **THEN** 非 NULL のコンテキストが返り、`audiocpp_is_loaded()` が非ゼロを返す

#### Scenario: 無効なモデルパスで初期化する
- **WHEN** 存在しないディレクトリを指定して `audiocpp_init` を呼ぶ
- **THEN** NULL が返り、クラッシュしない

#### Scenario: GPU 初期化失敗時の CPU フォールバック
- **WHEN** Vulkan/Metal デバイスが利用できない環境で `audiocpp_init` を呼ぶ
- **THEN** CPU バックエンドで初期化が完了し、合成が可能である

### Requirement: 統合合成関数 (素TTS / クローン / caption / 両立)
`audiocpp_synthesize(ctx, text, ref_wav_path, caption, speaker_guidance_scale, caption_guidance_scale, num_inference_steps)` は `ref_wav_path` と `caption` をともに NULL 許容とし、NULL の組み合わせにより素TTS (両方 NULL) / クローンのみ (caption NULL) / caption のみ (ref NULL) / 両立 (両方指定) の4形態を単一関数で実行しなければならない (SHALL)。成功時は 0、失敗時は非ゼロを返し、`audiocpp_get_error(ctx)` でエラーメッセージを取得できなければならない (SHALL)。合成結果は `audiocpp_get_audio(ctx)` (float32 PCM)、`audiocpp_get_audio_length(ctx)`、`audiocpp_get_sample_rate(ctx)` (48000) で取得できなければならない (SHALL)。

#### Scenario: クローンと caption の両立合成
- **WHEN** `audiocpp_synthesize(ctx, "こんにちは", "/voices/ref.wav", "落ち着いた大人の女性の声", 5.0, 3.0, 40)` を呼ぶ
- **THEN** 0 が返り、参照話者の声質と caption のスタイルを併せ持つ 48kHz float32 PCM が取得できる

#### Scenario: caption なしのクローン合成
- **WHEN** caption に NULL を渡して合成する
- **THEN** 参照音声のみに条件付けられた合成が行われ、caption CFG は無効になる

#### Scenario: 空文字 caption は caption なしと同義
- **WHEN** caption に空文字列を渡して合成する
- **THEN** caption なし (NULL) と同じ挙動になる

### Requirement: 中断 (abort) 機構
C API はコンテキストと独立したライフタイムを持つ abort handle (`audiocpp_create_abort_handle` / `audiocpp_free_abort_handle`) を提供しなければならない (SHALL)。abort フラグは `std::atomic<bool>` とし、`audiocpp_abort(handle)` は任意のスレッドから安全に呼べなければならない (MUST)。Irodori の RF 拡散サンプリングループは各ステップ先頭で abort フラグを確認し、セット時は現在の合成を即座に中断して非ゼロエラーを返さなければならない (SHALL)。`audiocpp_reset_abort(handle)` はフラグをクリアし、以後の合成を通常どおり実行可能にしなければならない (SHALL)。handle は `audiocpp_free` によって解放されてはならず (MUST NOT)、コンテキスト解放後の `audiocpp_abort` 呼び出しは未定義動作であってはならない (MUST NOT)。abort handle はエンジンファミリごとに独立して所有され (qwen3 は qwen3_tts_ffi、Irodori は audiocpp_ffi が生成・解放)、一方の DLL が生成したハンドルを他方の DLL に渡してはならない (MUST NOT)。

#### Scenario: 合成中の中断
- **WHEN** 別スレッドで `audiocpp_synthesize` 実行中に `audiocpp_abort(handle)` を呼ぶ
- **THEN** 遅くとも次の RF ステップ境界で合成が中断され、`audiocpp_synthesize` は非ゼロを返す

#### Scenario: コンテキスト解放後の abort が安全
- **WHEN** `audiocpp_free(ctx)` 後に同じ handle へ `audiocpp_abort(handle)` を呼ぶ
- **THEN** クラッシュや未定義動作は発生しない (handle は ctx と独立に有効)

#### Scenario: reset 後の再合成
- **WHEN** abort で中断後に `audiocpp_reset_abort(handle)` を呼び再度合成する
- **THEN** 合成は正常に完走する

### Requirement: Dart FFI バインディングと IrodoriTtsEngine ラッパー
システムは `AudiocppNativeBindings` (DynamicLibrary から全 C API 関数を lookup) と、共通 TTS エンジンインターフェースに適合する `IrodoriTtsEngine` ラッパーを提供しなければならない (SHALL)。ライブラリ名は Windows: `audiocpp_ffi.dll`、macOS: `libaudiocpp_ffi.dylib` としなければならない (SHALL)。`IrodoriTtsEngine.synthesize` は text / 任意の refWavPath / 任意の caption / guidance 2種 / steps を受け取り、`TtsSynthesisResult` (Float32List + sampleRate) を返さなければならない (SHALL)。`TtsIsolate` は第3のエンジンブランチとして Irodori をサポートし、既存の Qwen3 / Piper ブランチの挙動を変更してはならない (MUST NOT)。

#### Scenario: エンジンラッパーでの合成
- **WHEN** `IrodoriTtsEngine.synthesize(text, refWavPath: ..., caption: ...)` を呼ぶ
- **THEN** ネイティブ合成が実行され `TtsSynthesisResult(audio, 48000)` が返る

#### Scenario: TtsIsolate の第3ブランチ
- **WHEN** `TtsIsolate` に `IrodoriEngineConfig` でモデルロードと合成を要求する
- **THEN** isolate 内で `IrodoriTtsEngine` が使用され、abort / dispose のライフサイクルが qwen3 と同等に機能する

#### Scenario: 未ロードでの合成はエラー
- **WHEN** モデル未ロードの `IrodoriTtsEngine` で `synthesize` を呼ぶ
- **THEN** `TtsEngineException` が送出される

### Requirement: 参照音声の WAV / MP3 対応

`audiocpp_synthesize` に渡される `ref_wav_path` は WAV と MP3 の両方を受け付けなければならない (SHALL)。シェイム層は WAV 専用の読み込み関数ではなく、フォーマットを判別する共通リーダ `engine::audio::read_audio_f32` を経由しなければならない (SHALL)。判別は先頭バイト (`RIFF`…`WAVE`) を優先し、判別できない場合に拡張子 (`.mp3` / `.mpa` / `.mpeg`) をフォールバックとして用いなければならない (SHALL)。デコード結果はサンプリングレートとチャンネル数を保持し、WAV 経路と同一の内部表現でエンジンに渡されなければならない (SHALL)。この対応により `voice-reference-library` が列挙する `.wav` / `.mp3` の両方が Irodori エンジンで実際に使用可能になる。

#### Scenario: MP3 の参照音声でクローン合成する

- **WHEN** `voices/` 内の MP3 ファイルのパスを `ref_wav_path` に指定して合成する
- **THEN** MP3 がデコードされ、参照話者の声質を持つ音声が生成される (エラーにならない)

#### Scenario: WAV の参照音声は従来どおり動作する

- **WHEN** WAV ファイルのパスを `ref_wav_path` に指定して合成する
- **THEN** 従来と同一の経路 (`read_wav_f32`) で読み込まれ、既存の挙動が変化しない

#### Scenario: 非 ASCII のファイル名を持つ MP3 を読み込む

- **WHEN** `月ノ美兎.mp3` のような非 ASCII 名の MP3 を参照音声に指定する
- **THEN** Windows を含む全プラットフォームでデコードに成功する

#### Scenario: 拡張子が .wav で中身が MP3 のファイル

- **WHEN** 中身が MP3 のファイルが `.wav` 拡張子で指定される
- **THEN** MP3 として読み替えず、`invalid WAV RIFF header` を含むエラーになる (拡張子が `.wav` の場合は拡張子の宣言を優先する)

### Requirement: 未対応フォーマットの診断可能なエラー

参照音声の読み込みに失敗した場合、エラーメッセージは対象ファイルのパスと、対応フォーマットの一覧を含まなければならない (SHALL)。このメッセージは `audiocpp_get_error(ctx)` 経由で Dart 層まで伝播し、アプリログに記録されなければならない (SHALL)。

#### Scenario: 未対応フォーマットを指定する

- **WHEN** WAV でも MP3 でもないファイルを `ref_wav_path` に指定する
- **THEN** `unsupported audio input format: <path> (supported: WAV, MP3)` に相当するメッセージで失敗する

#### Scenario: 空または破損した MP3 を指定する

- **WHEN** 空ファイル、またはデコードできない MP3 を `ref_wav_path` に指定する
- **THEN** 対象パスを含むエラーメッセージで失敗し、プロセスがクラッシュしない

#### Scenario: 非 ASCII パスを含むエラーメッセージ

- **WHEN** `月ノ美兎.txt` のような非 ASCII 名のファイルで読み込みが失敗する
- **THEN** エラーメッセージ中のパスは UTF-8 でエンコードされ、Dart 側の UTF-8 デコードが `FormatException` を起こさない (Windows の ANSI コードページに変換されてはならない)

