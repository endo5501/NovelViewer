## 1. サブモジュール追加とビルド基盤

- [x] 1.1 qwen3-tts.cpp を git サブモジュールとして `third_party/qwen3-tts.cpp` に追加し、再帰的にサブモジュール（GGML）を初期化する
- [x] 1.2 qwen3-tts.cpp の C API ラッパー（`qwen3_tts_c_api.h` / `qwen3_tts_c_api.cpp`）を `third_party/qwen3-tts.cpp/src/` に作成する。C API は `qwen3_tts_init`, `qwen3_tts_is_loaded`, `qwen3_tts_free`, `qwen3_tts_synthesize`, `qwen3_tts_synthesize_with_voice`, `qwen3_tts_get_audio`, `qwen3_tts_get_audio_length`, `qwen3_tts_get_sample_rate`, `qwen3_tts_get_error` を公開する
- [x] 1.3 qwen3-tts.cpp の CMakeLists.txt に共有ライブラリターゲット `qwen3_tts_ffi` (SHARED) を追加する。C API ラッパーをソースに含め、既存の静的ライブラリ群をリンクする
- [x] 1.4 macOS 向けビルドスクリプトを作成する。GGML を Metal 有効でビルドし、共有ライブラリをビルドして `macos/Frameworks/` にコピーする。Xcode プロジェクトに Embed Frameworks を設定する
- [x] 1.5 Windows 向けビルドスクリプトを作成する。GGML を CPU バックエンドでビルドし、共有ライブラリをビルドして実行ファイルディレクトリにコピーする
- [x] 1.6 macOS でビルドが成功し、共有ライブラリが正しくバンドルされることを確認する

## 2. Dart FFI バインディング

- [x] 2.1 `lib/features/tts/data/` ディレクトリを作成し、FFI バインディングクラス `TtsNativeBindings` のテストを作成する。共有ライブラリのロード、各 C API 関数のバインディング存在確認をテストする
- [x] 2.2 `TtsNativeBindings` クラスを実装する。プラットフォームに応じて `.dylib` / `.dll` をロードし、全 C API 関数の FFI バインディングを定義する
- [x] 2.3 FFI バインディングの上位ラッパー `TtsEngine` クラスのテストを作成する。`loadModel()`, `synthesize()`, `synthesizeWithVoice()`, `dispose()` の Dart フレンドリーな API をテストする
- [x] 2.4 `TtsEngine` クラスを実装する。FFI の生ポインタ操作を隠蔽し、`Float32List` や `String` を返す Dart API を提供する

## 3. テキスト分割

- [x] 3.1 `lib/features/tts/data/text_segmenter.dart` のテストを作成する。句点分割、括弧考慮、改行分割、空セグメント除外、ルビタグ除去、オフセット追跡をテストする
- [x] 3.2 `TextSegmenter` クラスを実装する。`splitIntoSentences(String text)` メソッドで `List<TextSegment>` を返す（`TextSegment` は `text`, `offset`, `length` を持つ）

## 4. 音声ファイル管理

- [x] 4.1 `lib/features/tts/data/wav_writer.dart` のテストを作成する。Float32List から WAV ファイル（24kHz, mono, 16-bit PCM）への変換を検証する
- [x] 4.2 `WavWriter` クラスを実装する。WAV ヘッダ生成と float→16-bit PCM 変換を行い、一時ファイルに書き出す
- [x] 4.3 pubspec.yaml に `just_audio` パッケージを追加する

## 5. TTS Isolate

- [x] 5.1 `lib/features/tts/data/tts_isolate.dart` のテストを作成する。Isolate でのモデルロード、合成リクエスト送信、結果受信、エラーハンドリングをテストする
- [x] 5.2 `TtsIsolate` クラスを実装する。バックグラウンド Isolate を起動し、`SendPort`/`ReceivePort` でメイン Isolate と通信する。モデルロードと合成を Isolate 内で実行する
- [x] 5.3 Isolate 間のオーディオデータ転送に `TransferableTypedData` を使用してコピーを回避する

## 6. TTS 設定

