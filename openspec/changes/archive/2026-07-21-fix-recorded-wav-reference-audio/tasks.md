## 1. audio.cpp: WAV パーサのテスト（テストファースト）

作業対象は submodule `third_party/audio.cpp`。作業ブランチを切ってから着手する。

- [x] 1.1 `tests/unittests/test_wav_reader.cpp` に、WAV バイト列をメモリ上で組み立てるヘルパを追加する（RIFF ヘッダ、任意サイズの `fmt`、任意の先行チャンク、`data`、末尾の任意バイト列を指定できること）
- [x] 1.2 EXTENSIBLE の失敗テストを追加する: `fmt` 40 バイト / `wFormatTag = 0xFFFE` / SubFormat GUID 先頭 `0x0001` / 16bit → PCM16 として復号されることを期待。現時点では失敗することを確認する
- [x] 1.3 EXTENSIBLE + IEEE float のテストを追加する: SubFormat GUID 先頭 `0x0003` / 32bit → float32 として復号されることを期待
- [x] 1.4 EXTENSIBLE + 拡張部欠損のテストを追加する: `fmt` 18 バイト / `wFormatTag = 0xFFFE` / 16bit → `bitsPerSample` からの推定で PCM16 として復号されることを期待
- [x] 1.5 EXTENSIBLE + 未知 SubFormat のテストを追加する: SubFormat GUID 先頭が `0x0001`/`0x0003` 以外 → 非対応として失敗することを期待
- [x] 1.6 先行チャンクのテストを追加する: `JUNK` と `FLLR` を `fmt` の前後に置いても正しく復号されることを期待
- [x] 1.7 末尾破損のテストを追加する: `data` の後に不正なチャンク ID と巨大なチャンクサイズを持つ余剰バイトを付けても、`data` のサンプルが正常に返ることを期待
- [x] 1.8 サイズクランプのテストを追加する: `data` の宣言サイズが残りバイト数を超えていても、残りバイト数までが読まれることを期待
- [x] 1.9 失敗し続けるべきケースのテストを追加する: `fmt` 欠損 / `data` 欠損 / `fmt` 取得前に範囲外シークが起きるファイル → いずれも失敗することを期待
- [x] 1.10 テストを実行し、1.2〜1.8 が失敗し 1.9 が成功することを確認する（現状の挙動を固定）

## 2. audio.cpp: WAV パーサの実装

- [x] 2.1 `src/framework/audio/wav_reader.cpp` の `fmt` 解析を拡張し、`wFormatTag == 0xFFFE` のとき拡張部の SubFormat GUID 先頭 2 バイトで `audio_format` を解決する
- [x] 2.2 `fmt` が拡張部を含む長さを持たない場合、`bitsPerSample` からの推定にフォールバックする（16/24 → PCM、32 → IEEE float）
- [x] 2.3 チャンク走査ループに「`fmt` と `data` の両方を取得済みか」の状態を導入する
- [x] 2.4 取得済み状態での走査失敗（不正なチャンクサイズ、範囲外シーク、チャンクヘッダ途中での終端）で走査を打ち切り、取得済みの結果で復号を継続するようにする。未取得状態での失敗は従来どおり例外を投げる
- [x] 2.5 チャンクサイズを入力の残りバイト数でクランプする
- [x] 2.6 テストを実行し、1.2〜1.9 のすべてが成功することを確認する
- [x] 2.7 既存の `test_wav_reader.cpp` / `test_audio_reader.cpp` の全テストが引き続き成功することを確認する（回帰確認）
- [x] 2.8 audio.cpp 側の変更をコミットする

## 3. ネイティブライブラリの再ビルドと実ファイル検証

- [x] 3.1 `scripts/build_irodori_macos.sh` で audio.cpp の FFI ライブラリを再ビルドし、`macos/Frameworks/libaudiocpp_ffi.dylib` を差し替える（`build_tts_macos.sh` は qwen3-tts.cpp 用で、このライブラリは作らない）
- [x] 3.2 NovelViewer 側の submodule 参照を更新する（submodule bump）
- [x] 3.3 macOS 実機で、録音機能で作成した WAV（例: `voices/test.wav`, `voices/endo1.wav`）を参照音声に指定して合成が成功することを確認する
- [x] 3.4 macOS 実機で、Windows 録音由来の WAV（例: `voices/test_rec.wav`）を参照音声に指定して合成が成功することを確認する
- [x] 3.5 従来動作していた MP3 / WAV（例: `voices/月ノ美兎.mp3`, `voices/tukino.wav`）で回帰がないことを確認する
- [x] 3.6 Windows で TTS DLL を再ビルドし、Windows 実機で録音 WAV による合成が成功することを確認する

## 4. Flutter: 合成失敗理由の伝播（テストファースト）

