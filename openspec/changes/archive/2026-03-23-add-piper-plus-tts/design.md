## Context

NovelViewerのTTSは現在qwen3-tts単一エンジン構成。`TtsEngine` → `TtsNativeBindings` → `libqwen3_tts_ffi.dylib` という直結アーキテクチャで、エンジン抽象化レイヤーがない。TtsIsolate内で`TtsEngine`をハードコードしており、別エンジンへの切り替え機構がない。

piper-plusフォーク（https://github.com/endo5501/piper-plus）をFFI統合し、qwen3-ttsと共存させる。piper-plusはVITS系モデルでONNX Runtime推論を行い、CPUのみでリアルタイム比10〜50倍速の高速合成が可能。

## Goals / Non-Goals

**Goals:**
- piper-plusをqwen3-ttsと同じFFIパターンでネイティブ統合する
- 設定画面でエンジンを切り替え可能にする
- piper-plus固有の合成パラメータ（速度・抑揚・ノイズ）をUIで調整可能にする
- piper-plusモデルとOpenJTalk辞書のダウンロード機能を提供する
- 既存のqwen3-tts機能に影響を与えない

**Non-Goals:**
- GPU (CoreML/DirectML/CUDA) 対応 — まずCPU版のみ
- piper-plusの音声クローン機能（piper-plus自体が未対応）
- piper-plusのストリーミング合成 — 通常の`textToAudio`で十分高速
- 複数エンジンの同時利用（排他選択のみ）

## Decisions

### D1: C APIラッパーのインターフェース設計

qwen3-ttsのC API (`qwen3_tts_c_api.h`) と対称的なインターフェースを設計する。

```c
piper_tts_ctx* piper_tts_init(const char* model_path, const char* dic_dir);
int            piper_tts_is_loaded(const piper_tts_ctx* ctx);
void           piper_tts_free(piper_tts_ctx* ctx);
int            piper_tts_synthesize(piper_tts_ctx* ctx, const char* text);
int            piper_tts_set_length_scale(piper_tts_ctx* ctx, float value);
int            piper_tts_set_noise_scale(piper_tts_ctx* ctx, float value);
int            piper_tts_set_noise_w(piper_tts_ctx* ctx, float value);
const float*   piper_tts_get_audio(const piper_tts_ctx* ctx);
int            piper_tts_get_audio_length(const piper_tts_ctx* ctx);
int            piper_tts_get_sample_rate(const piper_tts_ctx* ctx);
const char*    piper_tts_get_error(const piper_tts_ctx* ctx);
```

**Rationale**: qwen3のパターンを踏襲することでDart FFIバインディングの実装コストを最小化。音声データはpiper内部のint16をC API層でfloat32に変換し、既存のDartコード（`Float32List`）との互換性を保つ。

**Alternatives**: Dart側でint16→float32変換する案もあったが、C API側で吸収する方がDart層の変更が少ない。

### D2: エンジン切り替えの実装レイヤー

TtsIsolateの`_isolateEntryPoint`内でエンジン種別に応じて分岐する。

```
LoadModelMessage
  + TtsEngineType engineType (qwen3 | piper)
  + String? dicDir           (piper用OpenJTalk辞書パス)

_isolateEntryPoint:
  if engineType == qwen3 → TtsEngine.open() (既存)
  if engineType == piper → PiperTtsEngine.open() (新規)
```

**Rationale**: 上位のTtsStreamingController/TtsGenerationController等はTtsIsolateのresponseストリームのみに依存しており、Isolate内部のエンジン切り替えだけで変更が完結する。共通インターフェース（abstract class）の導入も検討したが、実質的に2つのエンジンしかなく、Isolateのエントリーポイントでのif分岐で十分シンプル。

**Alternatives**: `TtsEngineInterface` abstract classを導入する案。将来エンジンが3つ以上になるなら有用だが、現時点ではYAGNI。

### D3: piper-plusの配置とビルド

