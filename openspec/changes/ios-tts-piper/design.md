## Context

動機と範囲は proposal.md を参照。ここでは方式を左右する現状だけを記す。

- **機能の可否**
  - `PlatformCapabilities.forPlatform(isIOS:, isMacOS:)` が唯一の判定元で、`textToSpeech = !isIOS` としている。
  - 各機能は、その値から作る真偽値の provider で読まれる。TTS では `ttsSupportedProvider` を使う。
  - これを読むのは、本文の読み上げボタン、設定ダイアログ、選択メニュー、ショートカット、ホーム画面の 7 ファイル。
- **エンジンの選択**
  - `ttsEngineTypeProvider`(`TtsEngineTypeNotifier`)は保存値をそのまま返す。既定値は `qwen3`。
  - これを読むのは、設定の `_EngineSelector`、`TtsControlsBar`、`TtsEditDialog`、`ttsModelReadinessProvider`、`TtsEngineConfig.resolveFromRef`。
- **MP3 書き出し**: `TtsControlsBar._exportButtonOrProgress` が、エンジンやプラットフォームを見ずにボタンを出す。押すと LAME FFI(`lame_enc_bindings.dart`)と `FilePicker.saveFile` を使う。
- **編集ダイアログ**: `TtsEditSegmentRow` は、エンジンに関係なく参照音声のドロップダウンを出す。候補は `voiceReferenceServiceProvider` の `listVoiceFiles()` である。
- **読み込み失敗の伝わり方**
  - ワーカー isolate は `PiperTtsEngine.open()` の例外を `ModelLoadedResponse(success: false, error:)` で返す。
  - `TtsSession.ensureModelLoaded` は、その理由をログに出して `false` を返すだけで、理由を保持しない。
  - `TtsStreamingController` は、読み込み失敗では `_lastFailureReason` を設定しない(合成失敗では `lastSynthesisError` を設定する)。
  - そのため通知には「生成に失敗しました」の見出ししか出ない。
- **iOS のライブラリ**: `piper_plus.framework` は Git 管理外で、`scripts/build_piper_ios.sh` でビルドする(`piper-ios-build`)。無い場合、`DynamicLibrary.open` が `ArgumentError`(dlopen のエラー)を投げる。
- **再生**: just_audio が `setFilePath` で WAV を再生する。iOS のオーディオセッションは設定していない(just_audio の既定)。

## Goals / Non-Goals

**Goals:**
- iPad で Piper による読み上げを、生成・再生・一時停止・停止・編集・削除・読み上げ辞書まで、デスクトップと同じ画面で使えるようにする。
- iOS で動かないもの(Qwen3-TTS、Irodori-TTS、参照音声、録音、MP3 書き出し)を、押すと失敗するボタンとして見せない。
- ライブラリを同梱し忘れたビルドで、原因が通知から分かるようにする。

**Non-Goals:**
- 画面ロック中の再生(`UIBackgroundModes: audio`、ロック画面の操作)。
- iPad での MP3 書き出し(LAME の iOS 向けビルド、共有シートでの保存)。
- ライブラリが無いことを起動時に検出して、読み上げを隠すこと(proposal の判断 3.A)。
- 狭い画面向けに、読み上げボタンや編集ダイアログの配置を変えること(実機の確認で問題が見つかった場合は、別の change で扱う)。

## Decisions

### D1: 機能モデルにエンジンごとの可否と音声書き出しを加え、TTS 全体はそこから導く

`PlatformCapabilities` に `piperTts` / `qwen3Tts` / `irodoriTts` / `ttsAudioExport` を加える。`textToSpeech` は、フィールドではなく「どれかのエンジンが使える」という getter にする。iOS では `piperTts` だけが true になり、ほかのプラットフォームではすべて true になる(Linux も含む。従来の `textToSpeech` の答えと同じ)。

- 機能モデルは `lib/shared/` にあり、`features/tts` の `TtsEngineType` には依存させない。エンジンを列挙型で持たず真偽値を並べるのは、このためである。
- `features/tts` 側で、機能モデルから「使えるエンジンの一覧」(`supportedTtsEnginesProvider`、表示順は Qwen3-TTS → Piper → Irodori-TTS)と、`ttsAudioExportSupportedProvider` を作る。各画面はこれらを読む。
- `ttsSupportedProvider` は名前も型も変えず、`textToSpeech` を読み続ける。既存の 7 か所は変更しない。

代替案: 機能モデルに `Set<TtsEngineType>` を持たせる。shared から feature への依存が生まれ、機能モデルを純粋なまま保つという設計に反する。

### D2: 使えるエンジンは `ttsEngineTypeProvider` の 1 か所で決める

