## Why

`voices/` は仕様上 `.wav` と `.mp3` の両方を参照音声として受け付ける (`voice-reference-library`) が、Irodori-TTS のネイティブ側 (audio.cpp フォーク) は WAV しか読めず、MP3 を選ぶと合成が必ず `Irodori synthesis failed: invalid WAV RIFF header` で失敗する。アプリ自身の音声書き出しが MP3 (LAME) であるため、ユーザが自然に MP3 を `voices/` に置いてしまう導線があり、実機で再現済み。Qwen3 エンジンは minimp3 同梱で既に MP3 を読めるため、エンジン間で挙動が食い違っている状態でもある。

## What Changes

- 上流 `0xShug0/audio.cpp` の `ci/new-feature-mp3` ブランチのコミット `dd0aeff` "Add MP3 audio input support" を `endo5501/audio.cpp` フォークにチェリーピックする
  - 新規: `include/engine/framework/audio/audio_reader.h`、`src/framework/audio/audio_reader.cpp`、`external/minimp3/`(LICENSE=CC0 同梱)
  - `read_audio_f32(path)` がマジックバイト優先 + 拡張子フォールバックで WAV / MP3 を判別する
  - 衝突する `app/server/runtime.cpp` は**上流側**の改名 (`is_supported_audio_upload_filename`) とエラー文言を採用する
- フォーク固有の C shim `src/audiocpp_c_api.cpp` の参照音声読み込みを `read_wav_f32` → `read_audio_f32` に差し替える
- 上流コミットにはテストが無いため、フォークに C++ ユニットテストと数KBの MP3 フィクスチャを追加する
- NovelViewer 側は audio.cpp submodule 参照の更新のみ (Dart コードの変更なし)
- 未対応フォーマット時のエラーメッセージが `unsupported audio input format: <path> (supported: WAV, MP3)` になり、原因が特定できるようになる

非対象 (スコープ外):

- `read_wav_f32` の他の呼び出し元 (vevo2 / chatterbox / mixing 等) の差し替え — 上流も CLI/server のみを差し替えており、Irodori 経路に不要
- `AUDIOCPP_DEPLOYMENT_BUILD` (model spec の GGUF 埋め込み) への移行 — 別件
- Dart 側の許可拡張子とネイティブ対応フォーマットの二重定義の解消 — 今回で実害が消えるため、相互参照コメントに留める

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `irodori-tts-native-engine`: `audiocpp_synthesize` の `ref_wav_path` が受け付ける音声フォーマットに MP3 を追加する。未対応フォーマットのエラーメッセージ要件を追加する

## Impact

- `third_party/audio.cpp` (フォーク: endo5501/audio.cpp) — 別リポジトリでのコミットとプッシュが先行して必要
  - 新規 2 ファイル + ベンダリング `external/minimp3/`、`CMakeLists.txt` 2 行、`src/audiocpp_c_api.cpp` 1 行、`app/server/runtime.cpp` (未使用だがフォークの一貫性のため)
  - 新規テスト `tests/unittests/test_audio_reader.cpp` とフィクスチャ `tests/unittests/assets/`
- NovelViewer 本体 — submodule 参照の更新のみ。Dart / Flutter コードの変更なし
- ビルド — `scripts/build_irodori_windows.bat` / `scripts/build_irodori_macos.sh` は変更不要 (ヘッダオンリーの minimp3 が engine_runtime に取り込まれるだけ)
- バイナリサイズ — minimp3 分の微増のみ
- ライセンス — minimp3 は CC0。配布物へのライセンス同梱方針の見直しが必要かどうかを確認する
