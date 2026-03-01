## Context

現在の qwen3-tts.cpp は Qwen3-TTS-12Hz-0.6B-Base モデル専用に実装されている。テキストトークナイザーは `<|im_start|>assistant\n{text}<|im_end|>\n<|im_start|>assistant\n` というハードコードされたテンプレートのみをサポートし、`user` ロールの instruct テキストを渡す仕組みがない。

本家 Qwen3-TTS の CustomVoice モデルでは、instruct テキストを `<|im_start|>user\n{instruct}<|im_end|>\n` としてトークナイズし、text projection を通した embedding をテキスト embedding の前に配置することで、発話スタイルを制御する。instruct と text は別々にトークナイズされ、embedding 段階で結合される。

## Goals / Non-Goals

**Goals:**
- C++ パイプラインで instruct テキストをサポートし、CustomVoice モデルの発話スタイル制御を可能にする
- C API → Dart FFI → TtsEngine → TtsIsolate → Controller の全レイヤーで instruct パラメータを伝播する
- 既存の instruct なし合成との完全な後方互換性を維持する
- TTS 設定画面でグローバル instruct テキストを設定可能にする

**Non-Goals:**
- VoiceDesign モデル（テキスト記述による声質生成）のサポート
- セグメント毎の instruct オーバーライド（将来の拡張として検討）
- CustomVoice モデルの GGUF 変換スクリプトの修正（既存スクリプトで対応する前提）
- instruct テキストの自動生成（小説の場面から感情を推定する等）

## Decisions

### 1. instruct トークンと text トークンの分離トークナイズ

**決定**: `encode_instruct()` を新設し、instruct と text を別々にトークナイズする。

**理由**: 本家 Python 実装と同じアプローチ。`build_prefill_graph` で instruct embedding の位置を正確に制御するために、トークン列を分離する必要がある。単一のテンプレートに結合する方式では、prefill 構築時に instruct 部分と text 部分の境界を検出するのが困難。

**代替案**: `encode_for_tts_with_instruct(text, instruct)` で統合テンプレートを返す方式。却下理由: `build_prefill_graph` が instruct 部分と text 部分を区別して処理する必要があるため、境界の管理が複雑になる。

### 2. Prefill embedding における instruct の配置

**決定**: instruct embedding をテキスト role_embed の前に配置する。

```
[instruct_proj(全tokens)] [role_embed(3)] [codec_overlay] [first_text+codec_bos]
```

**理由**: 本家 Python 実装の `talker_input_embeds` の順序に従う。instruct embedding には codec overlay を合成せず、純粋な text_projection のみを適用する。

### 3. C API の拡張方式

**決定**: 既存関数を変更せず、新しい関数を追加する。

```c
qwen3_tts_synthesize_with_instruct(ctx, text, instruct)
qwen3_tts_synthesize_with_voice_and_instruct(ctx, text, ref_wav_path, instruct)
```

**理由**: 後方互換性の維持。既存の FFI バインディングや他のクライアントコードを壊さない。instruct が NULL の場合は従来の動作と同一。

**代替案**: 既存関数のシグネチャを変更する方式。却下理由: ABI 破壊を伴い、既存のビルドアーティファクトとの互換性が失われる。

### 4. instruct 設定のスコープ

**決定**: まずグローバル設定（全セグメント共通）として実装する。

**理由**: セグメント毎の instruct オーバーライドは DB スキーマ変更と TtsEditDialog の大幅な UI 変更を伴う。グローバル設定で基本機能を確立し、利用パターンを観察してから拡張する。

### 5. デフォルト引数によるシグネチャ拡張

**決定**: C++ 内部の `generate()` / `build_prefill_graph()` はデフォルト引数 (`nullptr, 0`) で拡張する。

**理由**: 既存のコードパスを変更せずに instruct 対応を追加できる。instruct_tokens が nullptr の場合は従来の処理フローをそのまま実行する。

## Risks / Trade-offs

**0.6B CustomVoice モデルの instruct 対応が限定的な可能性** → 本家 Python コードに 0.6B で instruct を無効化するコードパスがある。Phase 1 で Python 側検証を行い、動作しない場合は 1.7B モデルに切り替え。1.7B はメモリ使用量が約 3 倍になる。

**`build_prefill_graph` の改修リスク** → 現在の実装は精密なインデックス操作に依存しており、instruct embedding の挿入でオフセット計算を誤るリスクがある。Python リファレンス実装の出力と数値比較検証で対策する。

**user トークン ID の語彙存在** → BPE 語彙に "user" が単一トークンとして存在しない可能性がある。"Ġuser"（スペース付き）のフォールバック検索で対策。assistant トークンと同じパターンを踏襲。

**KV キャッシュサイズの増加** → instruct トークンの追加で prefill が長くなる。`required_ctx` の計算が `prefill_len + max_len + 8` のため自動的に対応されるが、長い instruct テキストでメモリ不足になる可能性がある。instruct テキストの最大長を制限することで対策。
