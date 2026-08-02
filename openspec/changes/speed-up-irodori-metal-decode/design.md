## Context

### upstream との乖離状況

```
        merge-base a0f3b4c (2026-07-18)
               │
   ┌───────────┴────────────┐
 ours (endo5501)        upstream (0xShug0)
 18 commits             145 commits (→ 2026-08-01)
 21 files               890 files
```

両側が変更したファイルは 6 本のみ、`git merge-tree` のドライランで実際に競合するのは 4 本 (`CMakeLists.txt`, `src/framework/audio/wav_reader.cpp`, `app/server/runtime.cpp`, `docs/usage.md`) である。Irodori エンジン本体 (`src/models/irodori_tts/`) への upstream 変更は `83b87d6` の名前空間リネームのみで、我々の C API が使う `engine/framework/runtime/{model,registry,session}.h` も API 互換を保っている。

このうち本 change が扱うのは Metal 最適化 2 件に限る。フルマージは別 change とする。

### 既存の計測資産

Irodori の session は既に必要な計時を出力している (`src/models/irodori_tts/session.cpp:683-698`)。

| ログ名 | 内容 |
|---|---|
| `irodori_tts.prepare_reference_ms` | 参照音声の準備 |
| `irodori_tts.tokenize_ms` | トークナイズ |
| `irodori_tts.condition_ms` | condition encoder |
| `irodori_tts.sample_rf_ms` | RF-DiT サンプリング (+ `context_cond` / `context_cfg` / `steps_cfg` / `steps_cond` の内訳 4 本) |
| **`irodori_tts.codec_decode_ms`** | **codec デコード = ConvTranspose1d が動く区間** |
| `session.wall_ms` | セッション全体 |

出力形式は `src/framework/debug/trace.cpp:320-327` の `[TIMING ts=<秒>] <name> <value>` で、`--log` (stdout) または `--log-file <path>` で有効化される。

**つまり計装は不要で、パースだけを実装すればよい。** これが本 change の実現性を支える中心的な事実である。

## Goals / Non-Goals

**Goals:**

- Irodori-TTS の段階別性能 (特に `codec_decode_ms`) を再現可能な条件で測定できるようにする。
- upstream の Metal ConvTranspose 最適化 2 件をフォークに取り込み、その効果を実測値で示す。
- 測定路を Windows / macOS 両方で動作させ、将来 Vulkan 側の最適化を検討する際のベースラインとする。

**Non-Goals:**

- upstream 145 コミットのフルマージ。別 change とする。
- Vulkan バックエンドの `conv_transpose_1d` 最適化。upstream に該当変更は存在せず、自前実装は本 change の範囲外。
- Flutter アプリ側の性能改善。`lib/` は一切触らない。
- upstream の検証レポート (`306673c`) の取り込み。
- Irodori 以外の audio.cpp モデルの測定。

## Decisions

### D1. 主指標を `decode_ms` とし、「効果が出ない = 失敗」としない

**決定**: 受け入れ基準は「before / after が同一条件で測定でき、`decode_ms` の変化が記録されたこと」とする。数値目標は設定しない。

**理由**: upstream の実測値は `cdd5196` 単独で Irodori E2E `-4.94%` であり、測定ノイズに埋もれうる幅である。一方 `c810a06` は conv_transpose カーネル自体を 5.6 倍高速化するが、E2E への寄与は Irodori の `codec_decode_ms` が `session.wall_ms` に占める割合に完全に依存する。RF-DiT サンプリングが支配的なら、デコードが 5 倍速くなっても E2E は数 % しか動かない。

その場合でも「変更は正しく効いたが Irodori のボトルネックは `sample_rf_ms` にある」という結論が得られる。これは次に何を最適化すべきかを決める材料であり、失敗ではない。

**却下した案**: E2E の改善率に閾値を設ける。ノイズと真の効果を区別できず、また効果が小さいという事実そのものが持つ情報価値を捨ててしまう。

### D2. チェリーピックを残すか revert するかの判断基準

D の測定後、以下で判断する。

