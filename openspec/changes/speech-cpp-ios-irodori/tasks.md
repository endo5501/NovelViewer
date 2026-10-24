# Tasks

各タスクは TDD で進める。手順は次のとおり。

1. テストを書く
2. 失敗を確認する
3. テストをコミットする
4. テストを変えずに実装する
5. テストが通ることを確認してコミットする

検証の欄にあるテストが、そのタスクの完了条件である。

## 1. プラットフォームの機能と Irodori の実行系

- [x] 1.1 `PlatformCapabilities` を次のように変える。
  - `IrodoriRuntime`（`audioCpp` / `speechCpp`）を同じファイルに定義する。
  - `irodoriTts` は全プラットフォームで true にする。
  - `irodoriRuntime` を足す（iOS は speechCpp、それ以外は audioCpp）。
  - `voiceRecording`、`voiceFileDragDrop`、`voicesFolderReveal` を足す（iOS は false）。
  - 確認: `platform-capabilities` の各シナリオを単体テストで確かめ、`fvm flutter test test/shared/platform/` が通る。
- [x] 1.2 次の 4 つのプロバイダを追加する。
  - Irodori の実行系
  - 録音
  - ドラッグ＆ドロップ
  - フォルダを開く

  あわせて、`tts_availability_provider.dart` と `platform_capabilities.dart` の、iOS は Piper だけと書いたコメントを直す。
  - 確認: iOS 相当の capabilities を上書きしたテストで `supportedTtsEnginesProvider` が `[piper, irodori]` を返し、エンジン選択の「iOS で `irodori` の保存値をそのまま使う」シナリオが通る。

## 2. Irodori の variant

- [x] 2.1 `IrodoriModelVariant` を次のように変える。
  - `v4.1-mf` を追加する。
  - 欄を足す: `runtime`、`acceptsGuidance`、`downloadUrl`、`sha256`。
  - 既存の `v3` / `v4` の値は変えない。`downloadUrl` は今の `_baseUrl` から組み立てたものと同じにする。
  - 確認: variant のテーブルの値（ファイル名、サイズ、SHA-256、caption、尺補正の要否、ガイダンス）を確かめる単体テストが通る。
- [ ] 2.2 プラットフォームに応じて variant を扱うプロバイダを作る。
  - 選択肢のプロバイダを追加する。
  - `irodoriModelVariantProvider` は、保存値を書き換えずに解決する。
  - 確認: `irodori-model-variant` の次のシナリオのテストが通る。
    - 既定値（デスクトップ）
    - iOS の既定値
    - iOS で動かせない保存値
    - 選択肢
    - 永続化
- [ ] 2.3 `IrodoriEngineConfig` に、受け付ける参照音声の拡張子を持たせる（speechCpp は `{'.wav'}`）。保存値の拡張子が受け付けないものなら、`refWavPath` を null に解決する。
  - 確認: `voice-reference-library` の次のシナリオが `tts_engine_config` のテストで通る。
    - 保存された MP3 を iOS で選んでいる場合
    - デスクトップでの同じ選択
- [ ] 2.4 セグメントごとに保存した参照音声にも、2.3 と同じ判定を当てる。対象は、streaming controller と edit controller で `resolveRefWavPath` を呼ぶ手前である。
  - 確認: 「セグメントの MP3 参照音声を iOS で使う場合」のシナリオが、両 controller のテストで通る。

## 3. モデルのダウンロード

- [ ] 3.1 `IrodoriModelDownloadService` を次のように変える。
  - `variant.downloadUrl` から取得する。
  - 完了したら、SHA-256 をストリームで検証する。
  - 一致しなければファイルを削除し、`IrodoriDownloadHashMismatchException` を投げる。
  - `isModelDownloaded` はサイズだけで判定する。
  - 確認: `irodori-tts-model-download` の次のシナリオを、フェイクの HTTP クライアントで確かめるテストが通る。
    - 固定したリビジョンの URL
    - 完了
    - ハッシュ不一致
    - サイズ不一致
- [ ] 3.2 iOS で Irodori の設定画面を開くと、MF のダウンロードの UI が出ることを確かめる。既存のダウンロードプロバイダは、選択中の variant をそのまま使えるはずだが、使えない場合だけ直す。
  - 確認: ウィジェットテストで、iOS 相当の上書きのもと、ダウンロードボタンと MF の名前が表示される。

## 4. speech.cpp のバインディング

- [ ] 4.1 バインディングを次のように変える。
  - `speech_request_set_progress` を追加する。
  - 合成に「停止を求めるか」の関数を渡せるようにする。進捗コールバックと音声コールバックは、どちらも `exceptionalReturn` を 1 にし、その関数が true なら 1 を返す。
  - `SpeechCppRequest.cancelAt` と `address` を削除する。
  - 確認: `speech_cpp_native_bindings_test.dart` に次のテストを足し、通る。
    - コールバックで停止を返すと、中断の結果になる
    - callbackError がある場合はエラーと区別される
