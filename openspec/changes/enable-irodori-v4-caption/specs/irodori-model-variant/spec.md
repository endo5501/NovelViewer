## MODIFIED Requirements

### Requirement: v4 における caption 非対応の決定
システムは variant ごとに caption 対応可否を決定しなければならない (SHALL)。`v3` と `v4` はいずれも caption に対応するものとして扱わなければならない (MUST)。

この判定は単一の箇所に集約し、合成の呼び出し側ごとに条件を書いてはならない (MUST NOT)。将来 caption 非対応の variant が追加された場合も、この 1 箇所の変更で対応できなければならない (SHALL)。

`v4` はかつて caption 非対応として扱われていた。参照音声と caption を同時に与えるとクリップ末尾へテキストに存在しない発話が付加されたためである。この現象は生成尺の与えすぎが原因であることが判明し、`irodori-duration-correction` の尺補正によって回避できるようになったため、制限は撤回された。**v4 で caption を有効にする場合、尺補正が有効でなければならない (MUST)。** 補正なしで caption を渡してはならない (MUST NOT)。

#### Scenario: v3 は caption 対応
- **WHEN** variant が `v3` のときに caption 対応可否を問い合わせる
- **THEN** 対応ありと判定される

#### Scenario: v4 も caption 対応
- **WHEN** variant が `v4` のときに caption 対応可否を問い合わせる
- **THEN** 対応ありと判定される

#### Scenario: v4 の caption 合成では尺補正が有効になる
- **WHEN** variant が `v4` の状態で caption 付きの合成を実行する
- **THEN** 合成リクエストに尺補正を有効化するオプションが含まれる

### Requirement: variant 選択 UI と制約の提示
Irodori 設定セクションは variant の選択 UI を提供しなければならない (SHALL)。caption に関わる UI (caption guidance scale の調整、セグメントメモが caption として使われる旨の表示) は、選択中の variant が caption に対応しているとき有効でなければならない (SHALL)。caption 非対応の variant が選択されているときのみ、これらを無効化し理由を表示しなければならない (SHALL)。

セグメントメモの入力・保存仕様そのものは variant によって変更してはならない (MUST NOT)。メモはメモとして引き続き記入・保存できる。

文言は ja / en / zh の全ロケールに提供しなければならない (SHALL)。

#### Scenario: v4 選択時も caption 系 UI が有効
- **WHEN** ユーザが variant を `v4` に切り替える
- **THEN** caption guidance scale の調整 UI は有効なままで、caption 非対応を告げる文言は表示されない

#### Scenario: v3 選択時も caption 系 UI が有効
- **WHEN** ユーザが variant を `v3` に切り替える
- **THEN** caption guidance scale の調整 UI は有効である

#### Scenario: メモは引き続き記入・保存できる
- **WHEN** 任意の variant でセグメントのメモを編集して保存する
- **THEN** メモは通常どおり保存される


## ADDED Requirements

### Requirement: variant ごとの尺補正の要否
システムは variant ごとに `irodori-duration-correction` の尺補正を必要とするかを決定しなければならない (SHALL)。`v4` は必要とし、`v3` は必要としないものとして扱わなければならない (MUST)。

判定は variant のテーブルに集約し、合成の呼び出し側ごとに条件を書いてはならない (MUST NOT)。補正はモデルごとの性質なので、合成リクエストごとではなく**モデルロード時**にエンジンへ与えなければならない (SHALL)。

`v3` を除外する理由は、**補正の係数が v4 の実測から当てはめたものである**ことによる。v3 では末尾アーティファクトが観測されておらず、かつ caption 付きの出力は本文終端が字数則の上限まで約 0.12 秒しか余裕がない。他所で校正した上限を当てると、現に正しい出力を切る恐れがある。

#### Scenario: v4 は補正を必要とする
- **WHEN** variant が `v4` のモデルをロードする
- **THEN** エンジンへ尺補正を有効化する指定が渡る

#### Scenario: v3 は補正を必要としない
- **WHEN** variant が `v3` のモデルをロードする
- **THEN** エンジンへ尺補正を有効化する指定は渡らない
