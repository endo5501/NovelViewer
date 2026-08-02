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

### D11. パーサは独立ファイルに置き、CR 除去と最終 run 採用を行う

**決定**: パーサは `scripts/lib/benchmark_timing_parse.sh` に置き、`benchmark_tts.sh` から source する。パーサは CR を除去し、同名の TIMING が複数ある場合は**最後**の値を採用する。

**理由 (配置)**: `benchmark_tts.sh` は関数定義の前後にトップレベルの実行コードを持つため、テストから source するとベンチマークが起動してしまう。`main()` 化する案は既存の qwen3 経路への回帰リスクがあり、タスク 2.6 の「無変更で動作すること」と衝突する。

**理由 (CR と最終 run)**: 実装調査で `trace.cpp:46` が `std::ofstream(*state.file_path, std::ios::app)` を使っていることが判明した。ここから 2 つの要求が導かれる。

- **テキストモード** (`std::ios::binary` 指定なし) のため、MSVC は `\n` を `\r\n` に変換する。Windows で取得したログの値には CR が付く。
- **追記モード** (`std::ios::app`) のため、同一パスを再利用するとログが蓄積する。ベンチマークは run ごとに別パスを渡すが、パーサ側でも最後の値を採るほうが安全である。

加えて `[TRACE ts=...] <name> <value>` は `[TIMING ...]` と行構造が同一であるため、パーサは TIMING タグでアンカーし、名前は前方一致ではなく完全一致で比較しなければならない (`sample_rf_ms` は `sample_rf.context_cond_ms` の接頭辞であり、`condition_ms` は `*_cond_ms` と部分文字列を共有する)。

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

## 測定結果

### 測定条件

| 項目 | 値 |
|---|---|
| マシン | MacBook Pro M3 Max / 96 GB |
| バックエンド | Metal |
| モデル | `Irodori-TTS-600M-v3-VoiceDesign` |
| テキスト | `benchmark_tts.sh` の既定 (日本語 1 文) |
| seed | 1234 (両測定で同一) |
| 試行 | ウォームアップ 1 回 + 計測 3 回、中央値、直列実行 |
| before | `benchmarks/baseline-eda8e83.json` (`engine_revision` = `eda8e83`, ggml `novelviewer-v1-15-geda8e83`) |
| after | `benchmarks/after-7b2a3c4.json` (`engine_revision` = `7b2a3c4`, ggml `novelviewer-v1-17-g7b2a3c4`) |

生の結果 JSON は本 change ディレクトリ配下に置いた。`benchmarks/` はリポジトリの `.gitignore` 対象 (各環境の一時的な計測結果を置く場所) であり方針は変えていない。この 2 ファイルは通常の計測結果ではなく後述の判定を支える証跡であり、`engine_timings` の内訳が次の最適化対象の判断材料になるため、change とともにアーカイブされる場所に残した。

### ベースライン (チェリーピック前, macOS / Metal)

中央値 (ウォームアップ 1 回 + 計測 3 回, seed 1234, 既定テキスト):

| 段階 | 中央値 (ms) | wall 比 |
|---|---:|---:|
| `tokenize_ms` | 0.172 | 0.00% |
| `encode_ms` (condition) | 33.857 | 0.43% |
| `generate_ms` (sample_rf) | 1465.910 | 18.73% |
| **`decode_ms` (codec)** | **6328.086** | **80.84%** |
| `total_ms` (session.wall) | 7828.142 | 100% |

**タスク 4.4 の結論: `codec_decode_ms / session.wall_ms` = 80.8%。**

これは D1 で警戒した状況の逆である。D1 では「RF サンプリングが支配的なら、デコードが 5 倍速くなっても E2E は数 % しか動かない」と想定していたが、実測では codec デコードが wall time のほぼ全てを占めていた。ConvTranspose1d の最適化は Irodori の主ボトルネックに直撃する。

段階の合計 7828.03 ms は wall 7828.14 ms とほぼ一致するため、計測されていない隠れた区間は無い。

期待値の上限と見込み:

| `decode_ms` の改善 | 予測 `total_ms` | E2E 倍率 |
|---|---:|---:|
| 理論上限 (decode → 0) | 1500 ms | 5.2x |
| 5.6x (upstream が VoxCPM2 で実測した倍率) | 2630 ms | 3.0x |
| 3x | 3610 ms | 2.2x |
| 2x | 4664 ms | 1.7x |

なお upstream が `irodori_tts` について報告した `-4.94%` は `cdd5196` 単独の増分である。`c810a06` はその 3 日前 (2026-07-29) に既にマージ済みで、当該の検証表のベースライン側に含まれている。我々のフォークにはどちらも入っていないため、両方の効果を同時に得る。

注記: この比率は入力テキスト長に依存する。`decode_ms` は生成音声長に、`generate_ms` は RF ステップ数に比例するため、長文では比率が変わりうる。before/after は同一テキストで比較するので判定には影響しない。

### 効果測定 (チェリーピック後, macOS / Metal)

同一マシン・同一モデル・同一テキスト・seed 1234・直列実行。中央値:

| 段階 | before (ms) | after (ms) | 変化 |
|---|---:|---:|---:|
| `tokenize_ms` | 0.172 | 0.170 | -1.4% |
| `encode_ms` | 33.857 | 34.938 | +3.2% |
| `generate_ms` (sample_rf) | 1465.910 | 1467.919 | **+0.14%** |
| **`decode_ms` (codec)** | **6328.086** | **1140.448** | **-81.98% (5.55x)** |
| `total_ms` | 7828.142 | 2645.455 | **-66.21% (2.96x)** |