`TtsEngineTypeNotifier.build()` が、保存値とプラットフォームで使えるエンジンを照らし合わせる。保存値が使えないエンジンなら、Piper → Qwen3-TTS → Irodori-TTS の順で最初に使えるものを返す。`setEngineType` は従来どおり保存する。保存値は、解決のために書き換えない。

- エンジンを読む 5 か所は、すべてこの provider を経由している。ここで決めれば、各所に条件を書かずに済み、書き漏らしも起きない。
- フォールバックの先頭を Piper にするのは、Piper だけがすべてのプラットフォームで使えるからである。
- 保存値を書き換えないのは、設定を共有・復元した場合に、デスクトップでの選択を iPad が上書きしないためである。

代替案: 使う側ごとに「使えなければ Piper」と書く。5 か所に同じ条件が散らばり、1 か所でも漏れると、iOS で Qwen3 を読み込もうとして失敗する。

### D3: エンジン選択は使えるものだけを並べ、1 つしかなければ出さない

`_EngineSelector` は `supportedTtsEnginesProvider` から選択肢を作り、要素が 1 つなら `SizedBox.shrink()` を返す。設定タブは、従来どおり `ttsEngineTypeProvider`(D2 で解決済み)に応じた設定を表示する。iOS では Piper の設定(モデルのダウンロードと合成パラメータ)だけが並び、参照音声の欄は自然に出なくなる。

### D4: 書き出しボタンは `ttsAudioExportSupportedProvider` が false なら作らない

`TtsControlsBar` の書き出しボタン(と、その進捗表示)を、`ttsAudioExportSupportedProvider` が false のときはウィジェットツリーに入れない。押されなければ LAME FFI は読み込まれない(読み込みは書き出しの処理の中だけで行われる)。

### D5: 参照音声の列は、参照音声を使うエンジンのときだけ出す

`TtsEngineType` に `usesReferenceVoice` を加える(qwen3 と irodori が true、piper が false)。`TtsEditDialog` は、`ttsEngineTypeProvider` の値で列を出すかどうかを決めて `TtsEditSegmentRow` に渡す。列を出さないときは、参照音声の一覧(`_loadVoiceFiles`)も読み込まない。区間に保存済みの `ref_wav_path` は変更しない。

- 判定をエンジン側の性質として持たせ、`TtsEngineConfig.synthesisFallbackRefWavPath`(Piper では常に null)と同じ意味にそろえる。

### D6: ライブラリを開けないときは、名前と入手方法を示す例外にする

`PiperNativeBindings.open()` で `DynamicLibrary.open` が投げる `ArgumentError` を捕まえ、`TtsEngineException` にする。メッセージには次の 3 つを入れる。

- 開けなかったライブラリ名(`libraryNameFor` の値)
- そのプラットフォームのビルド手順(iOS: `scripts/build_piper_ios.sh`、macOS: `scripts/build_piper_macos.sh`、Windows: `scripts\build_piper_windows.bat`)
- 元のエラー文言(末尾に付ける)

手順の文字列は `libraryNameFor` と同じく OS 名を引数に取る純粋関数にし、ホストのテストで全 OS 分を確かめられるようにする。

### D7: 読み込み失敗の理由を、セッションからコントローラ、通知へ渡す

- `TtsSession` に `lastModelLoadError` を加える。`ensureModelLoaded` の開始時に消し、`ModelLoadedResponse` の `error` と、ワーカーが落ちたときの理由を入れる。
- `TtsStreamingController` は、読み込み失敗で `failed` にするとき、`_lastFailureReason = _session.lastModelLoadError` とする。
- 通知の組み立て(`TtsControlsBar` の `buildTtsFailureReport`)は、すでに `controller.lastFailureReason` を cause として使っているので、変えなくてよい。
- 編集ダイアログの単体生成も同じセッションを使う。読み込みに失敗したときの理由の扱いは、そちらにも同じ形で渡す。

### D9: 同梱フェーズは、前回同梱したもので今は無いものを取り除く(実装中に追加)

5.4 の準備で xcframework を外して release ビルドを作り直したところ、`.app` に前回の `piper_plus.framework` が残っていた。Xcode の差分ビルドは `.app` を作り直さず、同梱フェーズは出力を宣言していないので、Xcode が片付けることもない。前の change でレビューに指摘され、Simulator の debug ビルドで再現しなかったので見送った問題で、実機向けの release ビルドでは再現した。

