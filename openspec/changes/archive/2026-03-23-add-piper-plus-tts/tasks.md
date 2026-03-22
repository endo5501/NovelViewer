## 1. piper-plusフォーク準備とC APIラッパー

- [x] 1.1 `third_party/piper-plus/` にフォーク（https://github.com/endo5501/piper-plus）をgit submoduleとして追加
- [x] 1.2 `src/cpp/piper_tts_c_api.h` を作成（C API関数宣言: init, is_loaded, free, synthesize, set_length_scale, set_noise_scale, set_noise_w, get_audio, get_audio_length, get_sample_rate, get_error）
- [x] 1.3 `src/cpp/piper_tts_c_api.cpp` を作成（piper::Voice/PiperConfigのラップ、int16→float32変換、エラーハンドリング）
- [x] 1.4 CMakeLists.txtに `PIPER_TTS_BUILD_SHARED` オプションと `piper_tts_ffi` 共有ライブラリターゲットを追加

## 2. ビルドスクリプト

- [x] 2.1 `scripts/build_piper_macos.sh` を作成（CPU版ONNX Runtime、arm64、出力先macos/Frameworks/）
- [x] 2.2 `scripts/build_piper_windows.bat` を作成（CPU版ONNX Runtime、MSVC、出力先ビルドディレクトリ）
- [x] 2.3 macOSでビルドスクリプトを実行し `libpiper_tts_ffi.dylib` と `libonnxruntime.dylib` が生成されることを確認

## 3. Dart FFIバインディングとエンジンラッパー

- [x] 3.1 `TtsEngineType` enumを作成（qwen3, piper）
- [x] 3.2 `PiperNativeBindings` クラスを作成（libpiper_tts_ffi のロードと全C API関数のバインディング）
- [x] 3.3 `PiperTtsEngine` クラスを作成（loadModel, synthesize, setLengthScale, setNoiseScale, setNoiseW, dispose）
- [x] 3.4 `PiperTtsEngine.synthesize()` が既存の `TtsSynthesisResult` を返すことをテストで確認

## 4. TtsIsolateのエンジン分岐

- [x] 4.1 `LoadModelMessage` に `engineType`、`dicDir`、合成パラメータ（lengthScale, noiseScale, noiseW）フィールドを追加
- [x] 4.2 `TtsIsolate._isolateEntryPoint` でengineTypeに応じた分岐を実装（qwen3→TtsEngine、piper→PiperTtsEngine）
- [x] 4.3 `TtsIsolate.loadModel()` メソッドにengineType等のパラメータを追加
- [x] 4.4 piper選択時に合成パラメータ（lengthScale, noiseScale, noiseW）がエンジンに適用されることをテストで確認

## 5. TtsStreamingController/TtsGenerationControllerの対応

- [x] 5.1 `TtsStreamingController.start()` にengineType、dicDir、合成パラメータを追加
- [x] 5.2 piper選択時にrefWavPathが無視されることを確認
- [x] 5.3 `TtsGenerationController` にも同様のengineType対応を追加
- [x] 5.4 既存のqwen3-ttsフローが変更なく動作することをテストで確認

## 6. エンジン選択の永続化とProvider

- [x] 6.1 `SettingsRepository` にttsEngineType（SharedPreferencesキー: `tts_engine_type`）のgetter/setterを追加
- [x] 6.2 `ttsEngineTypeProvider`（NotifierProvider）を作成
- [x] 6.3 `piperModelNameProvider` を作成（SharedPreferencesキー: `piper_model_name`、デフォルト: `tsukuyomi-chan-6lang-fp16`）

## 7. piper合成パラメータの永続化とProvider

- [x] 7.1 `SettingsRepository` にpiperLengthScale、piperNoiseScale、piperNoiseWのgetter/setterを追加
- [x] 7.2 `piperLengthScaleProvider`、`piperNoiseScaleProvider`、`piperNoiseWProvider` を作成
- [x] 7.3 各providerのデフォルト値（1.3, 0.667, 0.8）と永続化のテストを作成

## 8. piperモデルダウンロード

- [x] 8.1 piperモデルのダウンロードURL定義とファイルリスト（.onnx, .onnx.json, open_jtalk_dic）を定義
- [x] 8.2 `PiperModelDownloadNotifier` を作成（既存のTtsModelDownloadNotifierと同パターン）
- [x] 8.3 OpenJTalk辞書が存在する場合のスキップロジックを実装
- [x] 8.4 piperモデルディレクトリパス解決用のprovider（`piperModelDirProvider`、`piperDicDirProvider`）を作成

## 9. 設定画面UI

- [x] 9.1 TTSタブの最上部にエンジン選択 `SegmentedButton<TtsEngineType>` を追加
- [x] 9.2 qwen3選択時に既存設定（言語、モデルサイズ、DL、参照音声）を表示する条件分岐を実装
- [x] 9.3 piper選択時にpiperモデル選択ドロップダウンを表示
- [x] 9.4 piper選択時にpiperモデルダウンロードセクション（idle/downloading/completed/error状態）を表示
- [x] 9.5 piper選択時に合成パラメータスライダー（lengthScale: 0.5-2.0 step 0.1、noiseScale: 0.0-1.0 step 0.05、noiseW: 0.0-1.0 step 0.05）を表示
- [x] 9.6 エンジン切り替え時に対応するセクションの表示/非表示が正しく動作することを確認

## 10. 読み上げフローの結合

- [x] 10.1 テキストビューアからの読み上げ開始時に、選択されたエンジン種別に応じてTtsStreamingControllerに正しいパラメータを渡す
- [x] 10.2 piper選択時にモデルが未ダウンロードの場合の適切なエラーハンドリングを追加
- [x] 10.3 エンジン切替後に再生済みキャッシュ（DB内のepisode/segment）の扱いを確認（異なるエンジンで生成した音声は混在しないようにする）

## 11. 最終確認

- [x] 11.1 simplifyスキルを使用してコードレビューを実施
- [x] 11.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 11.3 `fvm flutter analyze`でリントを実行
- [x] 11.4 `fvm flutter test`でテストを実行
