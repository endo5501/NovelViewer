## 1. 依存パッケージの追加

- [ ] 1.1 `pubspec.yaml`に`just_audio_media_kit`と`media_kit_libs_windows_audio`を依存に追加
- [ ] 1.2 `fvm flutter pub get`を実行して依存を解決

## 2. Windows向け初期化コードの追加

- [ ] 2.1 `lib/main.dart`に`JustAudioMediaKit`のimportを追加
- [ ] 2.2 `main()`関数内で`Platform.isWindows`の場合のみ`JustAudioMediaKit.ensureInitialized()`を呼び出すコードを追加（`WidgetsFlutterBinding.ensureInitialized()`の後に配置）

## 3. 動作確認

- [ ] 3.1 Windows環境でアプリをビルドし、TTS読み上げで音声が再生されることを確認
- [ ] 3.2 macOS環境で既存のTTS読み上げが引き続き正常動作することを確認（可能であれば）

## 4. 最終確認

- [ ] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze`でリントを実行
- [ ] 4.4 `fvm flutter test`でテストを実行
