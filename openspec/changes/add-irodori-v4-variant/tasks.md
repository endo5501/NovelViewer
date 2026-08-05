## 1. 前提作業 (ユーザ側)

- [x] 1.1 Hugging Face `endo5501/audio.cpp` へ `Irodori-TTS-v4-Small-GGUF/irodori-tts-v4-small-f16.gguf` (1,762,161,536 バイト) をミラーする
- [x] 1.2 Hugging Face `endo5501/audio.cpp` へ `Irodori-TTS-600M-v3-VoiceDesign-GGUF/irodori-tts-600m-v3-voicedesign-f16.gguf` (1,463,787,680 バイト) をミラーする
- [x] 1.3 ミラー後の実サイズが上記 pin 値と一致することを確認する
- [x] 1.4 先にアップロード済みの q8_0 2本を削除する (spec で配布禁止としたため、pin の取り違えを防ぐ)

## 2. audio.cpp の upstream マージ

- [x] 2.1 `third_party/audio.cpp` で作業ブランチを切り、`upstream/main` をマージする
- [x] 2.2 `conv_modules.cpp` の衝突を upstream 採用で解決する (我々の Hip メンバー不在への回避策は削除)
- [x] 2.3 `wav_reader.cpp` の衝突を我々版採用で解決する (upstream のサイズ詐称対策ハンクは破棄。`remaining_bytes()` によるクランプで目的を達成済み)
- [x] 2.4 `session.h` / `session.cpp` の衝突を解決し、abort パッチをチャンクループと RF サンプリング本体の2箇所へ再適用する (`timesteps` 事前計算ループには入れない)
- [x] 2.5 `session.h` / `session.cpp` の衝突解決時に codec タイル設定 (`codec_decode_tile_frames` / `codec_decode_overlap_frames`) の配線を再適用する
- [x] 2.6 削除された `loader.cpp` の CLI オプション記述2行を、upstream の新しい宣言場所へ移設する
- [x] 2.7 `CMakeLists.txt` の衝突を解決し、我々の5ブロック (`AUDIOCPP_BUILD_SHARED` オプション / `audio_reader.cpp` ソース / minimp3 include ディレクトリ / `audiocpp_ffi` ターゲット / テスト2件の登録) を再配置する
- [x] 2.8 `app/server/runtime.cpp` の衝突を解決する (本アプリは `audiocpp_server` を使わないため upstream 採用でよい)
- [x] 2.9 `docs/tts.md` / `docs/usage.md` の衝突を upstream 採用で解決する
- [x] 2.10 `model_specs/irodori_tts.json` を upstream 版に更新し、我々の独自セッションオプション記述が失われていないか確認する

## 3. マージ後のネイティブ検証

- [x] 3.1 Windows で `scripts/build_irodori_windows.bat` を実行し、`audiocpp_ffi.dll` と `audiocpp_cli.exe` がビルドできることを確認する ※FFI シムがコンパイルできない場合はここで停止し、以降へ進まない
- [x] 3.2 `IrodoriTTSSession` のコンストラクタ引数増加 (`ModelContract`) と `make_irodori_tts_loader()` の導入に対し、`audiocpp_c_api.cpp` のセッション生成を必要なら追随させる
- [x] 3.3 audio.cpp の既存ユニットテスト (`audio_reader_test` / `wav_reader_test` / `codec_tiled_decode_test` ほか) が通ることを確認する
- [x] 3.4 weight context の既定値が 512/768/512 MB から 32MB へ変わった影響を確認し、合成が従来と同等に動作するか検証する。不足するならセッションオプションで明示指定する
- [x] 3.4b q8_0 GGUF が Vulkan で出力を定数フルスケールに飽和させることを確認し、配布精度を f16 に決定する (design D7)
- [x] 3.5 マージ前後で同一入力・同一 seed の v3 合成結果が同等であることを確認する
- [x] 3.6 MP3 参照音声の読み込みが維持されていることを確認する
- [x] 3.7 abort がチャンク境界と RF サンプリング中の双方で効くことを確認する
- [x] 3.8 macOS で `scripts/build_irodori_macos.sh` を実行しビルドできることを確認する
- [x] 3.9 submodule の pin をマージ後のコミットへ更新する

## 4. variant の導入 (TDD)

- [x] 4.1 `IrodoriModelVariant` (v3 / v4) の enum と、既定が v3 であることを検証する失敗するテストを書く
- [x] 4.2 `IrodoriEngineConfig` に variant フィールドが載り、`modelLoadKey` に含まれることを検証する失敗するテストを書く
- [x] 4.3 variant の永続化と復元を検証する失敗するテストを書く (`settings_repository_test`)
- [x] 4.4 4.1〜4.3 のテストが失敗することを確認してコミットする
- [x] 4.5 `IrodoriModelVariant` enum と Riverpod プロバイダを実装する
- [x] 4.6 `IrodoriEngineConfig` に variant フィールドを追加し `modelLoadKey` に含める
- [x] 4.7 `SettingsRepository` に variant の永続化を実装する
- [x] 4.8 4.1〜4.3 のテストが通ることを確認する

