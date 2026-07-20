## Why

アプリ内の録音機能で作成した WAV を参照音声に指定すると、TTS 合成が必ず失敗する。ネットからダウンロードした MP3 / WAV は問題なく動作するため、録音機能そのものが実質的に使えない状態になっている。

調査の結果、原因は macOS と Windows で **それぞれ別のもの** であり、いずれも `audio.cpp` の WAV パーサ (`src/framework/audio/wav_reader.cpp`) が「実際には読める音声データ」を拒否していることが分かった。

- **macOS**: AVAudioRecorder が出力する WAV は `fmt` チャンクの `wFormatTag` が `WAVE_FORMAT_EXTENSIBLE (0xFFFE)` になる。中身は普通の PCM16 だが、パーサは `wFormatTag` を素の値でしか判定しないため `unsupported WAV encoding` で例外を投げる。
- **Windows**: `record_windows` パッケージが破損した WAV を生成する。`data` チャンクが「offset 46 から 155458 バイト」と宣言しているのに実データは offset 82 から始まっており、末尾に 36 バイトの余剰が残る。パーサは `data` を読み終えた後もファイル末尾まで走査を続けるため、余剰バイトを不正なチャンクヘッダとして解釈し、範囲外シークで例外を投げる。**音声データは既に正常に読めているのに、その結果を捨てている。**

さらに、どちらの失敗も UI には `Synthesis failed` としか表示されない。ネイティブ層は `unsupported WAV encoding (need PCM16, PCM24, or float32)` / `failed to seek inside WAV file` という具体的な文言を返しているが、`TtsSession.synthesize` が `null` を返す際に破棄されている。この情報欠落が、上記2つの別々の原因を「同じ不具合」に見せ、原因究明を大きく遅らせた。

## What Changes

### audio.cpp (submodule) — WAV パーサの堅牢化

- `fmt` チャンクの `wFormatTag` が `0xFFFE` の場合、拡張部の SubFormat GUID 先頭 2 バイトを実フォーマットとして解決する (`0x0001` → PCM / `0x0003` → IEEE float)。GUID が欠損している壊れたファイル向けに `bitsPerSample` からの推定フォールバックを持つ。
- `fmt` と `data` の両方を取得した後のチャンク走査を best-effort に格下げする。走査中の破損（不正なチャンクサイズ、範囲外シーク）で、成功済みのパース結果を破棄しない。
- チャンクサイズが残りバイト数を超える場合はクランプする。
- パースが不完全なまま壊れているファイル、および真に非対応のフォーマットは、従来どおり明示的に例外を投げる（寛容化の対象を限定する）。
- 回帰テストはバイト列をテストコード内で組み立てて追加する（バイナリ資産を追加しない）。

### NovelViewer (Flutter) — 合成失敗の原因表示

- `TtsSession.synthesize` が失敗した際、ネイティブ層のエラー文言を呼び出し元へ伝播させる（現在はログに出すだけで破棄している）。
- **BREAKING**（仕様上の方針転換）既存要件の「失敗通知にネイティブのエラー文字列を露出させない」という制限を撤回する。現状この制限は目的を果たしておらず、ストリーミング再生では原因不明のローカライズ文言が、読み上げ編集画面ではローカライズすらされていない `Synthesis failed` が出るだけになっている。両画面を「ローカライズされた見出し + ネイティブの原因文言」に統一する。
- ストリーミング再生 (`TtsControlsBar`): `TtsStreamingController` が失敗理由を保持し、ローカライズ済みの見出しに連結して表示する。
- 読み上げ編集画面 (`TtsEditController`): 固定文言 `'Synthesis failed'` を廃し、ローカライズされた見出しと原因を提示する。

### スコープ外

- `record_windows` が破損した WAV を生成する問題そのものは上流パッケージ（llfbandit/record, 現行最新 2.2.2 で未修正）の不具合であり、本変更では修正しない。別途 issue を報告する。本変更のパーサ堅牢化により**ファイルは読めるようになる**が、余剰 36 バイトが音として解釈されるため Windows 録音の冒頭に約 1.1ms のクリックが残る。声質クローンの参照としては影響が無視できる範囲と判断し、実害が観測された時点で対症療法を検討する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `tts-native-engine`: 参照音声として受け付ける WAV の範囲を拡張する。`WAVE_FORMAT_EXTENSIBLE` を SubFormat GUID 経由で解決すること、および `fmt`/`data` 取得後の末尾破損を許容することを要件に加える。
- `tts-streaming-pipeline`: 合成失敗時に `TtsSession.synthesize` が原因文言を呼び出し元へ伝えることを要件に加える。あわせて「失敗通知にネイティブのエラー文字列を露出させない」という既存の制限を撤回し、ローカライズされた見出しに原因文言を連結して表示することを要件とする。
- `tts-edit-screen`: 合成失敗時に固定文言ではなく、ローカライズされた見出しと具体的な原因を表示することを要件に加える。

## Impact

**コード**

- `third_party/audio.cpp/src/framework/audio/wav_reader.cpp` — パーサ本体
- `third_party/audio.cpp/tests/unittests/test_wav_reader.cpp` — 回帰テスト
- `lib/features/tts/data/tts_session.dart` — エラー文言の保持
- `lib/features/tts/data/tts_streaming_controller.dart` — 失敗理由の退避（session の dispose 前）
- `lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart` — ストリーミング再生の失敗通知
- `lib/features/tts/data/tts_edit_controller.dart` — 編集画面のエラー生成
- `lib/features/tts/presentation/tts_edit_dialog.dart` — 表示側（必要に応じて）
- `lib/l10n/app_ja.arb` / `app_en.arb` / `app_zh.arb` — 編集画面の失敗見出しキーの追加

**ビルド成果物**

- `macos/Frameworks/libaudiocpp_ffi.dylib` — audio.cpp 修正後に `scripts/build_tts_macos.sh` で再ビルドし差し替えが必要
- Windows 側の DLL も同様に再ビルドが必要

**依存**

- `third_party/audio.cpp` submodule のコミット更新（submodule bump）を伴う

**外部**

- llfbandit/record への上流報告（本変更のブロッカーにはしない）
