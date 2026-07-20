# irodori-tts-model-download

## ADDED Requirements

### Requirement: Irodori モデル資産の一括ダウンロード
システムは `IrodoriModelDownloadService` を提供し、endo5501 の Hugging Face リポジトリから以下の4資産を単一の操作でダウンロードしなければならない (SHALL):
- `Irodori-TTS-600M-v3-VoiceDesign/` (model.safetensors, model_config.json ほか必須ファイル)
- `llm-jp-3-150m/tokenizer.json`
- `Semantic-DACVAE-Japanese-32dim/weights.safetensors` (pth から変換済みの safetensors)

保存レイアウトは audio.cpp の `model_specs/irodori_tts.json` (safetensors ソース定義) が要求する相対配置 (600M ディレクトリの兄弟に llm-jp-3-150m / Semantic-DACVAE-Japanese-32dim) に一致しなければならない (MUST)。

#### Scenario: 一括ダウンロードの完了
- **WHEN** ユーザが Irodori 設定セクションでモデルダウンロードを開始し、完走する
- **THEN** モデルルート配下に 600M / llm-jp-3-150m / Semantic-DACVAE の3ディレクトリと必須ファイルすべてが存在する

#### Scenario: 相対配置が spec と一致する
- **WHEN** ダウンロード完了後にモデルルートを検査する
- **THEN** `Irodori-TTS-600M-v3-VoiceDesign/../llm-jp-3-150m/tokenizer.json` と `../Semantic-DACVAE-Japanese-32dim/weights.safetensors` が解決できる

### Requirement: ダウンロード進捗と状態表示
ダウンロード中はファイル単位の進捗 (受信バイト/総バイト) を UI に通知しなければならない (SHALL)。全必須ファイルが存在する場合は「ダウンロード済み」状態を表示し、再ダウンロードを要求してはならない (MUST NOT)。ダウンロードは既存 TTS モデルダウンロードと同様にキャンセル可能でなければならない (SHALL)。

#### Scenario: 進捗の表示
- **WHEN** 4.7GB 超の資産をダウンロード中
- **THEN** 進捗インジケータが受信状況を反映して更新される

#### Scenario: ダウンロード済み判定
- **WHEN** 必須ファイルがすべて揃った状態で設定画面を開く
- **THEN** 「ダウンロード済み」と表示され、ダウンロードボタンは再実行を促さない

#### Scenario: キャンセル
- **WHEN** ダウンロード中にユーザがキャンセルする
- **THEN** 転送が停止し、部分ファイルにより「ダウンロード済み」と誤判定されない

### Requirement: ダウンロード失敗時の再試行
ネットワークエラー等でダウンロードが失敗した場合、エラー状態を表示し再試行操作を提供しなければならない (SHALL)。再試行時に取得済みの完全なファイルを再ダウンロードしてはならない (SHOULD NOT に相当する動作として、ファイル存在+サイズ一致で skip しなければならない (SHALL))。

#### Scenario: 途中失敗からの再開
- **WHEN** 3ファイル目のダウンロード中に失敗し、ユーザが再試行する
- **THEN** 完了済みファイルはスキップされ、未完了ファイルのみ再取得される
