## Purpose

Irodori エンジンが使用するモデル variant (`v3` = 600M VoiceDesign / `v4` = v4 Small) をユーザが選択・永続化できるようにする。variant はモデルロードを伴う設定であり、`IrodoriEngineConfig` の `modelLoadKey` に含める。あわせて variant ごとの機能差 (v4 は caption 非対応) を単一の判定箇所に集約し、設定 UI でその制約と理由を提示する。

## Requirements

### Requirement: Irodori モデル variant の選択と永続化
システムは Irodori エンジンのモデル variant として `v3` (600M VoiceDesign) と `v4` (v4 Small) を提供し、ユーザが選択できるようにしなければならない (SHALL)。選択値は SharedPreferences に永続化し、Riverpod プロバイダで公開しなければならない (SHALL)。既定値は `v3` でなければならない (MUST)。variant は `TtsEngineType` の値としてではなく `IrodoriEngineConfig` のフィールドとして保持しなければならない (MUST)。

variant はモデルロードを伴うため、`IrodoriEngineConfig` の `modelLoadKey` に含めなければならない (MUST)。

#### Scenario: 既定値
- **WHEN** 初回起動後に Irodori variant のプロバイダを読む
- **THEN** `v3` が返る

#### Scenario: 選択の永続化
- **WHEN** ユーザが variant を `v4` に変更してアプリを再起動する
- **THEN** `v4` が選択された状態で復元される

#### Scenario: variant 変更はモデル再ロードを引き起こす
- **WHEN** 合成中でない状態で variant を `v3` から `v4` へ変更し、次の合成を実行する
- **THEN** `modelLoadKey` が変化しているためモデルが再ロードされ、v4 の GGUF が読み込まれる

### Requirement: v4 における caption 非対応の決定
システムは variant ごとに caption 対応可否を決定しなければならない (SHALL)。`v3` は caption に対応し、`v4` は caption に対応しないものとして扱わなければならない (MUST)。

この判定は単一の箇所に集約し、合成の呼び出し側ごとに条件を書いてはならない (MUST NOT)。

`v4` が caption 非対応である理由は、参照音声と caption を同時に与えたときにクリップ末尾へテキストに存在しない発話が付加されるためである。参照音声のみ、あるいは caption のみでは発生しない交互作用であり、本アプリの主経路である「参照音声 × caption」が該当する。

#### Scenario: v3 は caption 対応
- **WHEN** variant が `v3` のときに caption 対応可否を問い合わせる
- **THEN** 対応ありと判定される

#### Scenario: v4 は caption 非対応
- **WHEN** variant が `v4` のときに caption 対応可否を問い合わせる
- **THEN** 対応なしと判定される

### Requirement: variant 選択 UI と制約の提示
Irodori 設定セクションは variant の選択 UI を提供しなければならない (SHALL)。`v4` が選択されているとき、caption に関わる UI (caption guidance scale の調整、セグメントメモが caption として使われる旨の表示) を無効化し、**v4 では caption に対応しない旨の理由を表示**しなければならない (SHALL)。

セグメントメモの入力・保存仕様そのものは variant によって変更してはならない (MUST NOT)。メモはメモとして引き続き記入・保存できる。

文言は ja / en / zh の全ロケールに提供しなければならない (SHALL)。

#### Scenario: v4 選択時に caption 系 UI が無効化される
- **WHEN** ユーザが variant を `v4` に切り替える
- **THEN** caption guidance scale の調整 UI が無効化され、v4 では caption が合成に反映されない旨が表示される

#### Scenario: v3 に戻すと caption 系 UI が復帰する
- **WHEN** ユーザが variant を `v4` から `v3` に戻す
- **THEN** caption guidance scale の調整 UI が再び有効になる

#### Scenario: v4 選択中もメモは記入・保存できる
- **WHEN** variant が `v4` の状態でセグメントのメモを編集して保存する
- **THEN** メモは通常どおり保存され、合成には影響しない
