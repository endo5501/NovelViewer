> **環境の凡例**: 🪟 = Windows で実施可 / 🍎 = **macOS 必須** / 🌐 = OS 非依存
>
> **順序の制約**: セクション 1〜3 (測定路) → 4 (ベースライン測定) → 5 (チェリーピック) → 6 (効果測定)。
> **5 を 4 より先に実施してはならない。** ベースラインが取得できなくなる。

## 1. 計時ログパーサ (TDD ループ 1) 🌐

- [ ] 1.1 🌐 `scripts/test/fixtures/irodori_timing_sample.log` を作成する。`[TIMING ts=<秒>] <名前> <値>` 形式で `irodori_tts.prepare_reference_ms` / `tokenize_ms` / `condition_ms` / `sample_rf_ms` / `sample_rf.context_cond_ms` / `sample_rf.context_cfg_ms` / `sample_rf.steps_cfg_ms` / `sample_rf.steps_cond_ms` / `codec_decode_ms` / `session.wall_ms` の全行と、無関係な非 TIMING 行を含める
- [ ] 1.2 🌐 `scripts/test/fixtures/irodori_timing_missing_wall.log` を作成する。`session.wall_ms` を欠いた異常系フィクスチャ
- [ ] 1.3 🌐 **[テストファースト]** `scripts/test/benchmark_parse_test.sh` を作成する。`verify_irodori_macos.sh` と同じ ok/ng カウンタ形式で、1.1 のフィクスチャから `tokenize_ms` / `encode_ms` / `generate_ms` / `decode_ms` / `total_ms` と `engine_timings` の各値が期待どおり抽出されること、および 1.2 のフィクスチャで非ゼロ終了することを検証する
- [ ] 1.4 🌐 テストを実行し、パーサ未実装のため失敗することを確認する
- [ ] 1.5 🌐 失敗するテストをコミットする
- [ ] 1.6 🌐 `scripts/benchmark_tts.sh` に `parse_timing_irodori()` を実装する。マッピングは design.md D4 の表に従う。`session.wall_ms` 欠落時はエラー終了し、欠損値を 0 として集計しない
- [ ] 1.7 🌐 `scripts/test/benchmark_parse_test.sh` が全て通ることを確認する

## 2. ベンチマークスクリプトのエンジン選択 🪟

- [ ] 2.1 🪟 `scripts/benchmark_tts.sh` に `--engine <qwen3|irodori>` を追加する。既定は `qwen3`、未知の値はエラー終了
- [ ] 2.2 🪟 CLI バイナリ解決をエンジン別に分岐する。`irodori` では `third_party/audio.cpp` のビルド出力から `audiocpp_cli` (Windows: `.exe`) を解決し、見つからない場合は該当ビルドスクリプト名を示してエラー終了する
- [ ] 2.3 🪟 `run_once()` をエンジン別に分岐する。`irodori` では `--task tts --family irodori_tts --model <dir> --backend <metal|vulkan> --text <text> --language <lang> --seed <固定値> --log-file <path> --model-spec-override <audio.cpp>/model_specs` で起動し、計時ログのファイルパスを返す
- [ ] 2.4 🪟 `parse_timing()` をエンジン別にディスパッチし、`irodori` では 1.6 の `parse_timing_irodori()` を呼ぶ
- [ ] 2.5 🪟 結果 JSON に `engine` フィールドを追加する。`irodori` の各 run には `engine_timings` を含め、`rtf` と `audio_duration_s` は `null` を出力する
- [ ] 2.6 🪟 既存の qwen3 経路が無変更で動作することを確認する (CLI 引数・出力 JSON スキーマが従来と一致すること)
- [ ] 2.7 🪟 `scripts/test/benchmark_parse_test.sh` が引き続き通ることを確認する

## 3. ビルドスクリプトへの測定用 CLI 追加

- [ ] 3.1 🪟 `scripts/build_irodori_windows.bat` のビルドターゲットに `audiocpp_cli` を追加する。`audiocpp_ffi` と同一の configure を使い、CLI は配布先 (`build/windows/x64/runner/Release/`) にコピーしない
- [ ] 3.2 🪟 Windows で `scripts/build_irodori_windows.bat` を実行し、`audiocpp_ffi.dll` と `audiocpp_cli.exe` の両方が生成されることを確認する
- [ ] 3.3 🍎 **[テストファースト]** `scripts/test/verify_irodori_macos.sh` に検証項目を追加する。(a) `third_party/audio.cpp/build/ffi-metal/` 配下に `audiocpp_cli` が存在する、(b) `macos/Frameworks/audiocpp_cli` が存在しない
- [ ] 3.4 🍎 検証スクリプトを実行し、(a) が失敗することを確認する
- [ ] 3.5 🍎 `scripts/build_irodori_macos.sh` のビルドターゲットに `audiocpp_cli` を追加する。`macos/Frameworks/` へはコピーしない
- [ ] 3.6 🍎 `scripts/build_irodori_macos.sh` を実行し、`scripts/test/verify_irodori_macos.sh` が全項目通ることを確認する

