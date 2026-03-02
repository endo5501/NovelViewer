## 1. セットアップ（依存パッケージ・プラットフォーム設定）

- [ ] 1.1 `record` パッケージを `pubspec.yaml` に追加し `fvm flutter pub get` を実行
- [ ] 1.2 `macos/Runner/Info.plist` に `NSMicrophoneUsageDescription` キーを追加
- [ ] 1.3 `macos/Runner/DebugProfile.entitlements` に `com.apple.security.device.audio-input` を追加
- [ ] 1.4 `macos/Runner/Release.entitlements` に `com.apple.security.device.audio-input` を追加

## 2. VoiceReferenceService 拡張（moveVoiceFile）

- [ ] 2.1 `moveVoiceFile` メソッドのテストを作成（移動成功、拡張子バリデーション、重複拒否、ディレクトリ自動作成）
- [ ] 2.2 `VoiceReferenceService` に `moveVoiceFile(String sourcePath, String targetFileName)` メソッドを実装

## 3. VoiceRecordingService（録音コアロジック）

- [ ] 3.1 `VoiceRecordingService` のテストを作成（録音開始・停止、権限チェック、一時ファイルパス生成）
- [ ] 3.2 `lib/features/tts/data/voice_recording_service.dart` に `VoiceRecordingService` クラスを実装（`AudioRecorder` をラップ、WAV 16kHz/16bit/mono で録音、一時ファイル管理）
- [ ] 3.3 `lib/features/tts/providers/tts_settings_providers.dart` に `voiceRecordingServiceProvider` を追加

## 4. VoiceRecordingDialog（録音ダイアログ UI）

- [ ] 4.1 `lib/features/tts/presentation/voice_recording_dialog.dart` に `VoiceRecordingDialog` を実装（録音開始/停止ボタン、経過時間 MM:SS 表示、音声レベルインジケーター）
- [ ] 4.2 録音停止後のファイル名入力ダイアログを実装（`.wav` 拡張子自動付与、重複チェックバリデーション）
- [ ] 4.3 保存処理を実装（`VoiceReferenceService.moveVoiceFile` で voices/ に保存、保存したファイル名を返して閉じる）
- [ ] 4.4 `PopScope` による録音中のダイアログ閉じ防止と確認ダイアログを実装
- [ ] 4.5 ダイアログ dispose 時の一時ファイルクリーンアップを実装

## 5. SettingsDialog への統合

- [ ] 5.1 `_buildVoiceReferenceSelector()` に録音ボタン（マイクアイコン）を追加
- [ ] 5.2 録音ボタン押下時に `VoiceRecordingDialog` を表示し、保存完了後にファイルリストを更新する処理を実装

## 6. 最終確認

- [ ] 6.1 simplifyスキルを使用してコードレビューを実施
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 6.3 `fvm flutter analyze`でリントを実行
- [ ] 6.4 `fvm flutter test`でテストを実行