## 5. caption ゲート (TDD)

- [x] 5.1 variant が v4 のとき `TtsEngineConfig.captionFromMemo()` が memo の内容にかかわらず null を返すことを検証する失敗するテストを書く
- [x] 5.2 variant が v3 のとき従来どおり memo が caption として返ることを検証するテストを書く (リグレッション防止)
- [x] 5.3 ストリーミング生成・編集ダイアログの再生成・保存済みセグメントの再合成のいずれの経路でも v4 で caption が渡らないことを検証する失敗するテストを書く
- [x] 5.4 5.1〜5.3 のテストが失敗することを確認してコミットする
- [x] 5.5 `captionFromMemo()` に variant ゲートを実装する
- [x] 5.6 5.1〜5.3 のテストが通ることを確認する

## 6. モデルダウンロードの GGUF 化 (TDD)

- [x] 6.1 variant ごとの単一 GGUF パスと pin サイズを検証する失敗するテストを書く
- [x] 6.2 ダウンロード済み判定が variant ごとに独立していることを検証する失敗するテストを書く
- [x] 6.3 サイズが pin 値と一致しない場合にファイルが削除されエラーになることを検証するテストを書く (既存動作の維持)
- [x] 6.4 キャンセルと再試行が従来どおり動作することを検証するテストを書く (既存動作の維持)
- [x] 6.5 6.1〜6.4 のテストが失敗することを確認してコミットする
- [x] 6.6 `IrodoriModelDownloadService` を variant ごとの単一 GGUF ダウンロードへ変更する
- [x] 6.7 `irodori_model_download_providers` のダウンロード状態を variant 単位へ変更する
- [x] 6.8 `tts_model_readiness_provider` を variant を考慮した判定へ変更する
- [x] 6.9 `IrodoriTtsEngine.loadModel()` へ渡すモデルディレクトリを variant ごとの GGUF ディレクトリへ変更する
- [x] 6.10 6.1〜6.4 のテストが通ることを確認する

## 7. 旧 safetensors 資産の後始末 (TDD)

- [x] 7.1 旧形式3ディレクトリの検出と、解放可能容量の算出を検証する失敗するテストを書く
- [x] 7.2 旧資産の存在が新形式のダウンロード済み判定に影響しないことを検証するテストを書く
- [x] 7.3 ユーザ操作による削除で3ディレクトリが削除され、新形式の GGUF が影響を受けないことを検証する失敗するテストを書く
- [x] 7.4 確認なしには削除されないことを検証するテストを書く
- [x] 7.5 7.1〜7.4 のテストが失敗することを確認してコミットする
- [x] 7.6 旧資産の検出・容量算出・削除を実装する
- [x] 7.7 7.1〜7.4 のテストが通ることを確認する

## 8. UI と l10n (TDD)

- [x] 8.1 variant 選択 UI が表示され、選択がプロバイダへ反映されることを検証する失敗するテストを書く
- [x] 8.2 v4 選択時に caption guidance scale の UI が無効化され、理由が表示されることを検証する失敗するテストを書く
- [x] 8.3 v3 に戻すと caption 系 UI が復帰することを検証するテストを書く
- [x] 8.4 旧資産が残っているときに削除導線が表示されることを検証する失敗するテストを書く
- [x] 8.5 追加した文言が ja / en / zh の全ロケールに存在することを検証するテストを書く
- [x] 8.6 8.1〜8.5 のテストが失敗することを確認してコミットする
- [x] 8.7 `irodori_settings_section.dart` に variant 選択 UI を実装する
- [x] 8.8 v4 選択時の caption 系 UI 無効化と理由表示を実装する
- [x] 8.9 旧資産の削除導線を実装する
- [x] 8.10 ja / en / zh の文言を `lib/l10n/` へ追加する
- [x] 8.11 8.1〜8.5 のテストが通ることを確認する

## 9. 実機確認

- [x] 9.1 v3 を選択してモデルをダウンロードし、caption ありの合成が従来どおり動作することを確認する
- [x] 9.2 v4 を選択してモデルをダウンロードし、参照音声のみの合成がクリーンであることを確認する
- [x] 9.3 v4 選択中に memo を記入したセグメントを合成し、末尾に余計な発話が付かないことを確認する
- [x] 9.4 variant を切り替えた際にモデルが再ロードされることを確認する
- [x] 9.5 旧 safetensors 資産の検出・削除が動作することを確認する

## 10. 最終確認

- [x] 10.1 code-reviewスキルを使用してコードレビューを実施
- [x] 10.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 10.3 `fvm flutter analyze`でリントを実行
- [x] 10.4 `fvm flutter test`でテストを実行
