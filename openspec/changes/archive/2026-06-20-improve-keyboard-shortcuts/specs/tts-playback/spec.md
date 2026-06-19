## ADDED Requirements

### Requirement: Keyboard toggle control for playback
システムは、キーボードショートカット（既定Ctrl+T）による単一のトグル操作でTTSの再生を制御しなければならない（SHALL）。ショートカットはフォーカスを持たないTTSコントロールへ届くよう、要求プロバイダ（command bus、既存の停止要求プロバイダと同一パターン）を介して伝達されなければならない（SHALL）。TTSコントロールはトグル要求を受け取ったとき、現在の `(TtsAudioState × TtsPlaybackState)` に応じて次のように解決しなければならない（SHALL）: 停止中（再生していない）→ 生成/再生を開始、再生中（playing/waiting）→ 一時停止、一時停止中（paused）→ 再開。

#### Scenario: トグルで再生を開始する
- **WHEN** 再生していない状態でTTSトグルショートカット（既定Ctrl+T）が押される
- **THEN** 選択中のファイルに対してTTSの生成/再生が開始される

#### Scenario: トグルで一時停止する
- **WHEN** 再生中（playing）の状態でTTSトグルショートカットが押される
- **THEN** 再生が一時停止される

#### Scenario: トグルで再開する
- **WHEN** 一時停止中（paused）の状態でTTSトグルショートカットが押される
- **THEN** 再生が再開される

#### Scenario: トグル要求はcommand bus経由で伝達される
- **WHEN** フォーカスがTTSコントロール以外（ビューアやファイルブラウザ）にある状態でTTSトグルショートカットが押される
- **THEN** トグル要求が要求プロバイダを通じてTTSコントロールへ伝達され、再生状態が切り替わる

#### Scenario: モデル未設定時は何もしない
- **WHEN** TTSモデルが未設定（コントロールが非表示）の状態でTTSトグルショートカットが押される
- **THEN** 再生は開始されず、エラーも発生しない

#### Scenario: トグルに停止は含まれない
- **WHEN** TTSトグルショートカット（Ctrl+T）が押される
- **THEN** 解決される動作は開始/一時停止/再開のいずれかであり、停止（stop）は含まれない（停止はEscapeに集約される）

### Requirement: Stop playback via Escape key
システムは、Escapeキーによる文脈依存のキャンセル操作の一部としてTTS再生を停止できなければならない（SHALL）。Escapeの意味はフォーカス文脈によって分岐し、明示的な優先順位ロジックを持ってはならない（SHALL NOT）。検索入力フィールドにフォーカスがある場合、Escapeは検索のクローズに使われTTSは停止しない（SHALL NOT）。検索入力フィールド以外（テキストビューア等）にフォーカスがある場合で、かつTTSが再生中（playing/waiting）または一時停止中（paused）であれば、EscapeはTTS再生を停止しなければならない（SHALL）。停止対象のTTS状態が無ければ、Escapeは何も行ってはならない（SHALL NOT）。Escapeは固定のキャンセルキーであり、カスタマイズ対象の論理アクションに含めてはならない（SHALL NOT）。

#### Scenario: Escapeで再生を停止する
- **WHEN** フォーカスがテキストビューアにあり、TTSが再生中の状態でEscapeを押す
- **THEN** TTS再生が停止する

#### Scenario: Escapeで一時停止中の再生を停止する
- **WHEN** フォーカスがテキストビューアにあり、TTSが一時停止中の状態でEscapeを押す
- **THEN** TTS再生が停止する

#### Scenario: 検索入力中のEscapeはTTSを停止しない
- **WHEN** 検索入力フィールドにフォーカスがある状態（かつTTSが再生中）でEscapeを押す
- **THEN** 検索が閉じられ、TTSは停止しない

#### Scenario: 対象状態が無いときは何もしない
- **WHEN** フォーカスがテキストビューアにあり、TTSが再生していない状態でEscapeを押す
- **THEN** 何も起きない
