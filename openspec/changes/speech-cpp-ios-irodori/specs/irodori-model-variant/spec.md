## MODIFIED Requirements

### Requirement: Irodori モデル variant の選択と永続化
システムは Irodori エンジンのモデル variant として次の 3 つを提供しなければならない (SHALL)。

| variant | 内容 | 実行系 |
|---|---|---|
| `v3` | 600M VoiceDesign | audio.cpp |
| `v4` | v4 Small | audio.cpp |
| `v4.1-mf` | v4.1 Small MF、F16 | speech.cpp |

各 variant は実行系を 1 つ持つ。選択肢に出すのは、実行中のプラットフォームの Irodori 実行系（`platform-capabilities`）と同じ実行系の variant だけでなければならない (MUST)。

選択値は SharedPreferences に永続化し、Riverpod プロバイダで公開しなければならない (SHALL)。variant は `TtsEngineType` の値としてではなく、`IrodoriEngineConfig` のフィールドとして保持しなければならない (MUST)。

使う variant は次のように決める。
- 保存値が無いとき、または保存値をプラットフォームが動かせないときは、選択肢の最初の variant を使わなければならない (MUST)。
- 選択肢の最初の variant は、デスクトップでは `v3`、iOS では `v4.1-mf` である。
- 保存値を動かせないことを理由に、保存値を書き換えてはならない (MUST NOT)。デスクトップのバックアップから設定を戻した読者が、デスクトップで元の選択を保てるようにするためである。

variant はモデルロードを伴うため、`IrodoriEngineConfig` の `modelLoadKey` に含めなければならない (MUST)。

#### Scenario: 既定値
- **WHEN** デスクトップで、保存値が無い状態で Irodori variant のプロバイダを読む
- **THEN** `v3` が返る

#### Scenario: iOS の既定値
- **WHEN** iOS で、保存値が無い状態で Irodori variant のプロバイダを読む
- **THEN** `v4.1-mf` が返る

#### Scenario: iOS で動かせない保存値は書き換えずに解決する
- **WHEN** iOS で、保存値が `v3` の状態で Irodori variant のプロバイダを読む
- **THEN** `v4.1-mf` が返り、保存値は `v3` のまま残る

#### Scenario: 選択肢はプラットフォームの実行系に従う
- **WHEN** variant の選択肢を、iOS とデスクトップでそれぞれ求める
- **THEN** iOS では `v4.1-mf` だけ、デスクトップでは `v3` と `v4` が返る

#### Scenario: 選択の永続化
- **WHEN** デスクトップでユーザが variant を `v4` に変更してアプリを再起動する
- **THEN** `v4` が選択された状態で復元される

#### Scenario: variant 変更はモデル再ロードを引き起こす
- **WHEN** 合成中でない状態で variant を `v3` から `v4` へ変更し、次の合成を実行する
- **THEN** `modelLoadKey` が変化しているためモデルが再ロードされ、v4 の GGUF が読み込まれる

### Requirement: variant ごとの caption 対応可否
システムは variant ごとに caption 対応可否を決定しなければならない (SHALL)。`v3`、`v4`、`v4.1-mf` はいずれも caption に対応するものとして扱わなければならない (MUST)。`v4.1-mf` では、caption を speech.cpp の `instructions` として渡す（`irodori-speech-cpp-engine`）。

この判定は単一の箇所に集約し、合成の呼び出し側ごとに条件を書いてはならない (MUST)。将来 caption 非対応の variant が追加された場合も、この 1 箇所の変更で対応できなければならない (SHALL)。

`v4` はかつて caption 非対応として扱われていた。参照音声と caption を同時に与えると、クリップの末尾にテキストに無い発話が付いたためである。原因は生成する尺を長く与えすぎていたことだと分かり、`irodori-duration-correction` の尺補正で避けられるようになったので、この制限は取り下げた。**v4 で caption を有効にする場合、尺補正が有効でなければならない (MUST)。** 補正なしで caption を渡してはならない (MUST NOT)。

#### Scenario: v3 は caption 対応
- **WHEN** variant が `v3` のときに caption 対応可否を問い合わせる
- **THEN** 対応ありと判定される

#### Scenario: v4 も caption 対応
- **WHEN** variant が `v4` のときに caption 対応可否を問い合わせる
- **THEN** 対応ありと判定される

