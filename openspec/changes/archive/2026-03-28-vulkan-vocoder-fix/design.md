## Context

qwen3-tts.cpp の vocoder（AudioTokenizerDecoder）は、モデルロード後に codebook テンソルを正規化する `normalize_codebooks()` を呼び出す。現在の実装は `codebook->data` ポインタに `ggml_fp16_t*` キャストで直接アクセスしており、テンソルが CPU メモリ上にある場合は動作するが、Vulkan バックエンドではデバイスマッピングされたメモリへの不正アクセスとなりセグフォルトする。

現在の endo5501 フォーク（コミット `5ec5c41`）には `upload_if_present()` による再アップロード処理が存在するが、その前段の `normalize_codebooks()` 内でクラッシュするため、Vulkan 環境では vocoder の GPU 実行に到達できない。

## Goals / Non-Goals

**Goals:**
- Vulkan バックエンド使用時の vocoder セグフォルトを解消する
- vocoder の codebook 正規化を GPU 安全な `ggml_backend_tensor_get/set` パターンで実装する
- Q8_0 量子化トークナイザーが存在する場合に自動的に優先選択する

**Non-Goals:**
- `gguf_loader.cpp` のバックエンドライフサイクル管理の変更（SiaoZeng の実測で現状でも GPU 実行が有効になることが確認済み）
- ストリーミング合成機能の追加（SiaoZeng フォークに含まれるが、現時点では不要）
- HTTP サーバー機能の追加
- エンベディングキャッシュ機能の追加

## Decisions

### 1. `normalize_codebooks()` の廃止とインライン化

**決定**: 既存の `normalize_codebooks()` メソッドとヘッダ宣言を削除し、`load_model()` 内に `normalize_and_upload` ラムダとしてインラインで実装する。

**理由**: SiaoZeng の修正と同じアプローチ。正規化と GPU アップロードは `load_model()` のコンテキストでのみ実行される一回限りの処理であり、独立メソッドにする必要がない。既存の `upload_if_present()` ラムダも不要になるため削除する。

**代替案**: `normalize_codebooks()` 内で `ggml_backend_tensor_get/set` を使う方法もあるが、メソッドのシグネチャ変更が必要になり、SiaoZeng の実証済みパターンから乖離するため不採用。

### 2. 3ステップ正規化パターン

**決定**: 以下の手順で正規化を行う。
1. `ggml_backend_tensor_get()` で GPU → ホストメモリにダウンロード
2. ホスト上の `std::vector<uint8_t>` バッファで `fp16 → fp32 → 除算 → fp32 → fp16` 正規化
3. `ggml_backend_tensor_set()` でホスト → GPU にアップロード

**理由**: GGML の公式 API を通じたメモリアクセスにより、バックエンド（CPU/Vulkan/Metal）に依存しない安全な処理が保証される。

### 3. Q8_0 トークナイザー自動選択

**決定**: `load_models()` で `qwen3-tts-tokenizer-q8_0.gguf` の存在を `fopen` でチェックし、存在すれば Q8_0 を優先、なければ従来の F16 にフォールバックする。

**理由**: Q8_0 は F16 比で約28%のメモリ削減が可能。ユーザが Q8_0 ファイルを配置するだけで自動的に利用される。既存の F16 のみの環境には影響しない。ただし、現在のモデルファイル検出ロジック（`*tokenizer*.gguf` パターン）との整合性を確認する必要がある。

## Risks / Trade-offs

- **[Risk] Q8_0 による音質劣化** → Q8_0 量子化は vocoder の codebook に適用されるため、音質への影響は軽微とされている。F16 フォールバックにより、ユーザが Q8_0 ファイルを配置しなければ従来通りの動作が保証される。
- **[Risk] バックエンド/バッファ不一致問題が残存** → SiaoZeng のベンチマーク（AMD Radeon 8060S）で `gguf_loader.cpp` 未修正のまま vocoder 656ms（GPU速度）を確認済み。ただし、異なる GPU ベンダー/ドライバでの挙動は未検証。改善が見られない場合は `gguf_loader.cpp` の修正を別途検討する。
- **[Risk] 既存のトークナイザー検出ロジックとの競合** → 現在の `load_models()` は `*tokenizer*.gguf` パターンで検出しており、Q8_0 と F16 の両方が存在する場合に複数マッチする可能性がある。Q8_0 優先選択は既存パターンマッチの前に特定ファイル名で直接チェックするため競合しない。
