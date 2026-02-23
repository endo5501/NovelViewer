## 1. ダウンロードサービス実装

- [ ] 1.1 `TtsModelDownloadState` sealed classを作成（idle, checking, downloading, completed, error）
- [ ] 1.2 `TtsModelDownloadService` クラスを `lib/features/tts/data/tts_model_download_service.dart` に作成（モデルディレクトリパス解決、ファイル存在チェック、ストリーミングダウンロード、部分ファイル削除）
- [ ] 1.3 ダウンロード進捗コールバック（ファイル名、進捗率）を実装

## 2. Riverpodプロバイダ実装

- [ ] 2.1 `modelsDirectoryPathProvider` を作成（libraryPathの親ディレクトリ + `models`）
- [ ] 2.2 `ttsModelDownloadProvider` (Notifier) を作成（ダウンロード状態管理、ファイル存在チェック、ダウンロード実行、完了時のttsModelDirProvider自動設定）

## 3. 設定画面UI実装

- [ ] 3.1 TTSタブにダウンロードセクションを追加（既存フィールドの上部に配置）
- [ ] 3.2 状態別UI表示を実装（未ダウンロード: ボタン、ダウンロード中: プログレスバー+ファイル名+進捗率、完了: ステータス+パス表示、エラー: メッセージ+リトライボタン）
- [ ] 3.3 ダウンロード完了時にモデルディレクトリテキストフィールドを自動更新

## 4. 最終確認

- [ ] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze`でリントを実行
- [ ] 4.4 `fvm flutter test`でテストを実行