**比較の妥当性**: 変更が届かない `generate_ms` が +0.14% で再現した。`tokenize_ms` と `encode_ms` も数 % 以内に収まっている。触っていない段階が誤差以下で一致したことは、2 回の測定でマシン状態が揃っており、動いたのが codec デコード段だけであることを示す。ベースラインと効果測定は別セッションで取得したが、この対照により比較は成立している。

**予測との一致**: ベースライン時に「decode が upstream の 5.6x で改善すれば total 2630 ms, 2.98x」と見積もった。実測は decode 5.55x, total 2645 ms, 2.96x で、total の予測誤差は 0.6% だった。`c810a06` の効果が Irodori の DACVAE デコードにも VoxCPM2 の AudioVAE と同程度に効いたことになる。

**ボトルネックの移動**: デコードが縮んだ結果、支配的な段階が入れ替わった。

```
before                              after
decode    80.8%  ████████████████   generate  55.5%  ███████████
generate  18.7%  ████               decode    43.1%  ████████
encode     0.4%                     encode     1.3%
```

### 測定の安定性

run ごとの `decode_ms`:

| | run 1 | run 2 | run 3 | 幅 |
|---|---:|---:|---:|---:|
| before | 6325.1 | 6328.1 | 6328.8 | 0.06% |
| after | 1138.4 | 1142.7 | 1140.4 | 0.38% |

2 つの分布は重ならない (最小 6325.1 に対し最大 1142.7)。中央値の選び方や外れ値の扱いで結論が変わる余地は無い。

### 次の最適化対象 (`engine_timings` より)

`sample_rf` の内訳 (run 2, 単位 ms):

| 内訳 | before | after |
|---|---:|---:|
| `context_cond_ms` | 0.000 | 0.000 |
| `context_cfg_ms` | 17.691 | 17.874 |
| `steps_cfg_ms` | 911.871 | 914.591 |
| `steps_cond_ms` | 523.602 | 523.636 |

チェリーピック後の総所要時間 2645 ms に対する内訳の順位:

| 順位 | 区間 | ms | 全体比 |
|---|---|---:|---:|
| 1 | `codec_decode` | 1140.4 | 43.1% |
| 2 | `sample_rf.steps_cfg` | 914.6 | 34.6% |
| 3 | `sample_rf.steps_cond` | 523.6 | 19.8% |
| 4 | `encode` (condition) | 34.9 | 1.3% |
| 5 | `sample_rf.context_cfg` | 17.9 | 0.7% |

**`steps_cfg` が `steps_cond` の 1.75 倍かかっている点は追う価値がある。** classifier-free guidance は条件付きと無条件の 2 経路を評価するため、両者が同程度になるのが素直な期待値である。この非対称が実装上の何かに由来するなら、単独で全体の 3 割を占める区間なので改善余地が大きい。ただし本 change の範囲外であり、別 change で調査する。

### 判定 (D2 の基準に照らして)

D2 の表の 1 行目「`decode_ms` が改善し、`total_ms` が baseline の +2% 以内」に該当する。`decode_ms` は 5.55 倍、`total_ms` は 2.96 倍の改善で、悪化した段階は無い。

**結論: チェリーピックを残す。**

D1 で定めた受け入れ基準「before/after が同一条件で測定でき、`decode_ms` の変化が記録されたこと」も満たしている。加えて、効果は測定ノイズに埋もれるどころか E2E で約 3 倍という規模だった。

### Windows (Vulkan) 無影響の検証

タスク 5.7 は「アプリが動く」ではなく出力の同一性で確認した。同一マシン・同一モデル・同一 seed (1234)・同一テキストで `audiocpp_cli --backend vulkan` を 2 回実行した。

| ビルド | submodule | 出力 WAV MD5 |
|---|---|---|
| チェリーピック前 | `eda8e83` (main) | `efd68c35169a171a622b30fbe5dc849c` |
| チェリーピック後 | `feat/metal-convtranspose` | `efd68c35169a171a622b30fbe5dc849c` |

330,284 バイトがバイト単位で一致した。理由は 2 つあり、どちらも設計どおりである。

- `conv_modules.cpp` のゲートに追加したのは `Metal` のみで、`Vulkan` は fast path に入らない。
- `cdd5196` が変更した `miocodec/graph_ops.cpp` は Irodori の経路に無い。Irodori は `src/models/irodori_tts/codec.cpp` の独自 codec を使い、MioCodec を参照しない。

## Open Questions

- `rtf` / `audio_duration_s` を出力 WAV ヘッダから導出するか (D5 で今回は見送り)。ベンチマークを継続的に使うなら後追いで足す価値がある。
- ~~ベースライン測定で `codec_decode_ms / session.wall_ms` の比率が小さかった場合、`sample_rf.*` の内訳のどれを次の最適化対象にするか。~~ 解決: ベースラインでは 80.8% で codec デコードが支配的だった。チェリーピック後は decode 43.1% / generate 55.5% と逆転した。内訳まで見ると **`sample_rf.steps_cfg` が単独で全体の 34.6%** を占め、`steps_cond` の 1.75 倍かかっている。次の調査対象はこの非対称である (上表を参照)。
- upstream フルマージ (残り 143 コミット、特に model spec v1 移行と `AUDIOCPP_MODEL_SET=custom` によるビルド絞り込み) を別 change としていつ着手するか。