#### Scenario: v4.1-mf も caption 対応
- **WHEN** variant が `v4.1-mf` のときに caption 対応可否を問い合わせる
- **THEN** 対応ありと判定される

#### Scenario: v4 の caption 合成では尺補正が有効になる
- **WHEN** variant が `v4` の状態で caption 付きの合成を実行する
- **THEN** 合成リクエストに尺補正を有効化するオプションが含まれる

### Requirement: variant 選択 UI と制約の提示
Irodori 設定セクションは variant の選択 UI を提供しなければならない (SHALL)。選択肢が 1 つしかないプラットフォーム（iOS）では、選択 UI の代わりに使う variant の名前を表示しなければならない (SHALL)。

caption に関わる UI は、選択中の variant が caption に対応しているとき有効でなければならない (SHALL)。caption に関わる UI とは、caption guidance scale の調整と、セグメントメモが caption として使われる旨の表示である。caption 非対応の variant が選択されているときだけ、これらを無効にし、理由を表示しなければならない (SHALL)。

各 variant は、ガイダンスの設定を受け付けるかどうかを持つ。ガイダンスの設定とは、speaker と caption の guidance scale、および推論の step 数である。`v3` と `v4` は受け付け、`v4.1-mf` は受け付けない。MF は guidance を学習に織り込んでおり、speech.cpp はこれらのオプションを拒否するためである。受け付けない variant が選択されているときは、ガイダンスの設定の UI を表示してはならない (MUST NOT)。保存されている値は変えない。

セグメントメモの入力・保存仕様そのものは variant によって変更してはならない (MUST NOT)。メモはメモとして引き続き記入・保存できる。

文言は ja / en / zh の全ロケールに提供しなければならない (SHALL)。

#### Scenario: v4 選択時も caption 系 UI が有効
- **WHEN** ユーザが variant を `v4` に切り替える
- **THEN** caption guidance scale の調整 UI は有効なままで、caption 非対応を告げる文言は表示されない

#### Scenario: v3 選択時も caption 系 UI が有効
- **WHEN** ユーザが variant を `v3` に切り替える
- **THEN** caption guidance scale の調整 UI は有効である

#### Scenario: MF ではガイダンスの設定を表示しない
- **WHEN** variant が `v4.1-mf` の状態で Irodori 設定セクションを開く
- **THEN** speaker / caption の guidance scale と step 数の UI は表示されず、caption 非対応を告げる文言も表示されない

#### Scenario: 選択肢が 1 つのときは名前を表示する
- **WHEN** iOS で Irodori 設定セクションを開く
- **THEN** variant を選ぶドロップダウンは表示されず、`v4.1-mf` の名前が表示される

#### Scenario: メモは引き続き記入・保存できる
- **WHEN** 任意の variant でセグメントのメモを編集して保存する
- **THEN** メモは通常どおり保存される

### Requirement: variant ごとの尺補正の要否
システムは variant ごとに、`irodori-duration-correction` の尺補正を必要とするかを決めなければならない (SHALL)。`v4` は必要とし、`v3` と `v4.1-mf` は必要としないものとして扱わなければならない (MUST)。

判定は variant のテーブルに集約し、合成の呼び出し側ごとに条件を書いてはならない (MUST NOT)。補正はモデルごとの性質なので、合成リクエストごとではなく**モデルロード時**にエンジンへ与えなければならない (SHALL)。

`v3` を除く理由は、**補正の係数を v4 の実測から当てはめた**ことにある。v3 では末尾の余計な発話が見られていない。しかも caption 付きの出力では、本文の終わりが字数則の上限まで約 0.12 秒しか余裕がない。他の variant で合わせた上限を当てると、今は正しい出力を切ってしまうおそれがある。

`v4.1-mf` を除く理由は、speech.cpp が話し終わりの無音で音声を終え、予測した尺を使い切らないことにある。そもそも補正の対象となる余りが生じない。

#### Scenario: v4 は補正を必要とする
- **WHEN** variant が `v4` のモデルをロードする
- **THEN** エンジンへ尺補正を有効化する指定が渡る

#### Scenario: v3 は補正を必要としない
- **WHEN** variant が `v3` のモデルをロードする
- **THEN** エンジンへ尺補正を有効化する指定は渡らない

#### Scenario: v4.1-mf は補正を必要としない
- **WHEN** variant が `v4.1-mf` のモデルをロードする
- **THEN** エンジンへ尺補正を有効化する指定は渡らない
