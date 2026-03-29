## ADDED Requirements

### Requirement: ベンチマークスクリプトがCLI経由でTTS推論を複数回実行し結果を集計する

`scripts/benchmark_tts.sh` はqwen3-tts-cliを使用してTTS推論をウォームアップ1回＋計測3回実行し、各フェーズのタイミングを集計しなければならない（MUST）。

#### Scenario: デフォルト設定でベンチマーク実行
- **WHEN** `scripts/benchmark_tts.sh --model-dir <dir>` を実行する
- **THEN** ウォームアップ1回＋計測3回が実行され、各回のタイミングと中央値がJSON形式で出力される

#### Scenario: カスタムテキストでベンチマーク実行
- **WHEN** `scripts/benchmark_tts.sh --model-dir <dir> --text "カスタムテキスト"` を実行する
- **THEN** 指定されたテキストでベンチマークが実行される

#### Scenario: 言語指定でベンチマーク実行
- **WHEN** `scripts/benchmark_tts.sh --model-dir <dir> --language ja` を実行する
- **THEN** 指定された言語でベンチマークが実行される

### Requirement: ベンチマーク結果がJSON形式で保存される

ベンチマーク結果はタイムスタンプ、モデル情報、各回の実行結果、中央値を含むJSONファイルとして保存されなければならない（MUST）。

#### Scenario: 結果ファイルの保存
- **WHEN** ベンチマークが正常に完了する
- **THEN** `benchmarks/` ディレクトリにタイムスタンプ付きのJSONファイルが保存される

#### Scenario: JSON出力のフォーマット
- **WHEN** 結果JSONを読み込む
- **THEN** `timestamp`, `model`, `text`, `language`, `runs` (配列), `median` フィールドが含まれる

### Requirement: ベンチマークは決定論的設定で実行される

再現性を確保するため、ベンチマークはtemperature=0（greedy）で実行されなければならない（MUST）。

#### Scenario: 決定論的生成
- **WHEN** ベンチマークスクリプトがCLIを呼び出す
- **THEN** `--temperature 0` が指定される

### Requirement: ベンチマークスクリプトがmax-tokensとタイムアウトを制御できる

0.6Bモデルなどgreedy decodingでEOSを出しにくいモデルへの対応として、`--max-tokens`で生成トークン数を制限し、`--timeout`で1回あたりのタイムアウトを設定できなければならない（MUST）。

#### Scenario: max-tokens指定でベンチマーク実行
- **WHEN** `scripts/benchmark_tts.sh --model-dir <dir> --max-tokens 200` を実行する
- **THEN** CLIに `--max-tokens 200` が渡され、生成トークン数が制限される

#### Scenario: タイムアウト指定でベンチマーク実行
- **WHEN** `scripts/benchmark_tts.sh --model-dir <dir> --timeout 120` を実行する
- **THEN** 各CLI実行が120秒でタイムアウトし、エラーメッセージが出力される

### Requirement: ベンチマークスクリプトはWindowsとmacOSの両方で動作する

`scripts/benchmark_tts.sh` はWindowsのGit BashとmacOSのBashの両方で動作しなければならない（MUST）。OS固有の差異（CLIバイナリパス、GPUバックエンド名）は自動検出で対応する。

#### Scenario: Windowsでの実行
- **WHEN** Windows環境（Git Bash）でスクリプトを実行する
- **THEN** `build/Release/qwen3-tts-cli.exe` が使用され、GPUバックエンドは "Vulkan" として記録される

#### Scenario: macOSでの実行
- **WHEN** macOS環境でスクリプトを実行する
- **THEN** `build/qwen3-tts-cli` が使用され、GPUバックエンドは "Metal" として記録される
