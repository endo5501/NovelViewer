## Purpose

Irodori エンジンが生成する音声の長さ (target seconds) を補正するルールを定める。noref 条件での duration 再予測、字数則による上限、既存の min/max クランプの維持、およびそれらを制御するリクエストオプションの契約を規定し、生成尺の与えすぎによってクリップ末尾へテキストに存在しない発話が付加される現象を防ぐ。

## Requirements

### Requirement: 生成尺の補正ルール
Irodori エンジンは、生成する音声の長さ (target seconds) を決定する際、duration predictor の出力をそのまま使わず、以下の 3 値の最小値を採らなければならない (SHALL)。

```
target_seconds = min( 通常の duration 予測 ,
                      noref 条件での duration 予測 ,
                      字数(記号除) × text_rate + text_margin )
```

- **通常の duration 予測**: 参照音声・caption を与えた現行どおりの予測値
- **noref 条件での duration 予測**: 参照音声も caption も無いものとして再予測した値
- **字数則**: 入力テキストから句読点・括弧類を除いた符号点数に `text_rate` を掛け、`text_margin` を足した値

この補正は、生成尺が本文を読み終える時刻より大きく余ったときにモデルがその余りを埋めるように発話し、テキストに存在しない発話がクリップ末尾へ付加される現象を防ぐためのものである。

補正後の値には、既存の `min_duration_sec` / `max_duration_sec` によるクランプを従来どおり適用しなければならない (SHALL)。

`duration_sec` が明示指定されている場合、補正を適用してはならない (MUST NOT)。明示指定は predictor 迂回の手段であり、呼び出し側の意図を上書きしてはならない。

#### Scenario: 中程度の長さのテキストでは noref 予測が採用される
- **WHEN** 参照音声と caption を与え、通常予測が noref 予測より大きく、字数則が noref 予測より大きいテキストを合成する
- **THEN** noref 予測が target seconds として採用される

#### Scenario: 短文では字数則が採用される
- **WHEN** noref 予測が字数則の値を上回る短いテキストを合成する
- **THEN** 字数則の値が target seconds として採用される

#### Scenario: 長文では字数則が採用される
- **WHEN** noref 予測が字数則の値を上回る長いテキストを合成する
- **THEN** 字数則の値が target seconds として採用される

#### Scenario: 補正は尺を伸ばさない
- **WHEN** noref 予測および字数則の値が、いずれも通常予測を上回る
- **THEN** 通常予測が採用され、補正によって尺が伸びることはない

#### Scenario: duration_sec 明示指定時は補正されない
- **WHEN** リクエストで `duration_sec` を明示指定して合成する
- **THEN** 指定値がそのまま使われ、noref 予測も字数則も参照されない

#### Scenario: min/max クランプは維持される
- **WHEN** 補正後の値が `min_duration_sec` を下回る
- **THEN** `min_duration_sec` にクランプされる

### Requirement: noref 条件での再予測
noref 条件での duration 予測は、condition graph の話者フラグと caption フラグを無効値にして同じグラフをもう一度実行することで取得しなければならない (SHALL)。グラフの再構築やモデルの再ロードを行ってはならない (MUST NOT)。

再予測はテキストのチャンクごとに行わなければならない (SHALL)。エンジンは渡されたテキストを内部で分割するため、チャンクをまたいで単一の尺を使い回してはならない (MUST NOT)。

参照音声も caption も与えられていない合成では、通常予測と noref 予測が一致するため、再予測を省略してよい (MAY)。

#### Scenario: 再予測でモデルは再ロードされない
- **WHEN** 参照音声と caption を与えた合成を実行する
- **THEN** condition graph は 2 回実行されるが、モデルロードは発生しない

#### Scenario: 複数チャンクではチャンクごとに補正される
- **WHEN** エンジン内部で複数チャンクに分割される長いテキストを合成する
- **THEN** 各チャンクが自身のテキストに基づく target seconds で生成される

### Requirement: 補正パラメータのリクエストオプション化
補正の挙動はリクエストオプションで制御できなければならない (SHALL)。少なくとも以下を提供する。

- 補正の有効・無効を切り替えるオプション
- 字数則の係数 (`text_rate`) と余白 (`text_margin`)

既定値は現行の挙動を変えないもの (補正無効) としなければならない (MUST)。これにより、既存の呼び出し側および他のフロントエンド (CLI / WebUI) の出力は変化しない。

不正な値 (負の係数など) を渡された場合、エンジンはエラーを返すか既定値にフォールバックしなければならない (SHALL)。無言で異常な尺を生成してはならない (MUST NOT)。

#### Scenario: 既定では補正されない
- **WHEN** 補正オプションを指定せずに合成する
- **THEN** 従来どおり通常予測がそのまま使われる

#### Scenario: オプションで補正を有効化できる
- **WHEN** 補正を有効にするオプションを指定して合成する
- **THEN** 補正ルールが適用された target seconds で生成される

#### Scenario: 係数を再ビルドなしで変更できる
- **WHEN** `text_rate` に既定と異なる値を指定して合成する
- **THEN** その値で字数則が計算される

### Requirement: 補正の追加コストの計測
noref 再予測にかかる時間は、既存の condition encoder の計測値と区別して観測できなければならない (SHALL)。補正を有効にした合成と無効にした合成で、追加コストを比較できる状態を保たなければならない (SHALL)。

#### Scenario: 追加コストが観測できる
- **WHEN** 補正を有効にして合成し、デバッグ計測を確認する
- **THEN** condition graph の実行にかかった時間が記録されており、補正無効時との差分が分かる
