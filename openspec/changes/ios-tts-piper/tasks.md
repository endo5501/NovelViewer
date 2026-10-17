## 1. 機能モデル: エンジンごとの可否と音声書き出し

- [x] 1.1 `test/shared/platform/platform_capabilities_test.dart` を書き換える(spec `platform-capabilities` の新しい要件のシナリオ)。iOS では `piperTts` だけが true で、`qwen3Tts` / `irodoriTts` / `ttsAudioExport` / `appUpdate` は false、`textToSpeech` は true。デスクトップではすべて true。`textToSpeech` は、どれかのエンジンが使えるときだけ true。確認: テストが失敗する
- [x] 1.2 `PlatformCapabilities` にフィールドを加え、`textToSpeech` を getter にする(design D1)。確認: 1.1 と既存の `platform_capabilities_provider_test.dart` が通る
- [x] 1.3 `features/tts/providers/` に `supportedTtsEnginesProvider`(表示順は Qwen3-TTS → Piper → Irodori-TTS)と `ttsAudioExportSupportedProvider` を加える。テストを先に書き、機能モデルの provider を上書きして iOS とデスクトップの両方を確かめる。`tts_availability_provider.dart` のコメントの iOS についての説明も、実態に合わせて直す。確認: 追加したテストと、既存の `tts_availability_gate_test.dart` が通る

## 2. 使うエンジンの解決とエンジン選択の UI

- [x] 2.1 `TtsEngineTypeNotifier` のテストを書く(spec `tts-engine-selection` の追加要件)。iOS で保存値なしなら piper。iOS で保存値が irodori なら piper になり、保存値は irodori のまま。デスクトップで irodori なら irodori。`setEngineType` は保存する。確認: テストが失敗する
- [x] 2.2 `TtsEngineTypeNotifier.build()` で、保存値を使えるエンジンに解決する(design D2)。確認: 2.1 と既存の TTS 関連テストが通る
- [x] 2.3 設定ダイアログのテストを書く。iOS の値では、エンジン選択が無く Piper の設定が表示され、参照音声の欄は無い。一部のエンジンだけが使える値では、選択肢がそれだけになる。デスクトップでは従来どおり 3 つ。確認: テストが失敗する
- [x] 2.4 `_EngineSelector` を `supportedTtsEnginesProvider` から組み立て、1 つしかなければ出さないようにする(design D3)。確認: 2.3 と `settings_dialog_*` の既存テストが通る

## 3. MP3 書き出しと参照音声の列

- [x] 3.1 `tts_controls_bar_test.dart` に、書き出しが使えない値ではボタンが無く(削除ボタンなどは表示される)、使える値ではボタンがあることのテストを加える(spec `tts-audio-export`)。確認: テストが失敗する
- [x] 3.2 `TtsControlsBar` の書き出しボタンと進捗表示を `ttsAudioExportSupportedProvider` で出し分ける(design D4)。確認: 3.1 と既存の `tts_controls_bar_test.dart` が通る
- [x] 3.3 `TtsEngineType.usesReferenceVoice` のテストと、編集ダイアログのテストを書く(spec `tts-edit-screen`)。Piper では、どの行にも参照音声の選択が無く、ほかの操作は表示される。Qwen3 / Irodori では従来どおり。Piper で開いて閉じても、区間の `ref_wav_path` は変わらない。確認: テストが失敗する
- [x] 3.4 `usesReferenceVoice` を加え、`TtsEditDialog` から `TtsEditSegmentRow` に列を出すかどうかを渡す。出さないときは、参照音声の一覧も読み込まない(design D5)。確認: 3.3 と `tts_edit_*` の既存テストが通る

## 4. 読み込み失敗の理由を伝える

- [x] 4.1 `PiperNativeBindings` に、OS ごとのビルド手順を返す純粋関数のテストと、ライブラリを開けないときに `TtsEngineException` になることのテストを書く(spec `piper-tts-native-engine` の追加要件)。存在しないパスを開かせ、例外の文言にライブラリ名・手順・元のエラーが含まれることを確かめる。確認: テストが失敗する
- [x] 4.2 `PiperNativeBindings.open()` で `ArgumentError` を `TtsEngineException` にする(design D6)。確認: 4.1 と既存の `piper_native_bindings_test.dart` が通る
- [x] 4.3 `TtsSession.lastModelLoadError` と、`TtsStreamingController` が読み込み失敗の理由を `lastFailureReason` に入れることのテストを書く(spec `tts-streaming-pipeline` の追加要件)。読み込み失敗で理由が入ること、中断では通知が出ないこと、後の実行に前の理由が残らないこと。確認: テストが失敗する
- [x] 4.4 `TtsSession` と `TtsStreamingController` を直す(design D7)。編集ダイアログの単体生成でも、読み込み失敗の理由が同じように伝わるようにする。確認: 4.3 と `tts_session_test.dart` / `tts_streaming_controller_test.dart` の既存テストが通る

## 5. ドキュメントと iPad 実機での確認

- [x] 5.1 `docs/ipad.md` を更新する。機能表で読み上げを「Piper のみ提供」にし、MP3 書き出しと画面ロック中の再生は提供しないことを書く。TTS の節には、使い方(設定でモデルをダウンロード → 読み上げ)と、ライブラリをビルドしていないと読み上げが失敗することを書く。あわせて `.claude/CLAUDE.md` の `build_app.sh ios` の説明(「TTSのUIは未対応」)も直す。確認: 書いた手順どおりに実機で操作できる(5.3 で確かめる)
- [x] 5.2 `scripts/build_piper_ios.sh` の後に `scripts/build_app.sh ios --release` でビルドし、iPad 実機にインストールする。確認: インストールして起動できる
- [x] 5.3 iPad 実機で design D8 の項目を手で確かめ、結果を design.md に記録する。項目は、モデルのダウンロード、読み上げ(生成・再生・一時停止・停止)、編集ダイアログ(参照音声の列が無い、区間の再生・再生成)、読み上げ辞書、書き出しボタンが無いこと、消音設定の有無による再生の違い、縦向き・横向きでの読み上げボタンの重なり。確認: すべての項目に結果が記録されている。消音で音が出ない問題が見つかった場合は、design のリスクに従ってタスクを追加する
- [x] 5.4 `test/platform/ios_project_config_test.dart` に、同梱フェーズが同梱した一覧を `TARGET_TEMP_DIR` に記録し、その一覧を使って無くなった framework を取り除くことの検査を加える(spec `ios-build-target`、design D9)。確認: テストが失敗する
- [ ] 5.5 同梱フェーズを直す(design D9)。確認: 5.4 のテストが通り、`xcodebuild -list` がエラーなく動く。xcframework ありでビルドしたあと、外して差分ビルドすると `Runner.app/Frameworks/` から `piper_plus.framework` が消え、Flutter の framework は残る
- [ ] 5.6 xcframework を外したビルドを iPad に入れて読み上げを押し、失敗通知に D6 のメッセージ(`piper_plus.framework` と `scripts/build_piper_ios.sh`)が出ることを確かめる。確認後、xcframework を戻して入れ直す。確認: 通知の詳細に、そのメッセージが表示される

## 6. 最終確認

- [ ] 6.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 6.3 `fvm dart format lib test`でフォーマットを実行
- [ ] 6.4 `fvm flutter analyze`でリントを実行
- [ ] 6.5 `fvm flutter test`でテストを実行
