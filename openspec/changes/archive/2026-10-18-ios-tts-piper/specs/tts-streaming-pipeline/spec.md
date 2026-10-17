## ADDED Requirements

### Requirement: A model-load failure carries its reason to the notification
モデルの読み込みに失敗した場合も、その理由（ワーカー isolate が返したエラー文言）を、合成失敗と同じく失敗通知の原因文言として提示 SHALL する。`TtsSession` は直近のモデル読み込み失敗の理由を保持 SHALL し、`TtsStreamingController` は読み込み失敗で `failed` を返すとき、その理由を失敗理由として保持 SHALL する。理由が得られない場合（中断による読み込み終了など）は、従来どおり見出しのみを提示する。

ネイティブライブラリが無い、モデルファイルが壊れているといった読み込み失敗は、理由が無ければ「生成に失敗しました」としか伝わらず、原因を突き止められない。iOS では、Piper のライブラリを同梱し忘れたビルドで、この状況が起こりうる。

#### Scenario: A load failure shows the reason
- **WHEN** ワーカー isolate がモデル読み込みに失敗して "Piper native library piper_plus.framework is not in this build" を返し、`start()` が `failed` を返す
- **THEN** 失敗スナックバーに、ローカライズされた見出しとその文言の両方が表示される

#### Scenario: An aborted load shows no reason
- **WHEN** 停止操作による中断でモデル読み込みが終わる
- **THEN** `start()` は `failed` を返さず、失敗スナックバーは表示されない

#### Scenario: The load reason does not leak into a later run
- **WHEN** 読み込みに失敗した後、別の実行でモデル読み込みに成功し、合成が理由なしで失敗する
- **THEN** その失敗の通知に、以前の読み込み失敗の理由は表示されない
