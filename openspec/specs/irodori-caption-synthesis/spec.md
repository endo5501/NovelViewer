## Purpose

Irodori エンジン選択時に、セグメントのメモ (`TtsEditSegment.memo`) を VoiceDesign caption として合成パイプラインに伝搬させる。caption はモデル再ロードを伴わない合成時パラメータとして扱い、guidance / steps の調整パラメータを SharedPreferences に永続化して各合成リクエストへ適用する。

## Requirements

### Requirement: セグメントメモを caption として合成に使用
Irodori エンジンが選択され、**かつ選択中の variant が caption に対応しているとき**、合成パイプライン (ストリーミング生成・編集ダイアログの再生成・保存済みセグメントの再合成) は対象セグメントの `TtsEditSegment.memo` を caption としてエンジンに渡さなければならない (SHALL)。メモが null または空文字のセグメントは caption なし (参照音声のみのクローン合成) で合成しなければならない (SHALL)。

caption 対応可否の判定は `TtsEngineConfig.captionFromMemo()` に集約し、合成の呼び出し側ごとに条件を書いてはならない (MUST NOT)。UI 層より下で閉じることで、UI 側の実装漏れがあっても不適切な variant へ caption が渡らないことを保証する。**v3 / v4 のいずれも caption 対応であるため、現時点でこのゲートが caption を落とすのは非対応エンジン (Qwen3 / Piper) の場合のみである。** ゲート自体は将来の非対応 variant のために残さなければならない (SHALL)。

Qwen3 / Piper エンジン選択時はメモを caption として使用してはならず (MUST NOT)、メモ欄の入力・保存仕様 (自由記述テキスト、DB 保存) は変更してはならない (MUST NOT)。

#### Scenario: メモ記入済みセグメントの再生成
- **WHEN** Irodori v3 選択中、メモに「怒って叫んでいる」と記入したセグメントを編集ダイアログで再生成する
- **THEN** 合成リクエストの caption に「怒って叫んでいる」が渡り、参照音声とともに両立合成される

#### Scenario: メモなしセグメントの合成
- **WHEN** Irodori v3 選択中、メモが空のセグメントを合成する
- **THEN** caption なし (クローンのみ) で合成される

#### Scenario: v4 選択時もメモが caption として渡る
- **WHEN** Irodori v4 選択中にメモ記入済みセグメントを再生成する
- **THEN** caption が渡り、参照音声とともに両立合成される

#### Scenario: v4 のどの経路でも caption が渡る
- **WHEN** Irodori v4 選択中に、ストリーミング生成・編集ダイアログの再生成・保存済みセグメントの再合成のいずれの経路からでも合成する
- **THEN** いずれの経路でも同じく caption が渡り、尺補正も同じく適用される

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

`caption_guidance_scale` は、選択中の variant が caption に対応しているとき合成結果に影響する。caption 非対応の variant が選択されているときは合成結果に影響せず、永続化された値は保持しなければならない (SHALL) が、UI 上は無効化しなければならない (SHALL)。

#### Scenario: 既定値
- **WHEN** 初回起動後に Irodori パラメータのプロバイダを読む
- **THEN** speaker=5.0 / caption=3.0 / steps=40 が返る

#### Scenario: 変更の永続化と適用
- **WHEN** ユーザが caption_guidance_scale を 4.5 に変更し、次の合成を実行する
- **THEN** 値が永続化され、合成リクエストに 4.5 が渡る

#### Scenario: v4 でも caption_guidance_scale が合成に効く
- **WHEN** variant が v4 の状態で caption_guidance_scale を 4.5 に設定して合成する
- **THEN** 合成リクエストに 4.5 が渡り、合成結果に反映される

### Requirement: caption 併用時の尺補正の適用
**尺補正を必要とする variant** で caption を渡す合成リクエストは、`irodori-duration-correction` の尺補正を有効化するオプションを併せて渡さなければならない (SHALL)。**その variant で caption を渡しながら補正を渡さない組み合わせが存在してはならない (MUST NOT)** — それが実測で 8〜9/10 の確率で壊れる組み合わせだからである。

補正を必要とするかは variant ごとに決まる (`irodori-model-variant`)。**補正の係数は v4 の実測 3 点から当てはめたものであり、アーティファクトが観測されていない variant に当ててはならない (MUST NOT)** — v3 は caption 付きでも本文終端が字数則の上限まで約 0.12 秒しか余裕がなく、他所で校正した上限を当てると現に正しい出力を切る恐れがある。

この対応づけは `irodori-tts-native-engine` の「尺補正は caption から導出する」に従い、caption が C API へ渡る唯一の地点で行う。補正は合成時パラメータであり、`IrodoriEngineConfig` の `modelLoadKey` に含めてはならない (MUST NOT)。

#### Scenario: caption 付き合成では補正が有効になる
- **WHEN** 補正を必要とする variant でメモ記入済みセグメントを合成する
- **THEN** 合成リクエストに尺補正を有効化するオプションが含まれる

#### Scenario: 補正を必要としない variant では caption があっても尺が変わらない
- **WHEN** 補正を必要としない variant (v3) でメモ記入済みセグメントを合成する
- **THEN** caption は渡るが補正オプションは付かず、生成される長さは従来と変わらない

#### Scenario: caption なし合成では尺が変わらない
- **WHEN** メモが空のセグメントを Irodori で合成する
- **THEN** 補正オプションは付かず、生成される長さは従来と変わらない

#### Scenario: 補正の有無でモデルは再ロードされない
- **WHEN** 同一モデルロード中に caption ありと caption なしの合成を連続実行する
- **THEN** モデルロードは 1 回のままで、2 回の合成が行われる
