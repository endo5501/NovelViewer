## Context

qwen3-tts.cpp は Qwen3-TTS モデルの GGUF 推論エンジン。現在 0.6B モデルのみ対応している。1.7B モデルは同じ Qwen2 ベースの Talker アーキテクチャだが、Talker の hidden_size が 1024→2048 に拡大。Code Predictor の hidden_size は 1024 のまま据え置きのため、Talker 出力を Code Predictor に渡す前に `small_to_mtp_projection` 線形層 (2048→1024) で次元を落とす必要がある。

検証済みの事実:
- 変換スクリプト `convert_tts_to_gguf.py` は 1.7B の safetensors を変換でき、478 テンソルを出力する（2 テンソルがスキップ: `small_to_mtp_projection.weight/bias`）
- C++ エンジンの `parse_config()` は GGUF メタデータから hidden_size=2048, n_layers=28 等を正しく読み取る
- Talker transformer 部分はそのまま動作するが、Code Predictor にhidden_size=2048 の出力が直接渡されるため推論がハングする
- code_pred.codec_embd の次元も [2048, 1024] → [2048, 2048] に変化している（hidden_size に連動）

## Goals / Non-Goals

**Goals:**
- 1.7B モデルの GGUF 変換・推論を qwen3-tts-cli で完全に動作させる
- 0.6B モデルとの後方互換性を維持する（プロジェクション不要な場合はスキップ）
- モデルファイル名をハードコードせず、ディレクトリ内のファイルを動的に検出する

**Non-Goals:**
- NovelViewer (Flutter) 側のUI変更やモデルダウンロード対応（別 change で対応）
- 量子化 (Q4, Q8) への対応
- ストリーミング推論の最適化

## Decisions

### Decision 1: プロジェクション層の条件分岐方式

**選択**: GGUF メタデータから talker.hidden_size と code_pred.hidden_size を比較し、異なる場合のみプロジェクション層を適用する。

**理由**: 0.6B では talker.hidden_size == code_pred.hidden_size (= 1024) でプロジェクション不要。1.7B では talker.hidden_size (2048) > code_pred.hidden_size (1024) でプロジェクション必要。この条件をテンソル有無ではなく次元比較で判定することで、将来別サイズのモデルにも対応できる。

**代替案**: プロジェクション用テンソルの存在有無で判定 → テンソル名に依存するため脆い

### Decision 2: モデルファイル名の動的検出とディレクトリ分離

**選択**: モデルディレクトリ内から `qwen3-tts-*.gguf` パターンに一致するファイルを検索し、`tokenizer` を含まないものを TTS モデル、含むものを vocoder として自動判別する。TTS モデルファイルは1つだけ存在する前提とし、複数見つかった場合はエラーとする。0.6B と 1.7B はそれぞれ別ディレクトリに配置する運用を想定する。

```
models/
├── 0.6b/
│   ├── qwen3-tts-0.6b-f16.gguf
│   └── qwen3-tts-tokenizer-f16.gguf
└── 1.7b/
    ├── qwen3-tts-1.7b-f16.gguf
    └── qwen3-tts-tokenizer-f16.gguf
```

NovelViewer 側では将来「軽量モード/詳細モード」として設定画面でディレクトリを切り替える想定（本 change のスコープ外）。tokenizer ファイルの共有最適化も NovelViewer 対応時に検討する。

**理由**: 現在 `qwen3-tts-0.6b-f16.gguf` がハードコードされており、1.7B の `qwen3-tts-1.7b-f16.gguf` や将来の別名ファイルに対応できない。ディレクトリ内の自動検出で柔軟性を確保しつつ、ディレクトリ分離により曖昧さを排除する。

**代替案**:
- 同一ディレクトリに複数モデルを置いて自動選択 → 曖昧で予測しにくい
- CLI に `--model-file` オプション追加 → `-m` との使い分けが紛らわしい

### Decision 3: プロジェクション層の実装箇所

**選択**: `TTSTransformer::generate()` 内で、Talker の forward_step 出力を Code Predictor に渡す直前にプロジェクション (matmul + bias) を適用する。

**理由**: プロジェクション層は Talker と Code Predictor の間のブリッジであり、generate() のメインループ内で適用するのが自然。既存の `predict_codes_autoregressive()` のインターフェイス (hidden_size 次元の入力) を変えずに済む。

## Risks / Trade-offs

- **メモリ使用量の増加**: 1.7B モデルは F16 で約 3.9GB。M3 Max (96GB) では問題ないが、メモリの少ない環境では動作が重い可能性がある → low_mem_mode の活用で緩和可能
- **推論速度の低下**: hidden_size が 2 倍になるため、Talker の推論速度は約 2-3 倍遅くなる → これはモデルサイズに伴う本質的なトレードオフ
- **code_pred.codec_embd の次元変化**: 0.6B [2048, 1024] → 1.7B [2048, 2048]。C++ 側は `create_tensors()` で GGUF からテンソル形状を読むため、自動的に対応されるはず → 検証で確認
