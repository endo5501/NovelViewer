## 1. フォーク側の準備

- [ ] 1.1 `third_party/audio.cpp` で上流を remote 登録し `ci/new-feature-mp3` を fetch する (`0xShug0/audio.cpp`)
- [ ] 1.2 作業ブランチ `feat/mp3-reference-audio` を作成する
- [ ] 1.3 `ENGINE_BUILD_TESTS=ON` でユニットテストがビルド・実行できることを確認する (ベースライン)

## 2. テスト先行 (TDD: 赤)

- [ ] 2.1 数 KB の MP3 フィクスチャを `tests/unittests/assets/` に追加する (非 ASCII 名のものを含む)
- [ ] 2.2 `tests/unittests/test_audio_reader.cpp` を作成し、`read_audio_f32` に対する以下を書く
  - MP3 を読むと sample_rate / channels / サンプル数が期待どおり
  - WAV を読むと従来と同一結果 (回帰)
  - 非 ASCII ファイル名の MP3 を読める
  - `.wav` 拡張子で中身が MP3 → `invalid WAV RIFF header` を含む例外 (D3 の非対称性を意図として固定)
  - 未対応フォーマット → `unsupported audio input format` とパスと `(supported: WAV, MP3)` を含む例外
  - 空ファイル / 破損 MP3 → パスを含む例外で失敗しクラッシュしない
- [ ] 2.3 `CMakeLists.txt` に `add_engine_unittest(audio_reader_test tests/unittests/test_audio_reader.cpp)` を追加する
- [ ] 2.4 テストが**失敗する**ことを確認する (`read_audio_f32` 未定義によるコンパイルエラーで可)
- [ ] 2.5 テストのみをコミットする

## 3. 上流コミットの取り込み (TDD: 緑)

- [ ] 3.1 `dd0aeff` "Add MP3 audio input support" をチェリーピックする
- [ ] 3.2 `app/server/runtime.cpp` の衝突を**上流側**の内容で解決する (`is_supported_audio_upload_filename` への改名、エラー文言の差し替え)
- [ ] 3.3 `CMakeLists.txt` / `app/cli/request.cpp` が自動マージされた内容で妥当か確認する (ソース列挙・include ディレクトリ・呼び出し差し替え)
- [ ] 3.4 `external/minimp3/LICENSE` (CC0) が取り込まれていることを確認する
- [ ] 3.5 2.2 のテストが全て通ることを確認する

## 4. シェイム層の差し替え

- [ ] 4.1 `src/audiocpp_c_api.cpp` の `read_audio_buffer()` を `engine::audio::read_audio_f32` 経由に変更し、include を `audio_reader.h` に差し替える
- [ ] 4.2 参照音声キャッシュ (`get_ref_audio_buffer` の path/size/mtime キー) が MP3 でも従来どおり機能することを確認する
- [ ] 4.3 `AUDIOCPP_BUILD_SHARED=ON` で `audiocpp_ffi` がビルドできることを確認する (MSVC の minimp3 警告でビルドが落ちないこと)
- [ ] 4.4 フォークの変更をコミットし、main へ反映して push する

## 5. NovelViewer 側の統合

- [ ] 5.1 `third_party/audio.cpp` の submodule 参照を更新してコミットする
- [ ] 5.2 `scripts/build_irodori_windows.bat` で再ビルドし、`audiocpp_ffi.dll` が更新されることを確認する
- [ ] 5.3 `voices/Ash.mp3` を参照音声に指定して合成が成功することを実機で確認する (E2E)
- [ ] 5.4 WAV 参照音声での合成が従来どおり動作することを確認する (回帰)
- [ ] 5.5 未対応フォーマット指定時に `app.log` へ診断可能なエラーが出ることを確認する
- [ ] 5.6 `scripts/build_irodori_macos.sh` でのビルド可否を確認する (可能な範囲で)

## 6. 最終確認

- [ ] 6.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 6.3 `fvm flutter analyze`でリントを実行
- [ ] 6.4 `fvm flutter test`でテストを実行
