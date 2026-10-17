## Why

前の change `piper-ios-build` で、iPad mini 実機でも Piper が日本語を合成できることを確かめた(中文の RTF 0.031、空きメモリ 3GiB 以上)。しかし iPad 版の読み上げは今も UI ごと隠れている。`platform-capabilities` が TTS を「iOS では非対応」の 1 つのフラグで扱っているためで、iPad の読者は小説を読み上げで聞けない。

一方、TTS の画面には iOS で動かないものも含まれる。Qwen3-TTS と Irodori-TTS のエンジン、参照音声の録音とドラッグ&ドロップ、MP3 書き出し(LAME)である。フラグをそのまま true にすると、これらが押すと失敗するボタンとして現れる。

## What Changes

- `platform-capabilities` で、TTS をエンジン単位で扱うようにする。iOS では Piper だけを利用可能とし、Qwen3-TTS・Irodori-TTS と MP3 書き出しは利用不可とする。TTS 全体の可否は「利用可能なエンジンが 1 つでもあるか」から導く。
- iPad で、読み上げの UI(本文の読み上げボタン、設定の「読み上げ」タブ、選択メニューの「読み上げ辞書に追加」、再生のショートカット)を表示する。
- エンジンの選択肢を、そのプラットフォームで使えるエンジンに限る。使えるエンジンが 1 つだけなら、エンジン選択の UI は出さない。保存済みのエンジン設定が使えないエンジン(既定値の Qwen3 を含む)を指していても、使えるエンジンとして扱う。保存値そのものは書き換えない。
- MP3 書き出しのボタンは、書き出しが使えるプラットフォームでだけ表示する(iPad では隠す)。
- 編集ダイアログの区間ごとの参照音声の選択は、参照音声を使うエンジン(Qwen3-TTS / Irodori-TTS)のときだけ表示する。Piper のときはデスクトップでも隠れる。
- モデルの読み込みに失敗した理由を、失敗の通知に載せる。今は理由がログに出るだけである。iOS で Piper のライブラリを同梱し忘れたビルドでは、ライブラリが無いことと、ビルドの手順を示す。
- 画面ロック中の再生(バックグラウンド再生)と、iPad での MP3 書き出しは対象外とする。

## Capabilities

### New Capabilities
(なし)

### Modified Capabilities
- `platform-capabilities`: TTS をエンジン単位(Piper / Qwen3-TTS / Irodori-TTS)と音声書き出しに分け、iOS では Piper だけを利用可能とする。TTS 全体の可否は、使えるエンジンの有無から導く。
- `tts-platform-availability`: iOS でも TTS を利用可能とする。何も使えないプラットフォームで画面を隠す仕組みはそのまま残す。
- `tts-engine-selection`: 選択肢をプラットフォームで使えるエンジンに限る。1 つだけなら選択 UI を出さない。保存値が使えないエンジンなら、使えるエンジンとして扱う。
- `tts-settings`: 「読み上げ」タブの先頭にエンジン選択が出るのは、使えるエンジンが複数あるときだけとする。
- `tts-audio-export`: 書き出しが使えないプラットフォームでは、書き出しボタンを表示せず、LAME も読み込まない。
- `tts-edit-screen`: 区間ごとの参照音声の選択は、参照音声を使うエンジンのときだけ表示する。
- `piper-tts-native-engine`: ネイティブライブラリを開けないとき、ライブラリ名とビルドの手順を示すエラーにする。
- `tts-streaming-pipeline`: モデルの読み込みに失敗した理由を、失敗の通知の理由として伝える。

## Impact

- **Dart**
  - `lib/shared/platform/platform_capabilities.dart` と、その provider
  - `lib/features/tts/providers/tts_availability_provider.dart`、`tts_settings_providers.dart`(使える範囲で解決したエンジン)
  - `lib/features/settings/presentation/settings_dialog.dart`(エンジン選択)
  - `lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart`(書き出しボタン、失敗の理由)
  - `lib/features/tts/presentation/tts_edit_dialog.dart` / `tts_edit_segment_row.dart`(参照音声の列)
  - `lib/features/tts/data/piper_native_bindings.dart`、`tts_session.dart`、`tts_streaming_controller.dart`(読み込み失敗の理由)
- **テスト**: 上記それぞれのユニットテストとウィジェットテスト。iOS の扱いは、capability の provider を上書きして確かめる。
- **iOS 実機**: 読み上げを手動で確認する。`flutter build ios --release` で入れ、モデルのダウンロード、再生・一時停止・停止、編集、辞書を試す。
- **ドキュメント**: `docs/ipad.md` の機能表と TTS の節、`.claude/CLAUDE.md` の iOS ビルドの説明を更新する。
- **デスクトップへの影響**: 編集ダイアログで Piper を選んでいるとき、参照音声の列が隠れる。読み込みに失敗したときの通知に理由が載るようになる。それ以外の動作は変わらない。