- [ ] 4.2 `scripts/test/verify_speech_ios.sh` の `C_API_SYMBOLS` を更新する。
  - `speech_request_set_progress` を加える。
  - `speech_request_cancel` は、使わなくなるので外す。
  - 確認: 4.6 で作り直した xcframework に対してスクリプトが全件通る。
- [ ] 4.3 スパイクの計測テスト（`integration_test/speech_cpp_ios_test.dart`）の中断を、別の isolate からフラグを立てる方式に書き換える。
  - 確認: `fvm flutter analyze` が通り、Simulator で既存のバージョン確認だけが通る（`flutter drive -d <simulator>`）。
  - 実機での実行は、データが消えるので見送る（design D3）。
- [ ] 4.4 `scripts/build_speech_ios.sh` を変える。
  - ヘッダの「アプリ本体はまだ使わない」を直す。
  - 処理の内容は変えない。
  - 確認: `bash -n` が通り、差分は説明の部分だけである。
- [ ] 4.5 `.claude/CLAUDE.md` の開発コマンドの説明を、アプリが speech.cpp の framework を使う前提に直す。
  - 確認: 差分を目で確かめる。
- [ ] 4.6 `scripts/build_speech_ios.sh` で xcframework を作り直す。
  - 確認: `scripts/test/verify_speech_ios.sh` が全件通る。

## 5. 中断のハンドル

- [ ] 5.1 `TtsAbortHandleFactory` のキーを、`TtsEngineType` からネイティブの系統（`qwen3` / `audioCpp` / `speechCpp`）に変える。挙動は変えない。
  - 確認: 既存の `tts_isolate` と `tts_session` のテストを新しいキーに合わせても、すべて通る（リファクタリングとして独立したコミットにする）。
- [ ] 5.2 speechCpp の中断ハンドルを追加する。
  - `calloc<Int32>` で確保する 1 ワードで、`abort()` は 1 を書き、worker が終わってから解放する。
  - 中断の取りこぼしと atomic が無いことは、コメントに書く。
  - 確認: 次の単体テストが通る。
    - spawn のときに確保される
    - アドレスが読み込み直しをまたいで変わらない
    - dispose の後に解放される
- [ ] 5.3 `TtsSession` が、config の実行系から中断ハンドルの系統を選んで `LoadModelMessage` に渡すようにする。
  - 確認: speechCpp の variant で読み込むと、speechCpp のハンドルのアドレスが渡ることをテストで確かめる。

## 6. speech.cpp の Irodori エンジン

- [ ] 6.1 長い文の分割関数を作る。
  - 基準の長さ L は引数で受け取り、初期値は 80 字とする。
  - 確認: 単体テストで次を確かめる。
    - L 以下はそのまま
    - L 以下で最も後ろの読点で切る
    - L より前に読点が無いときは、L より後ろの最初の読点で切る
    - 読点の無い残りはそのまま
    - 部分をつなぐと元に戻る
- [ ] 6.2 つなぎ目の無音を補う関数を作る。
  - 閾値は −40 dBFS、最小の無音は引数で受け取り、初期値は 0.3 秒とする。
  - 確認: 単体テストで次を確かめる。
    - 無音が足りないときは不足分の 0 が入る
    - 足りているときは何も足さない
- [ ] 6.3 `SpeechCppIrodoriEngine` を作る。
  - 形は `loadModel`、`synthesize`、`abort`、`resetAbort`、`dispose`、`isLoaded` で、ネイティブの部分は注入できるようにする。
  - 確認: フェイクの speech.cpp を使い、`irodori-speech-cpp-engine` の次のシナリオのテストが通る。
    - 参照音声を一度だけ登録する
    - 参照音声なし
    - 読めない参照音声
    - キャプションあり / なし
    - 長いキャプションの拒否
    - 短い文 / 長い文
    - 読点の無い部分の拒否
    - 中断
    - 分割の途中での中断
    - 中断の後の合成
    - ガイダンスの値を使わない
    - 部分どうしで同じ seed
- [ ] 6.4 worker を変える。
  - `LoadModelMessage` に `irodoriRuntime` を足す。
  - worker は、実行系に応じて `IrodoriTtsEngine` か `SpeechCppIrodoriEngine` を開く。2 つのエンジンが共有するのは小さなインターフェースだけにする。
  - `TtsSession` は、speechCpp のとき GGUF のファイルパスを渡し、`IrodoriModelSpecInstaller` を呼ばない。
  - 確認: `tts_session` のテストで次を確かめる。
    - speechCpp の variant では installer が呼ばれず、GGUF のパスと実行系が送られる
    - audio.cpp の variant はこれまでどおり