| 測定結果 (中央値) | 判断 |
|---|---|
| `decode_ms` が改善し、`total_ms` が baseline の +2% 以内 | **残す** |
| `decode_ms` が悪化 | **revert** し、原因を別 change で調査 |
| どちらも ±2% 以内 (有意差なし) | **残す** |

3 行目を「残す」とするのは、upstream 追随の負債を減らす価値があり、かつ変更が Metal 経路に限定されていて Windows に影響しないためである。

### D3. 計時ログの取得は `--log-file` を使う

**決定**: `audiocpp_cli` には `--log-file <path>` を渡し、専用ファイルに書かせる。

**理由**: `--log` は stdout に流れるが、CLI は同じ stdout に通常の進捗も出す。ファイルに分離すればパーサが他の出力に影響されない。既存の qwen3 経路が stderr をキャプチャしているのと構造が揃う (`run_once()` がファイルパスを返す既存の契約をそのまま使える)。

### D4. Irodori の計時を既存 JSON スキーマにマップし、生の内訳も併記する

**決定**: 正規 5 フィールドは 1 対 1 でマップし、Irodori 固有の内訳は `engine_timings` オブジェクトとして各 run に併記する。

| JSON フィールド | Irodori の計時ログ |
|---|---|
| `tokenize_ms` | `irodori_tts.tokenize_ms` |
| `encode_ms` | `irodori_tts.condition_ms` |
| `generate_ms` | `irodori_tts.sample_rf_ms` |
| `decode_ms` | `irodori_tts.codec_decode_ms` ← **主指標** |
| `total_ms` | `session.wall_ms` |
| `engine_timings` | `prepare_reference_ms` および `sample_rf.*` の内訳 4 本 |

**理由**: 既存スキーマを壊さずに qwen3 と同じ形で読めるようにしつつ、合算や切り捨てで情報を失わない。特に `sample_rf.*` の内訳は、D1 で述べた「ボトルネックがどこか」の判断に直接使う。

**却下した案**: `encode_ms` を `condition_ms + prepare_reference_ms` の合算とする。参照音声を渡さない素 TTS ベンチでは `prepare_reference_ms` がほぼ 0 になるため合算の意味が薄く、かつ合算は元の値を復元できない。

### D5. `rtf` と `audio_duration_s` は Irodori 経路では `null` を出す

**決定**: Irodori は音声長を計時ログに出さないため、これら 2 フィールドは `null` とする。

**理由**: 出力 WAV のヘッダから導出することは可能だが、チャンク走査のパーサとフィクスチャ WAV が追加で必要になり、本 change の主目的に対して割に合わない。0 を書くと「測定した結果 0 だった」と誤読されるため `null` とする。既存 spec が必須としている JSON フィールドは `timestamp` / `model` / `text` / `language` / `runs` / `median` であり、`rtf` はそこに含まれない。

### D6. 決定論の確保は `--seed` で行う (`--temperature 0` ではない)

**決定**: Irodori 経路では `--seed <固定値>` を渡す。

**理由**: Irodori は RF-DiT (flow matching) であり、`session.cpp:114-118` が `seed` リクエストオプションを読み、**未指定なら `random_u32_seed()` で毎回変わる**。`--temperature 0` は自己回帰サンプリング用の既存 qwen3 経路の作法であって Irodori には効かない。seed 未指定のまま測ると RF ステップの軌道が run ごとに変わり、before/after の比較が成立しない。

### D7. モデルスペック解決は `--model-spec-override` で明示する

**決定**: `audiocpp_cli` には `--model-spec-override <audio.cpp>/model_specs` を明示的に渡す。

**理由**: CLI は既定でリポジトリ相対の `model_specs/` を探すため、カレントディレクトリ依存になる。明示すれば測定が起動場所に左右されない。

### D8. ⚠️ CLI で測った数字はアプリの数字ではない

`audiocpp_cli` と `audiocpp_ffi` はモデルスペックの解決経路が異なる。

```
audiocpp_cli   →  リポジトリ相対の model_specs/ (D7 で明示指定)
audiocpp_ffi   →  macOS:   ライブラリ埋め込み (AUDIOCPP_DEPLOYMENT_BUILD)
                  Windows: DLL 隣の model_specs/irodori_tts.json
```