- [x] 6.1 `SettingsRepository` に TTS 設定（モデルディレクトリパス、WAV ファイルパス）の読み書きメソッドのテストを作成する
- [x] 6.2 `SettingsRepository` に `getTtsModelDir()`, `setTtsModelDir()`, `getTtsRefWavPath()`, `setTtsRefWavPath()` を追加する
- [x] 6.3 TTS 設定用の Riverpod Provider（`ttsModelDirProvider`, `ttsRefWavPathProvider`）のテストを作成する
- [x] 6.4 TTS 設定用の Riverpod Provider を `lib/features/tts/providers/` に実装する
- [x] 6.5 設定ダイアログのタブ化テストを作成する。「一般」タブに既存設定、「読み上げ」タブにTTS設定が表示されることを検証する
- [x] 6.6 `SettingsDialog` を `TabBar` + `TabBarView` に変更し、既存設定を「一般」タブに移動する
- [x] 6.7 「読み上げ」タブに TTS 設定 UI（モデルディレクトリパス、WAV ファイルパス）を追加する。`file_picker` パッケージでフォルダ/ファイル選択ダイアログを提供する
- [x] 6.8 pubspec.yaml に `file_picker` パッケージを追加する

## 7. 再生パイプラインとステート管理

- [x] 7.1 TTS 再生状態の Riverpod Provider（`ttsPlaybackStateProvider`, `ttsHighlightRangeProvider`）のテストを作成する
- [x] 7.2 TTS 再生状態の Provider を実装する。状態は `stopped`, `loading`, `playing` の 3 値、ハイライト範囲は `TextRange?` で管理する
- [x] 7.3 再生パイプライン `TtsPlaybackController` のテストを作成する。再生開始（選択位置 / 表示先頭）、順次再生、先読み、停止、エラーハンドリングをテストする
- [x] 7.4 `TtsPlaybackController` を実装する。テキスト分割 → Isolate で生成 → WAV 書き出し → just_audio で再生 → ハイライト更新の一連のフローを管理する
- [x] 7.5 先読み生成を実装する。現在の文を再生中に次の文の音声を TTS Isolate で事前生成する
- [x] 7.6 再生完了・停止時に一時 WAV ファイルをクリーンアップする処理を実装する

## 8. テキストビューア統合

- [ ] 8.1 再生/停止ボタンの表示テストを作成する。TTS 状態に応じたボタン表示（play/stop/loading）、TTS 未設定時の無効化を検証する
- [ ] 8.2 `TextViewerPanel` に再生/停止ボタンを追加する。`ttsPlaybackStateProvider` を監視してボタンの状態を切り替える
- [ ] 8.3 横書きモードの TTS ハイライトレンダリングテストを作成する。`ttsHighlightRangeProvider` の範囲に緑色ハイライトが適用されることを検証する
- [ ] 8.4 横書きモード (`TextViewerPanel`) に TTS ハイライトレンダリングを実装する。`SelectableText.rich` の TextSpan にハイライトスタイルを適用する
- [ ] 8.5 縦書きモードの TTS ハイライトレンダリングテストを作成する
- [ ] 8.6 縦書きモード (`VerticalTextPage`) に TTS ハイライトレンダリングを実装する。文字ごとの背景色に TTS ハイライトを反映する
- [ ] 8.7 ハイライト優先順位テストを作成する。検索ハイライト（黄）> TTS ハイライト（緑）> 選択ハイライト（青）の順を検証する
- [ ] 8.8 ハイライト優先順位ロジックを横書き・縦書き両モードに実装する

## 9. 自動ページ送り

- [ ] 9.1 縦書きモードの自動ページ送りテストを作成する。ハイライト範囲のオフセットからページ番号を算出し、現在ページと異なる場合にページ遷移することを検証する
- [ ] 9.2 縦書きモードの自動ページ送りを実装する。`ttsHighlightRangeProvider` の変更を監視し、必要に応じて `_goToPage()` を呼び出す
- [ ] 9.3 横書きモードの自動スクロールテストを作成する
- [ ] 9.4 横書きモードの自動スクロールを実装する。`ScrollController` でハイライト位置までスクロールする

## 10. ユーザー操作による停止

- [ ] 10.1 ユーザーのページ操作で TTS が停止するテストを作成する。矢印キー、スワイプ、マウスホイールの各操作を検証する
- [ ] 10.2 `VerticalTextViewer` のページ操作ハンドラに TTS 停止処理を追加する。TTS 自身の自動ページ送りとユーザー操作を区別するフラグを導入する
- [ ] 10.3 横書きモードのスクロールハンドラに TTS 停止処理を追加する

## 11. 再生開始位置の決定

- [ ] 11.1 再生開始位置決定ロジックのテストを作成する。選択テキストあり → 選択開始位置の文から、選択なし → 表示先頭の文からの2パターンを検証する
- [ ] 11.2 再生開始位置決定ロジックを `TtsPlaybackController` に実装する。`selectedTextProvider` と現在の表示位置（ページ番号 / スクロール位置）から開始文を決定する

## 12. 最終確認

- [ ] 12.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 12.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 12.3 `fvm flutter analyze`でリントを実行
- [ ] 12.4 `fvm flutter test`でテストを実行