```
third_party/
├── qwen3-tts.cpp/          (既存 - git submodule)
└── piper-plus/             (新規 - git submodule)
    ├── CMakeLists.txt      (既存 + PIPER_TTS_BUILD_SHARED追加)
    ├── src/cpp/
    │   ├── piper.hpp/cpp   (既存)
    │   ├── piper_tts_c_api.h   (新規)
    │   └── piper_tts_c_api.cpp (新規)
    └── (依存: fmt, spdlog, onnxruntime, openjtalk - CMake ExternalProject)
```

ビルドスクリプト:
- `scripts/build_piper_macos.sh` → `libpiper_tts_ffi.dylib` + `libonnxruntime.dylib` → `macos/Frameworks/`
- `scripts/build_piper_windows.bat` → `piper_tts_ffi.dll` + `onnxruntime.dll` → ビルド出力ディレクトリ

**Rationale**: piper-plusの依存（fmt, spdlog, onnxruntime, openjtalk）はすべてCMake ExternalProjectで自動ダウンロード・ビルドされるため、サブモジュール追加だけで済む。ONNX Runtimeはプリビルトバイナリがダウンロードされる（macOS: ~30MB）。

### D4: モデルとOpenJTalk辞書の管理

```
models/
├── qwen3-tts/              (既存)
│   ├── 0.6b/
│   └── 1.7b/
└── piper/                  (新規)
    ├── ja_JP-tsukuyomi-chan-medium.onnx
    ├── ja_JP-tsukuyomi-chan-medium.onnx.json
    └── open_jtalk_dic/     (OpenJTalk辞書 - 全日本語モデル共有)
```

ダウンロード元: HuggingFace（既存のqwen3-ttsと同じパターン）。OpenJTalk辞書はモデルと一緒にダウンロードし、辞書ディレクトリが存在すればスキップ。

**Rationale**: 辞書は全日本語モデルで共有のため、モデルごとに重複ダウンロードしない。ディレクトリ構造を`models/piper/`で分離し、qwen3-ttsとの混在を防ぐ。

### D5: 設定UIの構成

TTSタブの最上部にエンジン選択`SegmentedButton<TtsEngineType>`を配置。選択に応じて以下を表示:

- **qwen3-tts選択時**: 既存の設定をそのまま表示（言語、モデルサイズ、DL、参照音声）
- **piper選択時**: モデル選択ドロップダウン、モデルDL、lengthScale/noiseScale/noiseWスライダー

**Rationale**: 既存のモデルサイズ選択で`SegmentedButton`を使用しておりUIの一貫性がある。エンジンごとの設定項目が大きく異なるため、条件付き表示が自然。

### D6: 合成パラメータの設計

| パラメータ | Slider範囲 | デフォルト | 効果 |
|-----------|-----------|-----------|------|
| lengthScale | 0.5〜2.0 (step 0.1) | 1.0 | 速度（小=速い） |
| noiseScale | 0.0〜1.0 (step 0.05) | 0.667 | 表現力/ランダム性 |
| noiseW | 0.0〜1.0 (step 0.05) | 0.8 | 音素間長さ変動 |

パラメータはC API経由で設定（`piper_tts_set_length_scale`等）。piper_tts_ctx内のVoice.synthesisConfigに反映される。

## Risks / Trade-offs

- **[ONNX Runtimeのサイズ]** CPU版で~30MB。アプリサイズが増加する → 許容範囲と確認済み。将来的に必要ならONNX Runtime共有化を検討。

- **[OpenJTalk辞書の初回ダウンロード]** ~50MBの追加ダウンロード → モデルダウンロード時に一括で取得するため、ユーザー体験としては違和感なし。

- **[piper-plusフォークの保守]** 上流の変更に追従する必要がある → C APIラッパーは独立したファイル（`piper_tts_c_api.h/cpp`）のため、本体のマージコンフリクトは最小限。

- **[サンプルレートの違い]** qwen3-ttsとpiper-plusでサンプルレートが異なる可能性がある（piper: 通常22050Hz）→ `TtsSynthesisResult`にsampleRateを含めており、下流で適切に処理される。DB保存時もepisode単位でsample_rateを記録済み。

- **[日本語以外のモデル]** 初期実装はja_JP-tsukuyomi-chan-mediumのみ → モデル選択ドロップダウンを設計に含めているため、将来のモデル追加は容易。