- 同梱フェーズは、同梱した framework 名の一覧を `$TARGET_TEMP_DIR/embedded_native_frameworks.txt` に書く。`.app` の中に置かないのは、余計なファイルがバンドルの検証を乱さないようにするためである。
- フェーズの最初に、その一覧にあって今回同梱しないものを `.app` の `Frameworks/` から削除する。一覧に無いもの(Flutter や SPM が入れた framework)には触れない。
- 一覧の名前は実行時に xcframework から得るので、フェーズに静的な名前の一覧は持たない(既存の要件を保つ)。
- 確かめ方は 2 つ。pbxproj の定義を確かめる既存のテストに「一覧を使って取り除く」ことの検査を加え、5.4 で実際にビルドして確かめる。

### D8: iPad での確認は手動で行う

UI の振る舞いはウィジェットテストで確かめる。iOS の扱いは、機能モデルの provider を iOS の値で上書きして確かめる。実機では `scripts/build_app.sh ios --release` でインストールし、次を手で確かめる。

- 設定で Piper のモデルをダウンロードできる
- 本文の読み上げ(生成・再生・一時停止・停止)
- 編集ダイアログ(区間の再生・再生成。参照音声の列が無いこと)
- 読み上げ辞書の追加
- 書き出しボタンが無いこと
- xcframework を外したビルドで、失敗通知に D6 のメッセージが出ること

## Risks / Trade-offs

- [just_audio の既定のオーディオセッションでは、iPad の消音設定で音が出ない可能性がある] → D8 の実機確認で、消音の有無ごとに音が出るかを見る。問題があれば、`audio_session` パッケージで再生カテゴリを `playback` にするタスクを追加する(バックグラウンド再生とは別の設定で、範囲は小さい)。
- [iPad mini の縦向きなど狭い画面では、読み上げボタンが本文に重なったり、編集ダイアログが窮屈になったりする] → 実機で確かめる。直す場合は Non-Goals のとおり別の change にする。
- [フォールバックで保存値を書き換えないため、設定画面の選択(D3 で非表示)と保存値が食い違ったままになる] → iOS では選択 UI 自体を出さないので、読者には見えない。デスクトップに戻せば保存値どおりに動く。
- [機能モデルのフィールドが増え、既存のテストの書き方が変わる] → `textToSpeech` は getter として残るので、読む側は変わらない。変わるのは機能モデル自体のテストだけである。

## iPad 実機での確認結果(2026-10-17、タスク 5.3)

- 環境: iPad mini (A17 Pro)、iPadOS 26.6.2。`scripts/build_app.sh ios --release` でビルドし、`xcrun devicectl` でインストールした。
- 次の 7 項目は、すべて問題なかった(ユーザが手で確認)。
  1. 設定の読み上げタブにエンジン選択が無く、Piper のモデルのダウンロードがあり、最後まで終わる
  2. 本文の読み上げで、生成・再生・一時停止・再開・停止が動く
  3. 生成済みの状態で、MP3 書き出しのボタンが無い
  4. 編集ダイアログに参照音声の列が無く、区間の再生と再生成が動く
  5. 読み上げ辞書に追加すると、読みが変わる
  6. 消音の有無にかかわらず音が出る(リスクに挙げたオーディオセッションの設定は不要だった)
  7. 縦向き・横向きのどちらでも、読み上げボタンが邪魔にならない

## ライブラリが無いビルドでの確認(2026-10-17、タスク 5.6)

- xcframework を外し、D9 の修正後の同梱フェーズで release ビルドを作った。差分ビルドで `piper_plus.framework` が取り除かれることを確かめてから、iPad にインストールした。
- 読み上げボタンを押すと失敗通知が出て、文言には `piper_plus.framework` と `scripts/build_piper_ios.sh` が含まれていた(ユーザが確認)。

**実機のデータの消失(記録)**: 一連の作業の途中で、iPad のアプリのデータ(小説、読書位置、ブックマークなど)が消えた。アプリのデータ領域が作り直された時刻は、タスク 5.2 で `xcrun devicectl device install app` を実行した 23:42 と一致する。その直前に入っていたのは、前の change で `flutter drive --profile` が入れた profile ビルドである。原因は、このインストールか、それ以前の `flutter drive` のどちらかで、特定できていない。iCloud バックアップが無く、復元はできなかった。今後は、実機にインストールする前にユーザに伝え、`Documents/` と `Library/Application Support/` を Mac に退避する。

## Migration Plan

- デスクトップの利用者に見える変化は 2 つだけである。編集ダイアログで Piper を選んでいるときに参照音声の列が消えること、読み込み失敗の通知に理由が載ることである。
- iPad は、更新すると読み上げが現れる。最初に設定から Piper のモデルをダウンロードする必要がある(読み上げを押すと、既存のモデル未準備の案内が出る)。
- 元に戻すときは、`piperTts` の iOS の値を false にすれば、従来どおり読み上げが隠れる。