## 4. ベースライン測定 (チェリーピック前) 🍎

- [ ] 4.1 🍎 測定条件を記録する。マシン、OS バージョン、モデルディレクトリ、テキスト、seed、`third_party/audio.cpp` の commit hash
- [ ] 4.2 🍎 他アプリを停止し、`scripts/benchmark_tts.sh --engine irodori --model-dir <dir>` を**直列で**実行する (並列実行は禁止)
- [ ] 4.3 🍎 結果 JSON が `benchmarks/` に保存されたことを確認し、ファイル名を design.md に記録する
- [ ] 4.4 🍎 `codec_decode_ms / session.wall_ms` の比率を算出し、design.md の Open Questions に記録する。この比率が Metal 最適化の効果の上限を決める
- [ ] 4.5 🍎 ベースライン結果をコミットする

## 5. upstream Metal 最適化のチェリーピック 🪟

- [ ] 5.1 🪟 submodule `third_party/audio.cpp` で `git fetch upstream` を実行し、`upstream/main` が取得できていることを確認する
- [ ] 5.2 🪟 submodule に `feat/metal-convtranspose` ブランチを `main` から作成する
- [ ] 5.3 🪟 `c810a06` (`metal: dispatch conv_transpose_1d with 256-thread threadgroups (#149)`) を cherry-pick する。`external/ggml/src/ggml-metal/` の 3 ファイルが clean に当たることを確認する
- [ ] 5.4 🪟 `cdd5196` (`Enable Metal ConvTranspose fast path with MioCodec layout-safe multiplies`) を cherry-pick する。`src/framework/modules/conv_modules.cpp` の競合は `is_conv_transpose1d_col2im_fast_path_eligible()` のゲートに `BackendType::Metal` を追加する形で解決する。`src/models/miocodec/graph_ops.cpp` の変更も併せて入っていることを確認する (ゲートだけ入って本体が入らない半端な状態を作らない)
- [ ] 5.5 🪟 upstream の `306673c` (検証レポート doc) を取り込んでいないことを確認する
- [ ] 5.6 🪟 Windows で `scripts/build_irodori_windows.bat` を実行し、Vulkan ビルドが壊れていないことを確認する (`conv_modules.cpp` と `miocodec/graph_ops.cpp` は Vulkan ビルドでもコンパイルされる)
- [ ] 5.7 🪟 Windows でアプリの Irodori 合成が従来どおり動作することを確認する。ゲート条件に追加したのは `Metal` のみで `Vulkan` は経路に入らないため、挙動は不変であるべき
- [ ] 5.8 🪟 `feat/metal-convtranspose` を endo5501/audio.cpp へ push する。**NovelViewer 側の pointer 更新より先に push すること** (順序を誤ると macOS 側の `git submodule update` が失敗する)
- [ ] 5.9 🪟 NovelViewer 側で submodule pointer を更新してコミットし、`feat/speed-up-irodori-metal-decode` を push する

## 6. 効果測定と判断 🍎

- [ ] 6.1 🍎 macOS で `git pull` と `git submodule update --init --recursive` を実行し、submodule が 5.8 のコミットを指していることを確認する
- [ ] 6.2 🍎 `scripts/build_irodori_macos.sh` を実行する。`.metal` シェーダのコンパイルが通ることを確認する (失敗した場合は macOS 側で修正し submodule ブランチに追加コミットする)
- [ ] 6.3 🍎 `scripts/test/verify_irodori_macos.sh` が全項目通ることを確認する
- [ ] 6.4 🍎 4.1 と**同一条件** (同一マシン・同一モデル・同一テキスト・同一 seed・他アプリ停止・直列) でベンチマークを実行する。4 と 6 の間でベンチスクリプト自体を変更していないことを確認する
- [ ] 6.5 🍎 before / after の `decode_ms` (主指標) と `total_ms` の中央値を比較し、`engine_timings` の内訳も含めて design.md に結果を追記する
- [ ] 6.6 🍎 design.md の D2 の判断基準に照らして、チェリーピックを残すか revert するかを決定し、判断とその根拠を design.md に記録する
- [ ] 6.7 🍎 revert する場合は submodule pointer を戻し、理由を design.md に残す。残す場合は測定結果をコミットする

## 7. 最終確認

- [ ] 7.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 7.3 `fvm flutter analyze`でリントを実行
- [ ] 7.4 `fvm flutter test`でテストを実行
- [ ] 7.5 `scripts/test/benchmark_parse_test.sh` を実行して通ることを確認
- [ ] 7.6 🍎 `scripts/test/verify_irodori_macos.sh` を実行して通ることを確認
