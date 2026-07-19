# Design: Add Irodori TTS Engine (audio.cpp)

## Context

NovelViewer は qwen3-tts.cpp / piper-plus を「endo5501 フォーク + 自前 C shim + 共有ライブラリ + Dart FFI」の型で統合済み。本変更は同じ型で audio.cpp (endo5501/audio.cpp フォーク) を第3エンジンとして追加し、Irodori-TTS-600M-v3-VoiceDesign による「ボイスクローニング×caption 併用」を実現する。

2026-07-19 スパイクでの確証事項 (memory: project-irodori-tts-engine-frozen 参照):
- クローン・caption・両立とも実用品質 (ユーザ耳判定済み)。両立の調整は `speaker_guidance_scale` (既定5.0) と `caption_guidance_scale` (既定3.0)
- Vulkan backend が RX 6800 で動作、48kHz 出力、ウォーム RTF≈0.3。日本語ロケール MSVC は `/utf-8` + `/openmp:experimental` 必須
- audio.cpp は `BUILD_SHARED_LIBS OFF` 強制・C ABI なし → shim 必須。生成ループは `src/models/irodori_tts/session.cpp` の per-step for ループ (既定40 step) で abort 注入が容易
- C++ API: `make_default_registry() → load(ModelLoadRequest) → create_task_session(TaskSpec, SessionOptions) → run(TaskRequest) → TaskResult.audio_output`
- 実行時に `model_specs/irodori_tts.json` が必要

セグメントメモ欄 (`TtsEditSegment.memo`) は元々 caption 用途のために用意されたフィールドであり、qwen3 がクローンと caption を併用できないため汎用メモのまま眠っていた。本変更でこれを caption として消費する。

## Goals / Non-Goals

**Goals:**
- `TtsEngineType.irodori` を第3エンジンとして追加 (Qwen3 / Piper は非破壊)
- クローン (既存ボイス参照ライブラリ) × caption (セグメントメモ) の併用合成
- 必須要件の中断 (abort) を qwen3 と同等の応答性設計で実現
- Windows (Vulkan) / macOS (Metal)、CPU フォールバック
- モデル資産の自動ダウンロード (endo5501 HF リポジトリ)

**Non-Goals:**
- Irodori-TTS-500M-v3 対応 (600M が全ユースケースを賄うため)
- ストリーミング合成 (既存エンジン同様、全量生成→再生)
- Irodori 用ディスク話者埋め込みキャッシュ (audio.cpp セッション内蔵のインメモリ参照話者キャッシュに委ねる。qwen3 の `.emb` キャッシュ相当は将来課題)
- audio.cpp の他モデル (VibeVoice 等) の露出
- 日本語以外の言語対応 (Irodori は ja 専用)

## Decisions

### D1: in-process FFI 統合 (サーバ方式は不採用)
`audiocpp_server` をサブプロセス起動する案はプロセス管理・同梱・レイテンシの複雑さがあり、ユーザの方向性 (ネイティブ組み込みが本来形。サーバは Python 本家しかなかった時代の次善策) に反するため不採用。qwen3-tts.cpp と同型の in-process FFI とする。

### D2: フォークに shim と abort パッチを置く
`third_party/audio.cpp` は endo5501/audio.cpp フォークの git submodule とする (piper-plus / qwen3-tts.cpp と同じ管理形態)。以下はフォーク側にコミットする:
- `src/audiocpp_c_api.{h,cpp}` — C ABI shim
- CMake: `AUDIOCPP_BUILD_SHARED` オプションで `audiocpp_ffi` 共有ライブラリターゲット追加 (engine_runtime を静的リンク)
- `src/models/irodori_tts/session.cpp` の RF ループへの abort チェック注入 (数行)

理由: 上流 (0xShug0) は共有ライブラリも C ABI も提供しない方針のため、この差分は恒久的にフォーク側で保守する。qwen3/piper で実績のある形。上流追従はタグ単位で必要時のみ rebase。

