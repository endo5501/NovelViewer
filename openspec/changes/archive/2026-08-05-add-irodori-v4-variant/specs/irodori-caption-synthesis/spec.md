## MODIFIED Requirements

### Requirement: セグメントメモを caption として合成に使用
Irodori エンジンが選択され、**かつ選択中の variant が caption に対応しているとき**、合成パイプライン (ストリーミング生成・編集ダイアログの再生成・保存済みセグメントの再合成) は対象セグメントの `TtsEditSegment.memo` を caption としてエンジンに渡さなければならない (SHALL)。メモが null または空文字のセグメントは caption なし (参照音声のみのクローン合成) で合成しなければならない (SHALL)。

**caption 非対応の variant (v4) が選択されているときは、メモの内容にかかわらず caption を渡してはならない (MUST NOT)。** この判定は `TtsEngineConfig.captionFromMemo()` に集約し、合成の呼び出し側ごとに条件を書いてはならない (MUST NOT)。UI 層より下で閉じることで、UI 側の実装漏れがあっても caption が v4 に渡らないことを保証する。

Qwen3 / Piper エンジン選択時はメモを caption として使用してはならず (MUST NOT)、メモ欄の入力・保存仕様 (自由記述テキスト、DB 保存) は変更してはならない (MUST NOT)。

#### Scenario: メモ記入済みセグメントの再生成
- **WHEN** Irodori v3 選択中、メモに「怒って叫んでいる」と記入したセグメントを編集ダイアログで再生成する
- **THEN** 合成リクエストの caption に「怒って叫んでいる」が渡り、参照音声とともに両立合成される

#### Scenario: メモなしセグメントの合成
- **WHEN** Irodori v3 選択中、メモが空のセグメントを合成する
- **THEN** caption なし (クローンのみ) で合成される

#### Scenario: v4 選択時はメモを caption にしない
- **WHEN** Irodori v4 選択中にメモ記入済みセグメントを再生成する
- **THEN** caption は渡されず、参照音声のみのクローン合成が行われる

#### Scenario: v4 でのゲートは UI を経由しない経路にも効く
- **WHEN** Irodori v4 選択中に、ストリーミング生成・編集ダイアログの再生成・保存済みセグメントの再合成のいずれの経路からでも合成する
- **THEN** いずれの経路でも caption は渡されない

#### Scenario: qwen3 選択時はメモを caption にしない
- **WHEN** Qwen3 エンジン選択中にメモ記入済みセグメントを再生成する
- **THEN** メモは合成に影響せず、従来どおりのクローン合成が行われる

### Requirement: guidance / steps パラメータの永続化と適用
システムは Irodori 用の合成調整パラメータとして `speaker_guidance_scale` (既定 5.0)、`caption_guidance_scale` (既定 3.0)、`num_inference_steps` (既定 40) を SharedPreferences に永続化し、Riverpod プロバイダで公開しなければならない (SHALL)。これらは合成リクエストごとにエンジンへ渡されなければならない (SHALL)。

**caption 非対応の variant (v4) が選択されているとき、`caption_guidance_scale` は合成結果に影響しない。** 永続化された値は保持しなければならない (SHALL) が、UI 上は無効化しなければならない (SHALL)。variant を v3 に戻したときは以前の値が復元されなければならない (SHALL)。

#### Scenario: 既定値
- **WHEN** 初回起動後に Irodori パラメータのプロバイダを読む
- **THEN** speaker=5.0 / caption=3.0 / steps=40 が返る

#### Scenario: 変更の永続化と適用
- **WHEN** ユーザが caption_guidance_scale を 4.5 に変更し、次の合成を実行する
- **THEN** 値が永続化され、合成リクエストに 4.5 が渡る

#### Scenario: v4 に切り替えても caption_guidance_scale の設定値は失われない
- **WHEN** caption_guidance_scale を 4.5 に設定した状態で variant を v4 に切り替え、その後 v3 に戻す
- **THEN** 4.5 が復元される
