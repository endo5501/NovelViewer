## 1. TtsLanguage enum 定義

- [x] 1.1 `lib/features/tts/data/tts_language.dart` に `TtsLanguage` enum を作成（10言語、languageId・displayName プロパティ付き）
- [x] 1.2 `TtsLanguage` enum のユニットテストを作成

## 2. 設定の永続化

- [x] 2.1 `SettingsRepository` に `getTtsLanguage()` / `setTtsLanguage()` メソッドを追加（キー: `tts_language`、デフォルト: `ja`）
- [x] 2.2 `SettingsRepository` の言語設定メソッドのテストを作成

## 3. Riverpod プロバイダー

- [x] 3.1 `tts_settings_providers.dart` に `ttsLanguageProvider` (NotifierProvider) を追加
- [x] 3.2 `ttsLanguageProvider` のテストを作成

## 4. TTS エンジン連携

- [x] 4.1 `tts_engine.dart` の `languageJapanese` 定数を削除し、`TtsLanguage` enum を使用するよう変更
- [x] 4.2 `tts_isolate.dart` に `SetLanguageMessage` を追加し、`loadModel` のデフォルト言語をプロバイダーから取得するよう変更
- [x] 4.3 `tts_generation_controller.dart` で `ttsLanguageProvider` から言語設定を読み取り、isolate に渡すよう変更
- [x] 4.4 TTS エンジン連携のテストを作成

## 5. 設定画面 UI

- [x] 5.1 `settings_dialog.dart` の `_buildTtsTab()` にモデルサイズセレクターの上に言語選択ドロップダウンを追加
- [x] 5.2 言語選択ドロップダウンのウィジェットテストを作成

## 6. 最終確認

- [x] 6.1 simplifyスキルを使用してコードレビューを実施
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
