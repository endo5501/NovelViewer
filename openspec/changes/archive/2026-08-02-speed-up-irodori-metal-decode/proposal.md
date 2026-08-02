## Why

audio.cpp フォーク (endo5501/audio.cpp) は merge-base `a0f3b4c` (2026-07-18) 以降、upstream (0xShug0/audio.cpp) が 145 コミット先行している。調査の結果、NovelViewer の Irodori-TTS に効く変更は **macOS Metal の ConvTranspose 最適化 2 件** に絞り込めた。Irodori の codec (`third_party/audio.cpp/src/models/irodori_tts/codec.cpp:232`) が `ConvTranspose1dModule` を使うため、両者とも波形デコード段に直撃する。

しかし取り込みを判断する前提が欠けている。**Irodori の性能を測る手段が存在しない**。`scripts/benchmark_tts.sh` は qwen3-tts.cpp 専用、`scripts/test/verify_irodori_macos.sh` は dylib の静的検証のみ、`benchmarks/*.json` は全て 2026-03 の qwen3 のものである。よって本 change の実質的な主タスクは測定路の整備であり、チェリーピックはその上で効果を確認する行為となる。

## What Changes

### A. 測定路の整備 (Windows で実装・テスト可能)

- `scripts/benchmark_tts.sh` に `--engine qwen3|irodori` を追加する。既定は `qwen3` とし、既存の qwen3 経路の挙動・CLI 引数・出力 JSON スキーマは一切変更しない。
- `--engine irodori` では audio.cpp の `audiocpp_cli` を `--log-file` 付きで実行し、Irodori が既に出力している `[TIMING ts=...] <name> <value>` 形式の計時ログを既存 JSON スキーマ (`tokenize_ms` / `encode_ms` / `generate_ms` / `decode_ms` / `total_ms`) にマップする。
- `scripts/build_irodori_macos.sh` / `scripts/build_irodori_windows.bat` が `audiocpp_ffi` に加えて `audiocpp_cli` も建てる。
- `scripts/test/verify_irodori_macos.sh` に `audiocpp_cli` の存在チェックを追加する。

### B. ベースライン測定 (macOS 必須)

チェリーピック**前**の状態で測定し、`benchmarks/` に結果 JSON を残す。

### C. upstream 変更のチェリーピック

- submodule `third_party/audio.cpp` に `feat/metal-convtranspose` ブランチを作成し、以下 2 件を cherry-pick して endo5501/audio.cpp へ push する。
  - `c810a06` "metal: dispatch conv_transpose_1d with 256-thread threadgroups (#149)" — 3 ファイル clean apply。
  - `cdd5196` "Enable Metal ConvTranspose fast path with MioCodec layout-safe multiplies" — `conv_modules.cpp` の 3 行ゲート条件に軽微な競合あり。
- NovelViewer 側の submodule pointer を更新する。
- upstream の `306673c` (検証レポート doc) は取り込まない。

### D. 効果測定と記録 (macOS 必須)

チェリーピック**後**を同一条件で測定し、`benchmarks/` に結果 JSON を残して `design.md` に結論を記録する。

**A → B → C → D の順序は必須である。** C を先に実施するとベースラインが取得できなくなる。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `tts-benchmark`: ベンチマークスクリプトが単一エンジン (qwen3) 固定だった要求を、エンジン選択可能 (`qwen3` / `irodori`) に変更する。Irodori 経路の CLI 起動方法と計時ログのパース、および既存 JSON スキーマへのマッピングを新たに規定する。
- `irodori-tts-native-engine`: ビルドスクリプトが `audiocpp_ffi` のみを建てる要求を、測定用に `audiocpp_cli` も併せて建てるよう拡張する (Windows / macOS 両方)。
- `irodori-macos-build`: 成果物配置の要求に、測定用 `audiocpp_cli` を `macos/Frameworks/` へ置いてはならない制約 (codesign の封印対象のため) と、`verify_irodori_macos.sh` による検証を追加する。

## Impact

### 変更されるファイル

| ファイル | 内容 | 実装環境 |
|---|---|---|
| `scripts/benchmark_tts.sh` | エンジン選択と Irodori 計時ログのパース | Windows |
| `scripts/test/benchmark_parse_test.sh` (新規) | 計時ログパーサのフィクスチャテスト | Windows |
| `scripts/test/fixtures/` (新規) | `audiocpp_cli --log` のサンプルログ | Windows |
| `scripts/build_irodori_macos.sh` | `audiocpp_cli` ターゲット追加 | macOS |
| `scripts/build_irodori_windows.bat` | `audiocpp_cli` ターゲット追加 | Windows |
| `scripts/test/verify_irodori_macos.sh` | `audiocpp_cli` 存在チェック | macOS |
| `third_party/audio.cpp` (submodule pointer) | cherry-pick 後のコミットを指す | Windows |
| `benchmarks/*.json` | before / after の測定結果 | macOS |

### 影響を受けないもの

- Flutter 側のコード (`lib/`) は一切変更しない。Dart FFI の呼び出し面 (`audiocpp_c_api.h`) も不変である。
- `audiocpp_ffi` の既存ビルド成果物とアプリの動作は、C の submodule 更新まで変化しない。
- Windows (Vulkan) の実行時挙動は C の後も変化しない。`c810a06` が触る `ggml-metal-*.{h,cpp,metal}` は Vulkan ビルドでコンパイルされず、`cdd5196` のゲート条件追加は `Metal` のみを対象とするため `Vulkan` は経路に入らない。

### 環境分業

- **Windows で完結**: A の実装とテスト、C のチェリーピックと push。
- **macOS 必須**: A のうち `build_irodori_macos.sh` / `verify_irodori_macos.sh` の実行確認、および B と D の測定。

### リスク

- `.metal` シェーダのコンパイル検証は macOS でしか行えない。upstream で検証済みかつ clean apply のため低リスクだが、ゼロではない。
- 効果が測定ノイズに埋もれる可能性がある。このため主指標を E2E ではなく `decode_ms` とし、「効果が出ない = 失敗」とはしない (詳細は design.md)。
