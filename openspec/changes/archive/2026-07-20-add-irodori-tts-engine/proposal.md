# Add Irodori TTS Engine (audio.cpp)

## Why

現行のTTSエンジン (Qwen3-TTS / Piper) では、ボイスクローニングと caption (自然言語によるボイスデザイン指定) を併用できない。qwen3-tts.cpp はクローンのみ、旧 Irodori-TTS-Server 経由の構想は上流の caption 未対応で凍結していた。audio.cpp (endo5501/audio.cpp フォーク) が Irodori-TTS-600M-v3-VoiceDesign を caption 込みでサポートしており、2026-07-19 のスパイクで「クローン×caption 同時指定」が実用品質・実用速度 (Vulkan/RX 6800 でウォーム RTF≈0.3、48kHz 出力) で動作することを実証済み。TTS編集ダイアログのセグメントメモ欄は元々この caption 用途のために用意されていたが qwen3 の制約で寝かせており、本変更でその本来の用途を解禁する。

## What Changes

- 3つ目のTTSエンジンとして Irodori (audio.cpp ベース) を追加する。既存の Qwen3 / Piper は変更しない
- `third_party/audio.cpp` に endo5501/audio.cpp フォークを git submodule として追加し、qwen3-tts.cpp / piper-plus と同型の「自前 C shim (`audiocpp_c_api.cpp`) → 共有ライブラリ (`audiocpp_ffi.dll` / `libaudiocpp_ffi.dylib`)」でFFI統合する
- フォーク側の Irodori 生成ループ (`src/models/irodori_tts/session.cpp` の RF per-step ループ) に abort チェックを注入し、qwen3 と同じ abort handle 設計 (コンテキストと独立したライフタイム) で中断を実現する
- モデルは Irodori-TTS-600M-v3-VoiceDesign のみ対応 (クローン・caption・両立のすべてを1モデルで賄う)。モデル資産 (600M 本体 / llm-jp-3-150m トークナイザ / 変換済み Semantic-DACVAE-Japanese-32dim / model spec JSON) は endo5501 の Hugging Face リポジトリからダウンロードする (qwen3 の `endo5501/qwen3-tts.cpp` 配信と同じ方式。DACVAE は HF 上流が weights.pth のため変換済み safetensors を自前ホストする)
- 合成は「参照音声 (既存のボイス参照ライブラリ) + セグメントメモ欄の内容を caption として併用」する。メモ欄が空のセグメントは caption なし (クローンのみ) で合成する
- 設定画面に Irodori セクション (モデルダウンロード、speaker/caption guidance scale、推論ステップ数) を追加し、エンジン選択に Irodori を加える
- CI の DLL ビルドに audiocpp_ffi を追加する

## Capabilities

### New Capabilities

- `irodori-tts-native-engine`: audio.cpp フォークの submodule 追加とビルド (Vulkan/Windows, Metal/macOS, CPUフォールバック)、C API shim (init / synthesize(text, ref_wav, caption) / abort handle / audio 取得)、生成ループへの abort 注入、Dart FFI バインディングと `IrodoriTtsEngine` ラッパー、`TtsIsolate` への第3ブランチ追加
- `irodori-tts-model-download`: endo5501 HF リポジトリからの4資産 (600M-v3-VoiceDesign / llm-jp-3-150m tokenizer / 変換済み DACVAE safetensors / model spec) の一括ダウンロード・進捗表示・検証・保存レイアウト
- `irodori-caption-synthesis`: セグメントメモ欄→caption の合成パイプライン連携 (メモ有無による caption 付き/なし切替、既定 caption なし)、speaker_guidance_scale / caption_guidance_scale / num_inference_steps の調整パラメータと永続化

### Modified Capabilities

- `tts-engine-selection`: `TtsEngineType` に第3の値 `irodori` (label "Irodori-TTS") を追加。SegmentedButton とエンジン別設定パネル切替に Irodori を追加
- `tts-engine-config`: sealed `TtsEngineConfig` に `IrodoriEngineConfig` サブクラス (modelDir / refWavPath / guidance scales / steps / sampleRate 48000) を追加。exhaustive switch の3分岐化
- `settings-dialog-composition`: 設定ダイアログに Irodori 設定セクションを追加
- `ci-tts-dll-build`: CI ビルド対象に audiocpp_ffi (Windows DLL / macOS dylib) を追加

## Impact

- **新規ネイティブ依存**: `third_party/audio.cpp` (endo5501 フォーク、タグピン留め)。engine_runtime はモデル別コンパイルスイッチが無く 30+ モデル全部入りの静的 lib のため、DLL サイズは qwen3_tts_ffi より大きくなる (コードのみで数十MB規模)。ggml が qwen3_tts_ffi と audiocpp_ffi に二重埋め込みになるが、DLL 分離 (Windows) / 二層名前空間 (macOS) で衝突しない
- **ビルド**: 日本語ロケール Windows では MSVC に `/utf-8` と `/openmp:experimental` が必須 (スパイクで確認済み)。`scripts/build_irodori_windows.bat` / `scripts/build_irodori_macos.sh` を新設
- **モデル配信**: endo5501 HF リポジトリに変換済み資産の一括アップロードが事前に必要 (計約3.5GB)
- **Dart 側**: `lib/features/tts/` の engine type / config / isolate / adapters / settings providers / 設定UI。既存の Qwen3 / Piper パスは非破壊 (sealed switch の網羅性エラーで追加漏れをコンパイル時検出)
- **合成パイプライン**: セグメントメモを caption として engine に渡す配線 (Irodori 選択時のみ)。メモ欄の UI・保存仕様は変更なし
- **実行時資産**: `model_specs/irodori_tts.json` を DLL と同梱 (または `AUDIOCPP_DEPLOYMENT_BUILD=ON` で埋め込み)
