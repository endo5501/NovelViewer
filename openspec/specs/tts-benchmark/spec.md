## Purpose

`scripts/benchmark_tts.sh` を介して TTS エンジンの CLI を反復実行し、ウォームアップ + 計測複数回の各フェーズタイミングを集計してJSON出力する。`--engine` で qwen3-tts-cli と audio.cpp の audiocpp_cli (Irodori-TTS) を選択でき、決定論的実行 (qwen3 は temperature=0、Irodori は固定 seed)、max-tokens / timeout の制御、Windows (Vulkan) と macOS (Metal) の両方をサポートする。

## Requirements

### Requirement: ベンチマークスクリプトがCLI経由でTTS推論を複数回実行し結果を集計する

`scripts/benchmark_tts.sh` は `--engine <qwen3|irodori>` で対象エンジンを選択できなければならない (MUST)。`--engine` 未指定時の既定値は `qwen3` とし、既存の呼び出し方法との後方互換を保たなければならない (MUST)。いずれのエンジンでも、TTS 推論をウォームアップ1回＋計測3回実行し、各フェーズのタイミングを集計しなければならない（MUST）。

`--engine qwen3` では従来どおり qwen3-tts-cli を使用しなければならない (MUST)。`--engine irodori` では `third_party/audio.cpp` の `audiocpp_cli` を `--task tts --family irodori_tts --model <model-dir> --backend <metal|vulkan>` で起動しなければならない (MUST)。

#### Scenario: デフォルト設定でベンチマーク実行
- **WHEN** `scripts/benchmark_tts.sh --model-dir <dir>` を実行する
- **THEN** `--engine qwen3` として扱われ、ウォームアップ1回＋計測3回が実行され、各回のタイミングと中央値がJSON形式で出力される

#### Scenario: Irodori エンジンを指定してベンチマーク実行
- **WHEN** `scripts/benchmark_tts.sh --engine irodori --model-dir <dir>` を実行する
- **THEN** `audiocpp_cli` が `--task tts --family irodori_tts` で起動され、ウォームアップ1回＋計測3回が実行される

#### Scenario: カスタムテキストでベンチマーク実行
- **WHEN** `scripts/benchmark_tts.sh --model-dir <dir> --text "カスタムテキスト"` を実行する
- **THEN** 指定されたテキストでベンチマークが実行される

#### Scenario: 言語指定でベンチマーク実行
- **WHEN** `scripts/benchmark_tts.sh --model-dir <dir> --language ja` を実行する
- **THEN** 指定された言語でベンチマークが実行される

#### Scenario: 未知のエンジン名を拒否する
- **WHEN** `scripts/benchmark_tts.sh --engine unknown --model-dir <dir>` を実行する
- **THEN** エラーメッセージを出力して非ゼロ終了し、推論を実行しない

### Requirement: ベンチマーク結果がJSON形式で保存される

ベンチマーク結果はタイムスタンプ、モデル情報、各回の実行結果、中央値を含むJSONファイルとして保存されなければならない（MUST）。結果JSONは測定対象エンジンを識別する `engine` フィールド (`"qwen3"` または `"irodori"`) を含まなければならない (MUST)。

#### Scenario: 結果ファイルの保存
- **WHEN** ベンチマークが正常に完了する
- **THEN** `benchmarks/` ディレクトリにタイムスタンプ付きのJSONファイルが保存される

#### Scenario: JSON出力のフォーマット
- **WHEN** 結果JSONを読み込む
- **THEN** `timestamp`, `engine`, `model`, `text`, `language`, `runs` (配列), `median` フィールドが含まれる

#### Scenario: エンジンの識別
- **WHEN** `--engine irodori` で実行した結果JSONを読み込む
- **THEN** `engine` フィールドの値が `"irodori"` である

### Requirement: ベンチマークは決定論的設定で実行される

再現性を確保するため、ベンチマークはエンジンごとに適切な決定論的設定で実行されなければならない（MUST）。

`--engine qwen3` では自己回帰サンプリングを greedy にするため `--temperature 0` を指定しなければならない (MUST)。`--engine irodori` では RF-DiT のサンプリング軌道を固定するため `--seed <固定値>` を指定しなければならない (MUST)。Irodori は seed 未指定時に実行ごとに異なる乱数 seed を用いるため、seed の明示は before/after 比較の前提条件である。

