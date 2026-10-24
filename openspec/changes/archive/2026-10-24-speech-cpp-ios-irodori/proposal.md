# Proposal

## Why

iPad でも Irodori-TTS で読み上げたい。audio.cpp の v3 f16 はアプリのメモリ上限（約 3.4 GiB）を超えたため、2026-09-15 に中断した（`irodori-ios-build`）。その後、speech.cpp の Irodori-TTS v4.1 Small MF F16 を試した。2026-10-24 の実機スパイク（`speech-cpp-ios-spike`）では、iPad mini（A17 Pro、8GB）で次の結果になった。

- 空きメモリの最小値: 1,349 MiB
- 125 字の文の RTF: 0.44
- 中断: 動作した
- 試聴: 許容範囲

アプリの読み上げに組み込める見込みが立ったので、この結果をアプリ本体につなぐ。

## What Changes

- iOS で Irodori-TTS エンジンを使えるようにする。エンジンの種類は `irodori` のまま変えず、実行系をプラットフォームごとに切り替える。
  - デスクトップ: これまでどおり audio.cpp
  - iOS: speech.cpp
- Irodori のモデル variant に `v4.1 Small MF (F16)` を追加する。variant ごとに実行系を持たせ、プラットフォームが動かせる variant だけを選択肢に出す。iOS の既定値はこの variant とする。保存済みの variant がそのプラットフォームで動かせないときは、保存値を書き換えずに、動かせる最初の variant を使う。
- speech.cpp を使う Irodori エンジンを worker isolate に追加する。
  - 参照音声: WAV を speech.cpp の voice として登録する。モデルを読み込んでいる間は、同じファイルを一度だけ登録して使い回す。
  - キャプション: セグメントのメモを `instructions` として渡す。
  - 長い文: エンジンの中で読点の位置で分けて合成し、音声をつなぐ。
  - 中断: プロセス内に置いた中断フラグを、speech.cpp の進捗コールバックと音声コールバックが読む方式で行う。
- MF のモデルは、sakasegawa の Hugging Face リポジトリからリビジョンを固定してダウンロードし、サイズと SHA-256 で検証する。既存の variant の取得元とサイズ検証は変えない。
- iOS では、Irodori の設定画面を次のように変える。
  - ガイダンスの 2 つのスケールと step 数を表示しない。MF はこれらを受け付けないため。
  - 参照音声の画面を表示する。
- 参照音声の画面に、ファイルを選んで追加するボタンを置く（全プラットフォーム）。マイク録音、ドラッグ＆ドロップ、フォルダを開くボタンは、プラットフォームが対応するときだけ表示する（iOS では表示しない）。iOS で Irodori を使うときは、一覧に `.wav` だけを出す。
- iOS ビルドに speech_cpp.xcframework を同梱する。これまでは計測専用で、普段のビルドの前に取り除く手順だった。今後は読み上げに必要なものとして扱い、ドキュメントを改める。
- 対象外: モデルを常駐させるかどうか（再生のたびに読み込む今の作りのまま。別の change で扱う）、マイク録音への対応、MP3 の参照音声を WAV に変換すること、バックグラウンド再生、デスクトップへの MF の導入。

## Capabilities

### New Capabilities

- `irodori-speech-cpp-engine`: speech.cpp で Irodori MF を動かすエンジン。次の振る舞いを定める。
  - モデルの読み込み
  - 参照音声の登録とキャッシュ
  - キャプションを `instructions` として渡すこと
  - 長い文を読点の位置で分けて合成し、つなぐこと
  - 中断フラグによる中断
  - worker isolate が variant の実行系に応じてエンジンを選ぶこと

### Modified Capabilities

- `platform-capabilities`: iOS でも Irodori-TTS を使えるとする。Irodori の実行系をプラットフォームが答えるようにする。参照音声の録音、ドラッグ＆ドロップ、フォルダを開く機能を、それぞれ独立した機能として名前を付ける。
- `tts-engine-selection`: iOS で保存済みの `irodori` を、そのまま使えるエンジンとして扱う。
- `irodori-model-variant`: MF variant を追加する。variant ごとの実行系と、ガイダンス設定を受け付けるかどうかを定める。プラットフォームに応じて、選択肢・既定値・解決方法を決める。iOS では設定画面を出し分ける。
- `irodori-tts-model-download`: MF variant について、取得元をリビジョン固定とし、SHA-256 でも検証する。
- `speech-cpp-native-bindings`: 中断の方式を、リクエストを指定する中断からコールバックによる中断に改める。進捗コールバックを使い、音声の登録をバインディングに含める。

`speech-cpp-ios-build` の要件は変えない。公開シンボルの要件は「バインディングが参照する関数」と書かれているので、進捗コールバックの関数が増えても文言はそのまま当てはまる。検証スクリプトの一覧だけを更新する。
- `ios-build-target`: speech.cpp の framework は読み上げ（Irodori）に必要なものになり、ビルド前に取り除く手順はなくなる。そのことをドキュメントに書く。
- `voice-reference-library`: ファイルを選んで追加できるようにする。フォルダを開く機能はプラットフォームが対応するときだけにする。一覧に出す拡張子をエンジンに応じて絞る。
- `voice-file-drag-drop`: プラットフォームが対応するときだけドロップを受け付ける。
- `voice-recording`: プラットフォームが対応するときだけ録音ボタンを表示する。

## Impact

- Dart のコード:
  - `lib/shared/platform/platform_capabilities.dart`
  - `lib/features/tts/data/` 配下: `irodori_model_variant.dart`、`irodori_model_download_service.dart`、`speech_cpp_native_bindings.dart`、新規の speech.cpp 版 Irodori エンジン、`tts_isolate.dart`、`voice_reference_service.dart`
  - `lib/features/tts/domain/tts_engine_config.dart`
  - `lib/features/tts/providers/` 配下: `tts_settings_providers.dart`、`tts_availability_provider.dart`、`irodori_model_download_providers.dart`
  - `lib/features/settings/presentation/` 配下: `settings_dialog.dart`、`sections/irodori_settings_section.dart`、`sections/voice_reference_section.dart`
  - l10n（ja / en / zh）
- ネイティブとビルド: `scripts/test/verify_speech_ios.sh`（シンボル一覧）、`scripts/build_speech_ios.sh` のヘッダの説明。`ios/Frameworks/speech_cpp.xcframework` は Git 管理外のまま、iOS ビルドに同梱する。
- ドキュメント: `docs/ipad.md` の読み上げとビルドの節、`.claude/CLAUDE.md` の開発コマンド。
- 依存: 新しいパッケージは追加しない。ファイルの選択には既存の `file_picker` を使う。
- 実機:
  - iPad mini（A17 Pro）に release ビルドを上書きでインストールして確認する。インストールには `xcrun devicectl device install app` を使い、データが消える `flutter drive` は使わない。
  - バックアップは 2026-10-24 に取得した `~/Backups/NovelViewer-iPad-20261024/` をそのまま使う。取り直さないことはユーザーが判断した。
- ブランチ: `feat/speech-cpp-ios-spike` の上で続ける。main へは組み込みが成功してからマージする。