## 7. 設定画面

- [ ] 7.1 Irodori の設定画面を変える。
  - `acceptsGuidance` が false の variant では、ガイダンスと step 数の UI を出さない。
  - 選択肢が 1 つのときは、ドロップダウンの代わりに名前を表示する。
  - 文言は ja / en / zh で追加する。
  - 確認: `irodori-model-variant` の次のシナリオが、ウィジェットテストで通る。
    - MF ではガイダンスの設定を表示しない
    - 選択肢が 1 つのときは名前を表示する
    - 既存の v3 / v4 のシナリオ
- [ ] 7.2 `VoiceReferenceSection` を変える。
  - ドラッグ＆ドロップ、録音ボタン、フォルダを開くボタンを、それぞれのプロバイダで出し分ける。
  - ファイルを選ぶボタンを足す（`file_picker` を注入できるようにする）。
  - 一覧の拡張子は、選択中の config から決める。
  - 文言は ja / en / zh で追加する。
  - 確認: ウィジェットテストで次のシナリオが通る。
    - `voice-recording`: iOS では録音ボタンが無い
    - `voice-file-drag-drop`: iOS ではドロップ先を登録しない
    - `voice-reference-library`: iOS ではフォルダのボタンが無い、ファイルを選んで追加・重複・キャンセル、speech.cpp では WAV だけを一覧に出す
    - デスクトップではこれまでどおり表示される
- [ ] 7.3 `VoiceReferenceService.listVoiceFiles` が拡張子で絞れるようにする。引数を省略したときは、これまでどおり `.wav` と `.mp3` を対象にする。
  - 確認: `voice_reference_service` のテストで、絞り込みと既定値を確かめる。

## 8. ドキュメント

- [ ] 8.1 `docs/ipad.md` を書き直す。
  - 「提供する機能・しない機能」と「読み上げ」の節: Irodori（MF F16）が使えること、参照音声は Files アプリかファイル選択で WAV を追加すること、録音できないこと、再生のたびに読み込みを待つこと。
  - 第 5 節と第 6 節: speech.cpp の framework は、Irodori を含むアプリのビルドでは `ios/Frameworks/` に置いたままにする。ビルド前に取り除く手順は削除する。
  - `flutter drive` はアプリを消し、`devicectl device install app` は上書きでデータを残すこと。
  - 確認: `ios-build-target` のドキュメントの各シナリオを満たしていることを、読み合わせで確かめる。

## 9. 実機での確認

- [ ] 9.1 `scripts/build_app.sh ios --release` でビルドし、`Runner.app` に `speech_cpp.framework` と Piper の framework が入っていることを確かめる。
- [ ] 9.2 ユーザーにインストールしてよいか確認してから、`xcrun devicectl device install app --device 00008130-000A0DD42181001C <Runner.app>` で上書きインストールする。
  - バックアップは、2026-10-24 に取った `~/Backups/NovelViewer-iPad-20261024/` を使う（取り直さないことはユーザーが判断した）。
  - 確認: 起動してライブラリとモデルが残っていることを最初に確かめる。消えていたら作業を止めて、バックアップから戻す。
- [ ] 9.3 iPad の設定で Irodori を選び、MF F16 をダウンロードする。
  - 確認: ダウンロードが完了して検証を通り、ダウンロード済みと表示される。
- [ ] 9.4 Files アプリかファイル選択で WAV の参照音声を追加し、キャプションを付けたセグメントを含む 1 話を読み上げる。
  - 確認: 次の 3 つを満たす。
    - 最後まで読み上がる
    - 中断が 1 秒程度で効く
    - 長い文のつなぎ目が聞いて自然である（ユーザーの試聴）
- [ ] 9.5 実際のアプリでのメモリと待ち時間を測り、design.md に書き戻す。
  - メモリ: ピーク値と空きの最小値
  - 待ち時間: モデルの読み込みと、最初の音が出るまで
  - 確認: 空きの最小値が 512 MiB 以上であること。下回ったら、Q8_0 への切り替えをユーザーと相談する。
- [ ] 9.6 試聴の結果から、基準の長さ L とつなぎ目の無音の値を決める。値を変えたときは、6.1 と 6.2 の初期値と design.md を更新する。
  - 確認: 決めた値が design の Open Questions から Decisions に移っている。

## 10. 最終確認

- [ ] 10.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 10.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 10.3 `fvm dart format lib test`でフォーマットを実行
- [ ] 10.4 `fvm flutter analyze`でリントを実行
- [ ] 10.5 `fvm flutter test`でテストを実行
