## ADDED Requirements

### Requirement: MP3 export is offered only where the platform supports it
エクスポートボタンは、プラットフォームの機能モデルが音声書き出しを利用可能と報告する場合にのみ表示しなければならない（SHALL）。利用不可の場合（iOS）、ボタンは無効化ではなくウィジェットツリーから取り除かなければならず（SHALL）、LAME FFI ライブラリを読み込んではならない（SHALL NOT）。LAME には iOS 向けのビルドが無く、押すと必ず失敗するボタンになるためである。再生・一時停止・停止・編集・削除など、TTS コントロール行のほかのボタンは影響を受けない。

#### Scenario: Export button is absent on iOS
- **WHEN** TTS音声が生成済みかつ再生停止中で、音声書き出しが利用不可のプラットフォームで TTS コントロール行を表示する
- **THEN** エクスポートボタンは表示されず、削除ボタンなどほかのボタンは表示される

#### Scenario: Export button is present on desktop
- **WHEN** TTS音声が生成済みかつ再生停止中で、音声書き出しが利用可能なプラットフォームで TTS コントロール行を表示する
- **THEN** エクスポートボタンが従来どおり表示される

#### Scenario: The encoder is never loaded where export is unavailable
- **WHEN** 音声書き出しが利用不可のプラットフォームで、TTS の生成・再生・編集・削除を行う
- **THEN** LAME FFI ライブラリの読み込みは一度も試みられない
