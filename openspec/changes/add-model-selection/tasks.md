## 1. TtsModelSize enum と設定永続化

- [ ] 1.1 `TtsModelSize` enumを作成（`small`/`large`、`dirName`, `modelFileName`, `label`プロパティ）
- [ ] 1.2 `SettingsRepository`に`getTtsModelSize`/`setTtsModelSize`を追加、`getTtsModelDir`/`setTtsModelDir`を削除
- [ ] 1.3 `TtsModelSizeNotifier`プロバイダーを作成（`tts_model_size`キーの読み書き）
- [ ] 1.4 `ttsModelDirProvider`を書き込み可能Notifierから読み取り専用Providerに変更（modelSizeとlibraryPathから自動算出）

## 2. ダウンロードサービスの変更

- [ ] 2.1 `TtsModelDownloadService`のbaseURLを`endo5501/qwen3-tts.cpp`に変更
- [ ] 2.2 `downloadModels`と`areModelsDownloaded`にモデルサイズ引数を追加、サイズ別ファイルリストとサブディレクトリ対応
- [ ] 2.3 `resolveModelsDir`をサイズ別サブディレクトリ対応に変更（`models/{size}/`）

## 3. レガシーマイグレーション

- [ ] 3.1 `TtsModelDownloadService`に`migrateFromLegacyDir`メソッドを追加（`models/`直下→`models/0.6b/`へのファイル移動）
- [ ] 3.2 `TtsModelDownloadNotifier.build()`でマイグレーションを呼び出し

## 4. ダウンロードプロバイダーの変更

- [ ] 4.1 `TtsModelDownloadNotifier`を選択中モデルサイズに対応したDL状態管理に変更
- [ ] 4.2 DL完了時の`ttsModelDirProvider`更新を削除（自動算出に依存）

## 5. 設定UI変更

- [ ] 5.1 読み上げタブにSegmentedButton（高速 0.6B / 高精度 1.7B）を追加
- [ ] 5.2 モデルディレクトリ手動設定フィールド（テキストフィールド＋フォルダピッカー）を削除
- [ ] 5.3 ダウンロード状態表示を選択中モデルに連動させる

## 6. 既存参照箇所の修正

- [ ] 6.1 `TtsModelDirNotifier`を削除し、参照箇所を新しい`ttsModelDirProvider`に更新
- [ ] 6.2 `TtsEngine`/`TtsIsolate`等のモデルディレクトリ参照箇所が新Providerで動作することを確認

## 7. 最終確認

- [ ] 7.1 simplifyスキルを使用してコードレビューを実施
- [ ] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 7.3 `fvm flutter analyze`でリントを実行
- [ ] 7.4 `fvm flutter test`でテストを実行