- [x] 4.1 `TtsSession` のテストを追加する: `SynthesisResultResponse` が `error` を伴って失敗したとき、`synthesize` が `null` を返しつつ直近の失敗理由がその文言を保持すること
- [x] 4.2 `TtsSession` のテストを追加する: `WorkerDiedResponse` を受信したとき、直近の失敗理由がその死亡理由を保持すること
- [x] 4.3 `TtsSession` のテストを追加する: 合成成功時に保持されている失敗理由がクリアされること
- [x] 4.4 `TtsSession` のテストを追加する: 既存の戻り値契約（成功時はレスポンス、失敗時は `null`）が変わらないこと
- [x] 4.5 テストを実行し、失敗することを確認する
- [x] 4.6 `lib/features/tts/data/tts_session.dart` に直近の失敗理由を保持する仕組みを実装し、4.1〜4.4 を成功させる
- [x] 4.7 既存の `TtsSession` / `TtsStreamingController` のテストが引き続き成功することを確認する（`null` 契約に依存する既存呼び出し元の回帰確認）

## 5. Flutter: 編集画面でのエラー表示

- [x] 5.1 合成失敗の見出し文言のキー（例: `ttsEdit_synthesisFailed`）を `lib/l10n/app_ja.arb`, `app_en.arb`, `app_zh.arb` に追加する
- [x] 5.2 `TtsEditController` のテストを追加する: 合成失敗時に、セッションが保持する失敗理由を含むメッセージが `onError` に渡されること
- [x] 5.3 `TtsEditController` のテストを追加する: 失敗理由が `null` のとき、見出しのみが `onError` に渡されること
- [x] 5.4 テストを実行し、失敗することを確認する
- [x] 5.5 `lib/features/tts/data/tts_edit_controller.dart:471` の固定文言 `'Synthesis failed'` を廃す。連結は `lib/features/tts/domain/tts_failure_message.dart` の純粋関数 `formatTtsFailureMessage` に切り出し、data 層の `onSynthesisFailed` は失敗理由のみを渡す（ローカライズは widget 層の責務のため）
- [x] 5.6 表示側 (`lib/features/tts/presentation/tts_edit_dialog.dart`) が長いメッセージを表示できることを確認する（必要ならスナックバーの表示時間・折り返しを調整する）
- [x] 5.7 テストを実行し、5.2〜5.3 が成功することを確認する

## 6. Flutter: ストリーミング再生でのエラー表示

- [x] 6.1 `TtsStreamingController` のテストを追加する: 合成失敗で `start()` が `failed` を返したとき、コントローラが失敗理由を保持していること（`TtsSession` が dispose された後でも参照できること）
- [x] 6.2 `TtsStreamingController` のテストを追加する: 正常完了・ユーザー停止では失敗理由が保持されないこと
- [x] 6.3 テストを実行し、失敗することを確認する
- [x] 6.4 `lib/features/tts/data/tts_streaming_controller.dart` の失敗判定箇所で、`_session.dispose()` より前にセッションから失敗理由を読み取り、コントローラのフィールドへ退避する実装を行う。`TtsStartOutcome` の列挙値は変更しない
- [x] 6.5 テストを実行し、6.1〜6.2 が成功することを確認する
- [x] 6.6 `lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart:216` のスナックバーを、`textViewer_ttsGenerationFailed` の見出しにコントローラの失敗理由を連結する形へ変更する。失敗理由が `null` のときは見出しのみ表示する
- [x] 6.7 `outcome == TtsStartOutcome.failed` 以外（`stopped` 等）では失敗スナックバーを出さない既存挙動が保たれていることを確認する
- [x] 6.8 既存の `TtsStreamingController` / `TtsControlsBar` のテストが引き続き成功することを確認する（回帰確認）

## 7. 実機での表示確認

- [x] 7.1 読み上げ編集画面で、読み込めない参照音声を指定して生成し、ローカライズされた見出しとネイティブの原因文言が表示されることを確認する
- [x] 7.2 ストリーミング再生で、読み込めない参照音声を設定して再生し、同様に見出しと原因文言が表示されることを確認する
- [x] 7.3 日本語・英語・中国語のロケールで見出しが正しく切り替わることを確認する

## 8. 上流への報告

- [x] 8.1 `llfbandit/record` に、Windows の `FillWavHeader` が SinkWriter のヘッダ長を 46 バイトと仮定しているために `data` チャンクの位置とサイズが不整合になる旨の issue を作成する（再現手順とヘッダのバイト列を添える）
- [x] 8.2 作成した issue の URL を本変更の記録に残す（https://github.com/llfbandit/record/issues/617）

## 9. 最終確認

- [x] 9.1 code-reviewスキルを使用してコードレビューを実施
- [x] 9.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 9.3 `fvm flutter analyze`でリントを実行
- [x] 9.4 `fvm flutter test`でテストを実行
