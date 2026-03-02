## Why

リファレンス音声を使ったボイスクローニングを行う際、現在はユーザーが外部ツールで録音したファイルを手動でインポートする必要がある。自分や友人の声をクローンしたい場合、「別アプリで録音 → ファイルを探す → ドラッグ&ドロップまたはコピー」という手順が煩雑で、アプリ内で直接マイク録音できれば大幅にワークフローが改善される。

## What Changes

- リファレンス音声の設定画面（SettingsDialog の「読み上げ」タブ）に録音ボタンを追加
- 録音ボタンを押すとマイクからの音声録音を開始し、停止ボタンで録音を終了
- 録音完了後、ファイル名を入力するダイアログを表示し、`voices/` フォルダに WAV ファイルとして保存
- 保存後、リファレンス音声のドロップダウンリストに自動的に反映
- macOS および Windows のデスクトップ環境で動作

## Capabilities

### New Capabilities

- `voice-recording`: マイクからの音声録音機能。録音の開始・停止、録音状態の表示、録音データの WAV ファイルへの保存、ファイル名の命名を含む

### Modified Capabilities

- `voice-reference-library`: 録音完了後のファイルが voices/ ディレクトリに保存された際、既存のファイルリスト更新フローと統合する必要がある

## Impact

- **依存パッケージ**: マイク録音用の Flutter パッケージ（例: `record`）を新規追加
- **プラットフォーム権限**: macOS の `Info.plist` にマイクアクセス権限（`NSMicrophoneUsageDescription`）の追加が必要。Windows は追加設定不要
- **UI**: `settings_dialog.dart` の `_buildVoiceReferenceSelector()` セクションに録音ボタンと録音中の状態表示を追加
- **サービス層**: `VoiceReferenceService` に録音ファイルの保存処理を追加、または新規録音サービスを作成
