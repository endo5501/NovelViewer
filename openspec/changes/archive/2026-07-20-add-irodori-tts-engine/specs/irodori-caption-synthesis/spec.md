# irodori-caption-synthesis

## ADDED Requirements

### Requirement: セグメントメモを caption として合成に使用
Irodori エンジンが選択されているとき、合成パイプライン (ストリーミング生成・編集ダイアログの再生成・保存済みセグメントの再合成) は対象セグメントの `TtsEditSegment.memo` を caption としてエンジンに渡さなければならない (SHALL)。メモが null または空文字のセグメントは caption なし (参照音声のみのクローン合成) で合成しなければならない (SHALL)。Qwen3 / Piper エンジン選択時はメモを caption として使用してはならず (MUST NOT)、メモ欄の入力・保存仕様 (自由記述テキスト、DB 保存) は変更してはならない (MUST NOT)。

#### Scenario: メモ記入済みセグメントの再生成
- **WHEN** Irodori 選択中、メモに「怒って叫んでいる」と記入したセグメントを編集ダイアログで再生成する
- **THEN** 合成リクエストの caption に「怒って叫んでいる」が渡り、参照音声とともに両立合成される

#### Scenario: メモなしセグメントの合成
- **WHEN** Irodori 選択中、メモが空のセグメントを合成する
- **THEN** caption なし (クローンのみ) で合成される

#### Scenario: qwen3 選択時はメモを caption にしない
- **WHEN** Qwen3 エンジン選択中にメモ記入済みセグメントを再生成する
- **THEN** メモは合成に影響せず、従来どおりのクローン合成が行われる

### Requirement: 合成時パラメータとしての caption 伝搬
`TtsIsolate` の合成リクエストは省略可能な `caption` (String?) を受け付けなければならない (SHALL)。caption は合成時パラメータであり、変更してもモデル再ロードを引き起こしてはならない (MUST NOT)。`IrodoriEngineConfig` の `modelLoadKey` は caption / refWavPath / guidance / steps を含んではならない (MUST NOT)。

#### Scenario: caption 変更でモデルは再ロードされない
- **WHEN** 同一モデルロード中に caption だけ異なる2つの合成を連続実行する
- **THEN** モデルロードは1回のままで、2回の合成が行われる

### Requirement: guidance / steps パラメータの永続化と適用
システムは Irodori 用の合成調整パラメータとして `speaker_guidance_scale` (既定 5.0)、`caption_guidance_scale` (既定 3.0)、`num_inference_steps` (既定 40) を SharedPreferences に永続化し、Riverpod プロバイダで公開しなければならない (SHALL)。これらは合成リクエストごとにエンジンへ渡されなければならない (SHALL)。

#### Scenario: 既定値
- **WHEN** 初回起動後に Irodori パラメータのプロバイダを読む
- **THEN** speaker=5.0 / caption=3.0 / steps=40 が返る

#### Scenario: 変更の永続化と適用
- **WHEN** ユーザが caption_guidance_scale を 4.5 に変更し、次の合成を実行する
- **THEN** 値が永続化され、合成リクエストに 4.5 が渡る
