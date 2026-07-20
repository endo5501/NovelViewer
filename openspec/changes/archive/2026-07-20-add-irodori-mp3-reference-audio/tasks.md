## 1. フォーク側の準備

- [x] 1.1 `third_party/audio.cpp` で上流を remote 登録し `ci/new-feature-mp3` を fetch する (`0xShug0/audio.cpp`)
- [x] 1.2 作業ブランチ `feat/mp3-reference-audio` を作成する
- [x] 1.3 `ENGINE_BUILD_TESTS=ON` でユニットテストがビルド・実行できることを確認する (ベースライン: `wav_reader_test passed`)

## 2. テスト先行 (TDD: 赤)

- [x] 2.1 数 KB の MP3 フィクスチャを `tests/unittests/assets/framework/audio/` に追加する (864 bytes。非 ASCII 名はテスト実行時に一時ディレクトリへコピーして再現する — 非 ASCII 名のファイルをリポジトリにコミットしない方が移植性が高いため)
- [x] 2.2 `tests/unittests/test_audio_reader.cpp` を作成し、`read_audio_f32` に対する以下を書く
  - MP3 を読むと sample_rate / channels / サンプル数が期待どおり
  - WAV を読むと従来と同一結果 (回帰)
  - 非 ASCII ファイル名の MP3 を読める
  - `.wav` 拡張子で中身が MP3 → `invalid WAV RIFF header` を含む例外 (D3 の非対称性を意図として固定)
  - 未対応フォーマット → `unsupported audio input format` とパスと `(supported: WAV, MP3)` を含む例外
  - 空ファイル / 破損 MP3 → パスを含む例外で失敗しクラッシュしない
- [x] 2.3 `CMakeLists.txt` に `add_engine_unittest(audio_reader_test tests/unittests/test_audio_reader.cpp)` を追加する
- [x] 2.4 テストが**失敗する**ことを確認する (`fatal error C1083: 'engine/framework/audio/audio_reader.h'`)
- [x] 2.5 テストのみをコミットする (`bd7ef95`)

## 3. 上流コミットの取り込み (TDD: 緑)

- [x] 3.1 `dd0aeff` "Add MP3 audio input support" をチェリーピックする (`7ba090b`)
- [x] 3.2 `app/server/runtime.cpp` の衝突を解決する。改名 (`is_supported_audio_upload_filename`) と文言差し替えの2ハンクは自動マージ済みで、実際の衝突は**フォーク側で既に削除済みの** `write_temp_upload` / `TempFileGuard` を上流が保持していた箇所だった。削除状態 (HEAD 側) を維持して解決
- [x] 3.3 `CMakeLists.txt` / `app/cli/request.cpp` が自動マージされた内容で妥当か確認する (`src/framework/audio/audio_reader.cpp` 追加・`external/minimp3` include・`read_audio_f32` 呼び出し)
- [x] 3.4 `external/minimp3/LICENSE` (CC0 1.0 Universal) が取り込まれていることを確認する
- [x] 3.5 2.2 のテストが全て通ることを確認する (`audio_reader_test passed` / `wav_reader_test passed`)

## 4. シェイム層の差し替え

- [x] 4.1 `src/audiocpp_c_api.cpp` の `read_audio_buffer()` を `engine::audio::read_audio_f32` 経由に変更し、include を `audio_reader.h` に差し替える (`a1869bc`)
- [x] 4.2 参照音声キャッシュ (`get_ref_audio_buffer` の path/size/mtime キー) が MP3 でも従来どおり機能することを確認する (キーはフォーマット非依存で変更不要)
- [x] 4.3 `AUDIOCPP_BUILD_SHARED=ON` で `audiocpp_ffi` がビルドできることを確認する (MSVC で警告・エラーなし)
- [x] 4.4 フォークの変更をコミットし、main へ反映して push する (`dcf2f71..790f7e9`)

## 5. NovelViewer 側の統合

- [x] 5.1 `third_party/audio.cpp` の submodule 参照を更新してコミットする
- [x] 5.2 `scripts/build_irodori_windows.bat` で再ビルドし、`audiocpp_ffi.dll` が更新されることを確認する
- [x] 5.3 MP3 参照音声で合成が成功することを実機で確認する (E2E: 非 ASCII 名の `月ノ美兎.mp3` で成功。リーダ再構成後の最新 DLL でも再確認済み)
- [x] 5.4 WAV 参照音声での合成が従来どおり動作することを確認する (回帰: OK)
- [x] 5.5 未対応フォーマット指定時に `app.log` へ診断可能なエラーが出ることを確認する (`voices/` の選択肢に出ないため UI からは指定不能。エラー文言はユニットテストで担保)
- [x] 5.6 `scripts/build_irodori_macos.sh` でのビルド可否を確認する → **本 change では未実施**。CI は Windows 専用 (`release.yml` は `windows-latest` のみ) で、開発環境にも mac が無いため検証できない。minimp3 はプラットフォーム非依存で上流の警告抑止 pragma も GCC/Clang 向けに入っているためリスクは低いと判断し、実機確認は別途 macOS 環境で実施する

## 5.5 エラーメッセージの UTF-8 化 (E2E で判明)

新しいリーダがエラーメッセージにパスを含めるようになった結果、Windows で `path.string()` が
ANSI コードページ (CP932) に変換され、Dart 側の `.toDartString()` が
`FormatException: Unexpected extension byte` を投げることが判明した (上流にも同じ問題がある)。

- [x] 5.5.1 非 ASCII 名のファイルで失敗させ、メッセージが UTF-8 であることを検証するテストを追加し、失敗を確認する
- [x] 5.5.2 `src/framework/audio/audio_reader.cpp` の `path.string()` を `display_path()` (u8string ベース) に変更する
- [x] 5.5.3 テストが通ることを確認し、コミットする (`790f7e9`)

## 5.7 レビュー指摘の反映

- [x] 5.7.1 メモリ上入力用の `read_audio_f32(std::string_view)` を追加し、`app/cli/request.cpp` のマルチパート経路を通す (チェリーピックの結果、サーバが `.mp3` アップロードを受理しつつ WAV として復号する不整合が残っていた。オーバーロード不在時は `string_view` が暗黙に `path` へ変換され、音声バイト列がファイル名として扱われる罠も同時に解消)
- [x] 5.7.2 `src/audiocpp_c_api.cpp` の初期化エラーのモデルパスを `u8string()` 化する (5.5 と同じ欠陥クラス)
- [x] 5.7.3 テストを追加・実行し、フォークへ push する (`4390072`)

## 6. 最終確認

- [x] 6.1 code-reviewスキルを使用してコードレビューを実施 (reuse/簡素化/効率/altitude の4観点。重複指摘を統合し `360d69e` で反映)
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施 (指摘3件。2件を 5.7 で修正、piper の再DL強制は別 change へ)
- [x] 6.3 `fvm flutter analyze`でリントを実行 (No issues found)
- [x] 6.4 `fvm flutter test`でテストを実行 (2421 passed)
