## ADDED Requirements

### Requirement: Synthesis failure reports the underlying cause

読み上げ編集画面でセグメントの合成が失敗した際、システムは固定文言のみを表示 SHALL NOT。`TtsEditController` は `TtsSession` が保持する直近の失敗理由を取得し、ローカライズされた見出し（例: 「合成に失敗しました」）と併せてユーザーに提示 SHALL する。

失敗理由が取得できない場合、システムはローカライズされた見出しのみを表示 SHALL する。見出しの文言は多言語リソース (`app_ja.arb`, `app_en.arb`, `app_zh.arb`) にキーを持ち、すべてのロケールで空でない翻訳を持つ SHALL。

原因文言はネイティブ層が生成する英語の技術的メッセージであり、翻訳の対象と SHALL NOT。見出しと連結して表示する。

#### Scenario: Failure with a native cause shows the cause
- **WHEN** セグメントの合成が失敗し、セッションが保持する失敗理由が "unsupported WAV encoding (need PCM16, PCM24, or float32)" である
- **THEN** スナックバーにローカライズされた見出しと "unsupported WAV encoding (need PCM16, PCM24, or float32)" の両方を含むメッセージが表示される

#### Scenario: Failure without a cause shows the headline only
- **WHEN** セグメントの合成が失敗し、セッションが保持する失敗理由が `null` である
- **THEN** スナックバーにローカライズされた見出しのみが表示される

#### Scenario: Reference audio failure is diagnosable
- **WHEN** 読み込めない参照音声を指定したセグメントの生成を実行する
- **THEN** 表示されるメッセージから、失敗が参照音声の読み込みに起因することが判別できる

#### Scenario: Localization parity for the headline
- **WHEN** 合成失敗の見出しキーを解決する
- **THEN** `app_ja.arb`, `app_en.arb`, `app_zh.arb` のすべてに空でない翻訳が存在する