推論エンジン本体 `engine_runtime` は両者で共通なので、**ConvTranspose の改善を測る目的には妥当**である。ただしモデルロード時間、Dart FFI 越えのオーバーヘッド、アプリ側のバッファリングは含まれない。`benchmarks/*.json` の数値をアプリの体感速度として引用してはならない。

### D9. 実装環境の分業

| 作業 | 環境 | 根拠 |
|---|---|---|
| ベンチスクリプトのパーサ実装とテスト | **Windows で可** | フィクスチャログを使うため OS 非依存 |
| `build_irodori_windows.bat` の CLI ターゲット追加 | Windows | |
| チェリーピックと push | **Windows で可** | git 操作のみ |
| `build_irodori_macos.sh` / `verify_irodori_macos.sh` | macOS | |
| ベースライン測定 (B) / 効果測定 (D) | **macOS 必須** | Metal 実行が要る |

`c810a06` が触る `ggml-metal-*.{h,cpp,metal}` は Windows (Vulkan) ビルドで一切コンパイルされないため、Windows では検証不能かつ破壊もされない。一方 `cdd5196` が触る `conv_modules.cpp` と `miocodec/graph_ops.cpp` は Windows でもコンパイルされるので、ビルドが壊れていないことは Windows で確認できる。

### D10. 測定の作法

- **直列実行**。GPU ベンチマークを並列に走らせない。
- 同一マシン / 同一モデル / 同一テキスト / 同一 seed / 他アプリ停止。
- 既存 `benchmark_tts.sh` の作法を踏襲: ウォームアップ 1 回 + 計測 3 回、中央値を採用。
- B と D の間で変わるのは submodule pointer のみとする。ベンチスクリプト自体を D の直前に変更してはならない。

## Risks / Trade-offs

- **`.metal` シェーダのコンパイル検証が macOS でしかできない** → upstream で検証済みかつ `git apply --3way --check` で 3 ファイル clean。それでも失敗した場合は macOS 側で修正し、submodule ブランチに追加コミットする。
- **`cdd5196` が `conv_modules.cpp` で競合する** → 競合の実体は fast path ゲートに `BackendType::Metal` を足す 3 行のみ。手当ては容易だが、`miocodec/graph_ops.cpp` の 62 行は clean apply される点に注意 (ゲートだけ入って本体が入らない、という半端な状態を作らないこと)。
- **効果が測定ノイズに埋もれる** → D1 の通り失敗としない。加えて `engine_timings` の内訳 (D4) を残すことで、E2E が動かなかった理由を後から説明できるようにする。
- **`benchmarks/` が qwen3 の古い結果 (2026-03) と混在する** → JSON に `engine` フィールドを追加して識別可能にする。既存ファイルには `engine` がないため、欠落は `qwen3` とみなす。
- **submodule の 2 段 push を忘れる** → submodule 側を push する前に NovelViewer の pointer を push すると、macOS 側で `git submodule update` が失敗する。tasks.md で順序を明示する。

## Migration Plan

```
A. 測定路の整備 (Windows)          ┐
   ↓                              │ A と B は並行可
B. ベースライン測定 (macOS)        ┘   ただし B は A の完了を待つ
   ↓
C. チェリーピック (Windows)
   submodule push → NovelViewer pointer 更新 → push
   ↓
D. 効果測定 (macOS)
   git pull → git submodule update → ビルド → 測定
   ↓
   D2 の判断基準で残す / revert を決定
```

**ロールバック**: C の submodule pointer 更新を revert すれば元に戻る。A の測定路は独立して価値があるため残す。

## Open Questions

- `rtf` / `audio_duration_s` を出力 WAV ヘッダから導出するか (D5 で今回は見送り)。ベンチマークを継続的に使うなら後追いで足す価値がある。
- ベースライン測定で `codec_decode_ms / session.wall_ms` の比率が小さかった場合、`sample_rf.*` の内訳のどれを次の最適化対象にするか。D の測定結果を見てから判断する。
- upstream フルマージ (残り 143 コミット、特に model spec v1 移行と `AUDIOCPP_MODEL_SET=custom` によるビルド絞り込み) を別 change としていつ着手するか。