#### Scenario: qwen3 の決定論的生成
- **WHEN** `--engine qwen3` でベンチマークスクリプトがCLIを呼び出す
- **THEN** `--temperature 0` が指定される

#### Scenario: Irodori の決定論的生成
- **WHEN** `--engine irodori` でベンチマークスクリプトがCLIを呼び出す
- **THEN** `--seed <固定値>` が指定され、ウォームアップ・計測の全実行で同一の値が用いられる

### Requirement: ベンチマークスクリプトがmax-tokensとタイムアウトを制御できる

0.6Bモデルなどgreedy decodingでEOSを出しにくいモデルへの対応として、`--max-tokens`で生成トークン数を制限し、`--timeout`で1回あたりのタイムアウトを設定できなければならない（MUST）。

#### Scenario: max-tokens指定でベンチマーク実行
- **WHEN** `scripts/benchmark_tts.sh --model-dir <dir> --max-tokens 200` を実行する
- **THEN** CLIに `--max-tokens 200` が渡され、生成トークン数が制限される

#### Scenario: タイムアウト指定でベンチマーク実行
- **WHEN** `scripts/benchmark_tts.sh --model-dir <dir> --timeout 120` を実行する
- **THEN** 各CLI実行が120秒でタイムアウトし、エラーメッセージが出力される

### Requirement: ベンチマークスクリプトはWindowsとmacOSの両方で動作する

`scripts/benchmark_tts.sh` はWindowsのGit BashとmacOSのBashの両方で動作しなければならない（MUST）。OS固有の差異（CLIバイナリパス、GPUバックエンド名）は自動検出で対応する。CLIバイナリパスは選択されたエンジンごとに解決しなければならない (MUST)。

#### Scenario: Windowsでの実行 (qwen3)
- **WHEN** Windows環境（Git Bash）で `--engine qwen3` を実行する
- **THEN** `build/Release/qwen3-tts-cli.exe` が使用され、GPUバックエンドは "Vulkan" として記録される

#### Scenario: macOSでの実行 (qwen3)
- **WHEN** macOS環境で `--engine qwen3` を実行する
- **THEN** `build/qwen3-tts-cli` が使用され、GPUバックエンドは "Metal" として記録される

#### Scenario: Windowsでの実行 (irodori)
- **WHEN** Windows環境（Git Bash）で `--engine irodori` を実行する
- **THEN** `third_party/audio.cpp` の Vulkan ビルド出力にある `audiocpp_cli.exe` が使用され、CLI には `--backend vulkan` が渡され、GPUバックエンドは "Vulkan" として記録される

#### Scenario: macOSでの実行 (irodori)
- **WHEN** macOS環境で `--engine irodori` を実行する
- **THEN** `third_party/audio.cpp` の Metal ビルド出力にある `audiocpp_cli` が使用され、CLI には `--backend metal` が渡され、GPUバックエンドは "Metal" として記録される

#### Scenario: CLI バイナリが存在しない場合
- **WHEN** 選択したエンジンのCLIバイナリが見つからない
- **THEN** 該当するビルドスクリプト名を示すエラーメッセージを出力して非ゼロ終了する

### Requirement: Irodori の計時ログを既存 JSON スキーマにマップする

`--engine irodori` では `audiocpp_cli` に `--log-file <path>` を渡して計時ログを専用ファイルへ出力させ、そこから `[TIMING ts=<秒>] <名前> <値>` 形式の行を抽出して既存の JSON スキーマにマップしなければならない (MUST)。マッピングは以下でなければならない (MUST)。

| JSON フィールド | 計時ログ名 |
|---|---|
| `tokenize_ms` | `irodori_tts.tokenize_ms` |
| `encode_ms` | `irodori_tts.condition_ms` |
| `generate_ms` | `irodori_tts.sample_rf_ms` |
| `decode_ms` | `irodori_tts.codec_decode_ms` |
| `total_ms` | `session.wall_ms` |