### D3: C API は qwen3_tts_c_api の形を踏襲し、caption を第一級引数にする
```c
audiocpp_abort_handle * audiocpp_create_abort_handle(void);
void  audiocpp_free_abort_handle(audiocpp_abort_handle *);
void  audiocpp_abort(audiocpp_abort_handle *);        // 任意スレッドから可
void  audiocpp_reset_abort(audiocpp_abort_handle *);

audiocpp_ctx * audiocpp_init(const char * model_dir, int n_threads,
                             audiocpp_abort_handle * handle);   // handle は ctx と独立所有
int   audiocpp_is_loaded(const audiocpp_ctx *);
void  audiocpp_free(audiocpp_ctx *);

// ref_wav_path / caption は NULL 可。NULL の組み合わせで
// 素TTS / クローンのみ / caption のみ / 両立 の4形態を1関数で表現
int   audiocpp_synthesize(audiocpp_ctx *, const char * text,
                          const char * ref_wav_path, const char * caption,
                          float speaker_guidance_scale, float caption_guidance_scale,
                          int num_inference_steps);

const float * audiocpp_get_audio(const audiocpp_ctx *);
int   audiocpp_get_audio_length(const audiocpp_ctx *);
int   audiocpp_get_sample_rate(const audiocpp_ctx *);   // 48000
const char *  audiocpp_get_error(const audiocpp_ctx *);
```
理由: qwen3 の synthesize / synthesize_with_voice / synthesize_with_embedding の3関数分裂は embedding キャッシュ由来の歴史的経緯。Irodori はセッション内蔵キャッシュがあるため1関数+NULL可引数で十分であり、Dart 側分岐も減る。abort handle の独立ライフタイム設計は qwen3 F111 (UAF 根治) の教訓をそのまま採用する。

内部実装: shim は `make_default_registry()` → `load({model_dir, family_hint:"irodori_tts"})` → `create_task_session()` を init で行い、synthesize ごとに `TaskRequest{text_input, voice(ref_wav), options{caption, no_ref, ...}}` を構築して `run()` する。参照 WAV の読み込み・リサンプルは audio.cpp 側ユーティリティを利用する。

### D4: abort は RF per-step ループへのフラグチェック注入
フォークの `IrodoriTTSSession` 実行パス (RF サンプラの per-step ループ、既定40 step) の各ステップ先頭で `std::atomic<bool>` の abort フラグを確認し、セット時は即座にエラー復帰する。中断応答性は合成時間の約 1/40 + 後段 codec デコード (不可分) で、qwen3 のトークンループ中断と同等の体感。ggml の abort_callback 連携は初版では行わない (per-step 粒度で要件を満たすため)。

### D5: バックエンドは GPU 優先 + CPU フォールバック
shim の init で Windows: Vulkan → CPU、macOS: Metal → CPU の順に試行する (qwen3_tts_ffi の「GPU/Metal 優先 + CPU フォールバック」と同じ振る舞い)。ビルドは Windows: `ENGINE_ENABLE_VULKAN=ON` (スパイク実証済みフラグ: `/utf-8`, `/openmp:experimental`)、macOS: `ENGINE_ENABLE_METAL=ON`。

### D6: model spec JSON は DLL に同梱ファイルとして配布
`model_specs/irodori_tts.json` を実行ファイル配置ディレクトリに同梱し、shim init が実行ファイル相対で解決して `model_spec_override` に渡す。`AUDIOCPP_DEPLOYMENT_BUILD=ON` による埋め込みが機能すればファイル同梱は不要になるが、検証コストを踏まえ「同梱ファイル + override」を確実な既定とし、埋め込みは実装時に動作確認できた場合のみ採用する。

### D7: モデル資産は endo5501 HF リポジトリから一括ダウンロード
qwen3 (`endo5501/qwen3-tts.cpp` から resolve) と同じ方式で、endo5501 の HF リポジトリに以下のレイアウトで変換済み一式をホストし、既存ダウンロードサービスの型 (進捗・検証・リトライ) を踏襲した `IrodoriModelDownloadService` を新設する:
```
models/
├── Irodori-TTS-600M-v3-VoiceDesign/   (model.safetensors, model_config.json ほか)
├── llm-jp-3-150m/                      (tokenizer.json)
└── Semantic-DACVAE-Japanese-32dim/     (weights.safetensors ← pth から変換済みを配置)
```
理由: DACVAE は HF 上流 (Aratako) が weights.pth のみで、変換には torch が必要 (アプリに同梱不可)。変換済み safetensors の自前ホストが唯一の現実解。アップロードは実装前の手動準備タスクとする。

