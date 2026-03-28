## Context

リファレンス音声を使ったTTS合成では、毎回ECAPA-TDNNエンコーダで1024次元のスピーカーエンベディングを抽出している。同一のリファレンス音声からは常に同一のエンベディングが得られるため、この再計算は無駄である。gonwan/qwen3-tts.cppフォークでは`extract_speaker_embedding`と`synthesize_with_embedding`のAPI分離が実装されており、このアプローチを参考にキャッシュ機構を構築する。

現在のコールチェーン:
```
Dart TtsEngine.synthesizeWithVoice(text, refWavPath)
  → FFI → qwen3_tts_synthesize_with_voice(ctx, text, ref_wav_path)
    → load_audio_file() → resample → audio_encoder_.encode() → synthesize_internal()
```

## Goals / Non-Goals

**Goals:**
- リファレンス音声のスピーカーエンベディングをキャッシュし、2回目以降のエンコーダ推論をスキップする
- キャッシュは自動的・透過的に動作し、ユーザーが意識する必要がない
- リファレンス音声ファイルが変更された場合はキャッシュを自動的に無効化する

**Non-Goals:**
- エンベディングの手動管理UI（エクスポート/インポート等）
- seedパラメータの追加
- ggmlサブモジュールの更新
- エンベディングの編集・補間機能

## Decisions

### Decision 1: C API設計 — extract / synthesize_with_embedding / file I/O の3系統

gonwanのアプローチを参考に、以下の関数をC APIに追加する:

1. `qwen3_tts_extract_speaker_embedding(ctx, ref_wav_path, out_data, out_size)` — リファレンス音声からエンベディングを抽出（合成はしない）
2. `qwen3_tts_synthesize_with_embedding(ctx, text, emb_data, emb_size)` — 事前抽出済みエンベディングで合成
3. `qwen3_tts_save_speaker_embedding(path, data, size)` — エンベディングをバイナリファイルに保存
4. `qwen3_tts_load_speaker_embedding(path, out_data, out_size)` — バイナリファイルからエンベディングを読込
5. `qwen3_tts_free_speaker_embedding(data)` — C側で確保したエンベディングメモリを解放

**代替案**: ファイルI/OをDart側で実装する案も検討したが、エンベディングの保存/読込はシンプルなバイナリ操作（4KB）であり、C側で完結させることでFFIの往復回数を減らせる。

**保存フォーマット**: バイナリ形式（raw float32配列、4096バイト固定）。JSON形式は不要（Dart側でのみ使用し、人が直接編集する必要がない）。

### Decision 2: キャッシュキー — ファイル内容のSHA256ハッシュ

キャッシュキーとしてリファレンス音声ファイルのSHA256ハッシュを使用する。

- キャッシュファイルパス: `{LibraryParentDir}/cache/embeddings/{sha256_hex}.emb`
- ハッシュ計算はDart側(`crypto`パッケージ)で実施

**代替案**: ファイルパスベースのキャッシュも検討したが、ファイル内容が変更された場合（同名で別の音声に差し替え）にstaleキャッシュが使われるリスクがある。ハッシュベースならファイル内容の変更を自動検知できる。

### Decision 3: キャッシュ管理の責務分担

```
C API層: エンベディングの抽出・合成・ファイルI/O（低レベル操作）
Dart層:  キャッシュ判定ロジック（ハッシュ計算、キャッシュヒット判定、キャッシュ保存/読込の呼び出し）
```

キャッシュの判定フロー（Dart TtsEngine内）:
1. リファレンス音声ファイルのSHA256を計算
2. `cache/embeddings/{hash}.emb` が存在するか確認
3. 存在する → `load_speaker_embedding` → `synthesize_with_embedding`
4. 存在しない → `extract_speaker_embedding` → `save_speaker_embedding` → `synthesize_with_embedding`

### Decision 4: キャッシュの配置

`{LibraryParentDir}/cache/embeddings/{modelBasename}/` ディレクトリに配置する（例: `cache/embeddings/0.6b/`, `cache/embeddings/1.7b/`）。モデルごとにサブディレクトリを分離し、異なるモデル間でのキャッシュ汚染を防止する。既存の`voices/`ディレクトリとは分離し、キャッシュはいつでも削除可能な揮発性データとして扱う。

## Risks / Trade-offs

- **[リスク] SHA256計算コスト** → リファレンス音声は通常数MB程度。Dart側のSHA256計算は数ms程度で、エンコーダ推論(50-200ms)に比べて無視できるレベル。問題にならない。
- **[リスク] キャッシュの肥大化** → エンベディングは1ファイル4KBと極めて小さい。100個のリファレンス音声でも400KB。キャッシュクリーニングは不要。
- **[リスク] モデル変更時のキャッシュ無効化** → 異なるモデル（0.6B vs 1.7B）ではエンコーダの出力次元が異なる（0.6B: hidden_size=1024, 1.7B: hidden_size=2048）。キャッシュディレクトリをモデルごとに分離し（`cache/embeddings/{modelBasename}/`）、クロスモデル汚染を防止する。
- **[トレードオフ] エンベディングの次元検証** → `synthesize_with_embedding`呼び出し時にエンベディングサイズの検証（`transformer_.get_config().hidden_size`と一致すること）を行い、不正なキャッシュの使用を防止する。
