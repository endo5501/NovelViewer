# Tasks: Add Irodori TTS Engine (audio.cpp)

## 1. 事前準備 (フォーク・モデル配信)

- [x] 1.1 Irodori-TTS-600M-v3-VoiceDesign / Semantic-DACVAE のライセンスを確認し、再配布可否と必要な帰属表示を記録する (600M: MIT+倫理条項 / llm-jp: Apache-2.0 / DACVAE: MIT。帰属表示は HF リポジトリ README に記載済み)
- [x] 1.2 DACVAE weights.pth を safetensors に変換し、endo5501 HF リポジトリに4資産 (600M / llm-jp tokenizer / DACVAE / 必須構成ファイル) を design D7 のレイアウトでアップロードする (https://huggingface.co/endo5501/audio.cpp に最小4ファイル構成でアップロード済み・resolve URL 疎通確認済み)
- [x] 1.3 endo5501/audio.cpp フォークに abort パッチを実装する: `IrodoriTTSSession` の RF per-step ループ先頭で `std::atomic<bool>` フラグを確認し中断 (design D4)
- [x] 1.4 フォークに `src/audiocpp_c_api.{h,cpp}` を実装する: abort handle (ctx と独立ライフタイム) / init (registry→load→create_task_session, GPU優先+CPUフォールバック, model spec 解決) / 統合 synthesize (ref_wav・caption NULL可, guidance 2種, steps) / get_audio 系 / get_error (design D3)
- [x] 1.5 フォークの CMake に `AUDIOCPP_BUILD_SHARED` オプションと `audiocpp_ffi` 共有ライブラリターゲットを追加する (engine_runtime 静的リンク)
- [x] 1.6 フォークの CLI または最小 C テストで shim の4合成形態 (素/クローン/caption/両立) と abort 動作を確認し、フォークにタグを付ける

## 2. ビルド統合 (NovelViewer 本体)

- [x] 2.1 `third_party/audio.cpp` に endo5501/audio.cpp フォークを git submodule として追加する (タグピン留め)
- [x] 2.2 `scripts/build_irodori_windows.bat` を作成する: Vulkan 有効 + `/utf-8` + `/openmp:experimental` で `audiocpp_ffi.dll` をビルドし `build/windows/x64/runner/Release/` へ配置、`model_specs/irodori_tts.json` を同梱 (design D5/D6)
- [x] 2.3 `scripts/build_irodori_macos.sh` を作成する: Metal 有効で `libaudiocpp_ffi.dylib` をビルドし `macos/Frameworks/` へ配置
- [x] 2.4 Windows でビルドスクリプトを実行し、DLL 生成と依存の静的リンクを確認する

## 3. Dart FFI バインディングとエンジンラッパー (TDD)

- [x] 3.1 `AudiocppNativeBindings` のテストを作成する (ライブラリ名解決、全シンボル lookup) → 失敗確認 → コミット
- [x] 3.2 `AudiocppNativeBindings` を実装しテストをパスさせる
- [x] 3.3 `IrodoriTtsEngine` のテストを作成する (loadModel / synthesize(text, refWavPath?, caption?) / 未ロードエラー / abort / dispose、モック bindings 使用) → 失敗確認 → コミット
- [x] 3.4 `IrodoriTtsEngine` を実装しテストをパスさせる (TtsSynthesisResult 48kHz)

## 4. エンジン種別・設定型の拡張 (TDD)

- [x] 4.1 `TtsEngineType.irodori` 追加のテストを作成する (enum / label / 永続化 "irodori") → 失敗確認 → コミット
- [x] 4.2 `TtsEngineType` と永続化を実装しテストをパスさせる
- [x] 4.3 `IrodoriEngineConfig` のテストを作成する (フィールド / sampleRate 48000 / modelLoadKey が modelDir のみ依存 / resolveFromReader の3分岐) → 失敗確認 → コミット
- [x] 4.4 `IrodoriEngineConfig` と resolve 分岐、Irodori パラメータ用プロバイダ (guidance 2種・steps、既定 5.0/3.0/40、SharedPreferences 永続化) を実装しテストをパスさせる

## 5. TtsIsolate 第3ブランチと caption 伝搬 (TDD)

- [x] 5.1 `TtsIsolate` Irodori ブランチのテストを作成する (IrodoriEngineConfig でのロード / caption 付き合成リクエスト / caption 変更で再ロードなし / abort / dispose) → 失敗確認 → コミット
- [x] 5.2 `TtsIsolate` / `TtsSession` / adapters に Irodori ブランチと `caption` パラメータを実装しテストをパスさせる (qwen3/piper ブランチ非破壊)
- [ ] 5.3 caption 伝搬のテストを作成する (Irodori 選択時: segment.memo → caption、memo 空 → caption なし、qwen3 選択時: memo 不使用) → 失敗確認 → コミット
- [ ] 5.4 ストリーミングパイプライン・編集ダイアログ再生成・保存済み再合成に memo → caption 配線を実装しテストをパスさせる

## 6. モデルダウンロード (TDD)

- [ ] 6.1 `IrodoriModelDownloadService` のテストを作成する (4資産 URL / 保存レイアウト / 進捗通知 / ダウンロード済み判定 / 完了済みファイル skip / キャンセル) → 失敗確認 → コミット
- [ ] 6.2 `IrodoriModelDownloadService` と providers を実装しテストをパスさせる (既存 qwen3/piper ダウンロードサービスの型を踏襲)

## 7. 設定 UI と国際化

- [ ] 7.1 `IrodoriSettingsSection` を実装する (モデルダウンロード UI / guidance スライダー2種 / steps 入力)、エンジン選択 SegmentedButton を3値化する
- [ ] 7.2 ARB 3言語 (ja/en/zh) に Irodori セクションの全ラベルキーを追加し、ウィジェットテストで表示と永続化を確認する
- [ ] 7.3 実機で E2E 確認: モデルダウンロード → クローンのみ合成 → メモ記入 → 再生成で caption 両立 → 再生中の中断

## 8. CI

- [ ] 8.1 CI ワークフローに audiocpp DLL ビルドステップ (build_irodori_windows.bat) と成果物検証 (audiocpp_ffi.dll / model spec) を flutter build より前に追加する

## 9. 最終確認

- [ ] 9.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 9.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 9.3 `fvm flutter analyze`でリントを実行
- [ ] 9.4 `fvm flutter test`でテストを実行
