## 1. ネイティブMP3デコード対応

- [ ] 1.1 minimp3ヘッダーファイル（`minimp3.h`, `minimp3_ex.h`）を`third_party/qwen3-tts.cpp/`内に配置
- [ ] 1.2 `load_audio_file`関数にファイル拡張子判定（case-insensitive）を追加し、`.wav`と`.mp3`で処理を分岐
- [ ] 1.3 MP3デコードパスを実装（minimp3でデコード→float正規化→マルチチャンネルのモノラルミックスダウン）
- [ ] 1.4 未対応拡張子の場合にエラーメッセージを返す処理を追加
- [ ] 1.5 MP3リファレンスファイルでの音声合成が動作することを手動確認

## 2. VoiceReferenceService実装

- [ ] 2.1 `VoiceReferenceService`クラスを作成（`lib/features/tts/data/voice_reference_service.dart`）
- [ ] 2.2 `voicesDir`パス解決メソッドを実装（`libraryPath`の親ディレクトリ + `voices`）
- [ ] 2.3 voicesディレクトリの自動作成ロジックを実装
- [ ] 2.4 音声ファイル列挙メソッドを実装（`.wav`, `.mp3`フィルタ、アルファベット順ソート、トップレベルのみ）
- [ ] 2.5 ファイル名→フルパス解決メソッドを実装
- [ ] 2.6 voicesディレクトリをファイルマネージャーで開くメソッドを実装（macOS: Finder、Windows: Explorer）
- [ ] 2.7 `VoiceReferenceService`のRiverpodプロバイダーを作成
- [ ] 2.8 `VoiceReferenceService`のユニットテストを作成

## 3. 設定の永続化変更

- [ ] 3.1 `SettingsRepository`のリファレンス音声設定をファイル名のみ保存する形式に変更
- [ ] 3.2 `ttsRefWavPathProvider`をファイル名ベースの管理に更新し、フルパス解決は`VoiceReferenceService`経由で行う
- [ ] 3.3 永続化のユニットテストを更新

## 4. 設定UI変更

- [ ] 4.1 voicesフォルダ内ファイル一覧を取得するプロバイダーを作成
- [ ] 4.2 `settings_dialog.dart`のリファレンスファイル選択を`TextField`+`FilePicker`から`DropdownButtonFormField`に変更
- [ ] 4.3 「なし（デフォルト音声）」オプションを先頭に追加
- [ ] 4.4 voicesフォルダが空の場合のドロップダウン無効化とヒントテキスト表示を実装
- [ ] 4.5 保存済みファイルが存在しない場合に「なし」を表示するフォールバック処理を実装
- [ ] 4.6 voicesフォルダを開くボタンを追加
- [ ] 4.7 ファイル一覧リフレッシュボタンを追加
- [ ] 4.8 設定UIのウィジェットテストを作成

## 5. TTSパイプライン統合

- [ ] 5.1 TTS合成時にファイル名からフルパスへの解決を`VoiceReferenceService`経由で行うよう`TtsGenerationController`を更新
- [ ] 5.2 `TtsIsolate`へ渡すリファレンスパスがフルパスであることを確認
- [ ] 5.3 統合テストで音声選択→合成のフローが正しく動作することを確認

## 6. 最終確認

- [ ] 6.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 6.3 `fvm flutter analyze`でリントを実行
- [ ] 6.4 `fvm flutter test`でテストを実行