さらに各 run の結果に `engine_timings` オブジェクトを含め、`irodori_tts.prepare_reference_ms` および `irodori_tts.sample_rf.context_cond_ms` / `context_cfg_ms` / `steps_cfg_ms` / `steps_cond_ms` の値を保持しなければならない (MUST)。Irodori は音声長を計時ログに出力しないため、`rtf` と `audio_duration_s` は `null` としなければならない (MUST)。

#### Scenario: 計時ログから正規フィールドを抽出する
- **WHEN** `irodori_tts.codec_decode_ms 123.4` を含む計時ログをパースする
- **THEN** その run の `decode_ms` が `123.4` になる

#### Scenario: 内訳を engine_timings に保持する
- **WHEN** `irodori_tts.sample_rf.steps_cond_ms` を含む計時ログをパースする
- **THEN** その run の `engine_timings.sample_rf.steps_cond_ms` に値が入る

#### Scenario: 音声長が測定できないことを明示する
- **WHEN** `--engine irodori` の結果JSONを読み込む
- **THEN** 各 run の `rtf` と `audio_duration_s` が `null` である

#### Scenario: 計時ログに期待する行がない場合
- **WHEN** `session.wall_ms` を含まない計時ログをパースする
- **THEN** 欠落した計時名を挙げたエラーメッセージを出力して非ゼロ終了し、欠損値を 0 として集計しない

### Requirement: 計時ログのパースが TRACE 行・CRLF・追記に耐える

パーサは `[TIMING ...]` タグで始まる行のみを対象としなければならない (MUST)。`audio.cpp` は `[TRACE ts=<stamp>] <名前> <値>` を同一の行構造で出力するため、タグを見ずに名前だけで一致させてはならない (MUST NOT)。名前の比較は完全一致でなければならない (MUST)。`irodori_tts.sample_rf_ms` は `irodori_tts.sample_rf.context_cond_ms` の接頭辞であり、`irodori_tts.condition_ms` は `*_cond_ms` と部分文字列を共有するためである。

パーサは値に付随する復帰文字 (CR) を除去しなければならない (MUST)。`audio.cpp` はログを `std::ofstream(path, std::ios::app)` すなわちテキストモードで開くため、Windows では CRLF で書き出される。

同一の計時名が複数回現れる場合、パーサは最後の値を採用しなければならない (MUST)。同じ `std::ios::app` により、ログパスを再利用すると複数 run 分が蓄積するためである。

#### Scenario: TRACE 行を TIMING と取り違えない
- **WHEN** `[TIMING ...] irodori_tts.codec_decode_ms` と同名の `[TRACE ...]` 行を両方含むログをパースする
- **THEN** `decode_ms` は TIMING 行の値になる

#### Scenario: CRLF のログをパースする
- **WHEN** CRLF 改行の計時ログをパースする
- **THEN** 抽出された値に復帰文字が含まれない

#### Scenario: 追記された複数 run のログをパースする
- **WHEN** 2 回分の計時が追記されたログをパースする
- **THEN** 後の run の値が採用される

### Requirement: Irodori のモデルスペック解決を明示する

`--engine irodori` では `audiocpp_cli` に `--model-spec-override <third_party/audio.cpp>/model_specs` を渡し、カレントディレクトリに依存しないスペック解決を行わなければならない (MUST)。

#### Scenario: 任意のディレクトリから実行する
- **WHEN** リポジトリルート以外のカレントディレクトリから `--engine irodori` でベンチマークを実行する
- **THEN** モデルスペックが解決され、推論が実行される

### Requirement: 計時ログのパーサが単体でテスト可能である

計時ログのパースはフィクスチャファイルを入力として検証できなければならない (MUST)。`scripts/test/` 配下にパーサのテストを配置し、実際の GPU 実行やモデルを必要とせずに検証できなければならない (MUST)。

#### Scenario: フィクスチャログでパーサを検証する
- **WHEN** `audiocpp_cli --log-file` の出力を模したフィクスチャを与えてパーサテストを実行する
- **THEN** GPU やモデルファイルなしでテストが完走し、マッピング結果が期待値と一致する

#### Scenario: OS を問わず検証できる
- **WHEN** Windows の Git Bash でパーサテストを実行する
- **THEN** macOS と同じ結果でテストが通る
