## MODIFIED Requirements

### Requirement: Synthesis failure reports the underlying cause

読み上げ編集画面でセグメントの合成が失敗した際、システムは固定文言のみを表示 SHALL NOT。`TtsEditController` は `TtsSession` が保持する直近の失敗理由を取得し、ローカライズされた見出し（例: 「合成に失敗しました」）と併せてユーザーに提示 SHALL する。

失敗理由が取得できない場合、システムはローカライズされた見出しのみを表示 SHALL する。見出しの文言は多言語リソース (`app_ja.arb`, `app_en.arb`, `app_zh.arb`) にキーを持ち、すべてのロケールで空でない翻訳を持つ SHALL。

原因文言はネイティブ層が生成する英語の技術的メッセージであり、翻訳の対象と SHALL NOT。見出しと連結して表示する。

通知は共通の失敗通知経路を通して表示 SHALL する。すなわち、ユーザーが閉じるまで残り、詳細アクションを備える。呼び出し元は見出しを headline、原因文言を cause とする `FailureReport` を構築 SHALL する。合成失敗は例外として送出されないため、スタックトレースは省略 SHALL する。

診断情報には、失敗時刻、アプリケーションバージョン、TTSエンジン種別、モデル名、対象ファイル名、失敗したセグメントの索引を含める SHALL。

#### Scenario: Failure with a native cause shows the cause
- **WHEN** セグメントの合成が失敗し、セッションが保持する失敗理由が "unsupported WAV encoding (need PCM16, PCM24, or float32)" である
- **THEN** スナックバーにローカライズされた見出しと "unsupported WAV encoding (need PCM16, PCM24, or float32)" の両方を含むメッセージが表示される

#### Scenario: Failure without a cause shows the headline only
- **WHEN** セグメントの合成が失敗し、セッションが保持する失敗理由が `null` である
- **THEN** スナックバーにローカライズされた見出しのみが表示される

#### Scenario: User cancel is not reported as a failure
- **WHEN** セグメント生成中にユーザーがキャンセルを実行し、進行中の合成が中断される
- **THEN** 失敗の通知は表示されない（意図的な中断は失敗ではない）

#### Scenario: Reference audio failure is diagnosable
- **WHEN** 読み込めない参照音声を指定したセグメントの生成を実行する
- **THEN** 表示されるメッセージから、失敗が参照音声の読み込みに起因することが判別できる

#### Scenario: Localization parity for the headline
- **WHEN** 合成失敗の見出しキーを解決する
- **THEN** `app_ja.arb`, `app_en.arb`, `app_zh.arb` のすべてに空でない翻訳が存在する

#### Scenario: The failure notification persists and offers details
- **WHEN** セグメントの合成が失敗して失敗スナックバーが表示される
- **THEN** スナックバーは既定の表示時間が経過しても表示されたままであり、詳細アクションを備える

#### Scenario: The report carries the segment diagnostics
- **WHEN** 索引 7 のセグメントの合成が失敗し、詳細ダイアログを開いてコピーする
- **THEN** コピーされたテキストに失敗時刻、アプリケーションバージョン、TTSエンジン種別、モデル名、対象ファイル名、およびセグメント索引 7 が含まれる