### D8: caption はセグメントメモから合成時パラメータとして渡す
- `IrodoriEngineConfig` (sealed 第3サブクラス): `modelDir` / `sampleRate=48000` / `refWavPath` / `speakerGuidanceScale` / `captionGuidanceScale` / `numInferenceSteps`。caption は **設定ではなく合成時パラメータ** であり config に持たせない (qwen3 の refWavPath が synthesis-time であるのと同じ整理)
- `modelLoadKey` は `(type, modelDir)` のみ。guidance / steps / refWavPath / caption は合成時に渡し、モデル再ロードを発生させない
- TtsIsolate の合成リクエストに `caption` (String?) を追加。Irodori ブランチのみ消費し、qwen3/piper ブランチは無視する
- 呼び出し側 (ストリーミングパイプライン / 編集ダイアログの再生成) は、エンジンが Irodori のとき `TtsEditSegment.memo` を caption として渡す。メモ null/空 → caption なし (クローンのみ)。メモ欄の UI・保存仕様は不変
- 初回一括生成時はメモが存在しないため caption なしで生成され、編集ダイアログでメモ記入→再生成で caption が効く、という運用になる

### D9: 設定 UI は Piper セクションの型を踏襲
`IrodoriSettingsSection` (ConsumerStatefulWidget) を新設: モデルダウンロード (進捗/再試行)、speaker_guidance_scale スライダー、caption_guidance_scale スライダー、num_inference_steps。参照音声は既存の `VoiceReferenceSection` を共用 (qwen3 と同じ voices ライブラリ・`ttsRefWavPathProvider` を参照)。ラベルは3言語 ARB 必須。エンジン選択 SegmentedButton は3値になる。

## Risks / Trade-offs

- [engine_runtime が 30+ モデル全部入りで DLL が肥大 (数十MB)] → 初版は許容。フォーク側 CMake でモデル選別する最適化は将来課題として切り離す
- [上流 audio.cpp の開発が速く (0.3.x)、フォークが陳腐化する] → タグピン留め + 「必要時のみ rebase」。Piper で学んだ model/runner 版数結合 (memory: project-piper-model-runner-mismatch) と同じ罠のため、モデル資産も HF 自前ホストで凍結しランナーと常に対で更新する
- [Vulkan が多様な GPU で未検証 (上流 preset も Vulkan 未サポート)] → CPU フォールバックを必ず実装。CPU 時は 40 step 拡散が遅い可能性 → num_inference_steps を下げる余地を設定 UI に持たせる
- [caption と参照話者の綱引きで期待と違う声になる] → guidance scale 2種を設定 UI に露出し、ユーザが調整可能にする (スパイクでの実測ノブ)
- [ggml の二重埋め込み (qwen3_tts_ffi / audiocpp_ffi)] → Windows は DLL 分離、macOS は two-level namespace で衝突なし。両エンジン同時ロード時のメモリ増は許容 (モデル切替時に旧エンジンは dispose される)
- [HF 自前ホストの帯域/容量 (約3.5GB)] → qwen3 で同方式の実績あり。HF は無料枠で十分
- [Aratako モデルの再配布ライセンス確認] → アップロード前に Irodori-TTS-600M-v3-VoiceDesign / Semantic-DACVAE のライセンス表記を確認し、必要な帰属表示を HF リポジトリに記載する

## Migration Plan

追加のみで既存エンジンに非破壊。ロールバックはエンジン選択を qwen3/piper に戻すだけ (SharedPreferences 既定は qwen3 のまま)。sealed switch の網羅性により、追加漏れはコンパイルエラーで検出される。

## Open Questions

- `AUDIOCPP_DEPLOYMENT_BUILD=ON` での spec 埋め込みが shim 経由でも機能するか (機能すれば D6 の同梱ファイルを省略可) — 実装時に確認
- macOS Metal での Irodori 動作 (スパイクは Windows/Vulkan のみ) — macOS ビルドタスクで検証
- 初回一括生成に既定 caption を適用したいニーズが出るか (現設計はメモ記入済みセグメントのみ caption) — 使用感を見て将来判断
