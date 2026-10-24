# Design

## Context

動機は proposal.md の Why を参照。ここでは、方式を決めるのに必要な現状と制約だけを書く。

- **読み上げの流れ**
  - 再生のたびに `TtsControlsBar` が新しい `TtsIsolate` を作る。`TtsStreamingController` は、`TtsSession.ensureModelLoaded(config)` の後、セグメントごとに `SynthesizeMessage` を worker に送る。
  - worker（`TtsIsolate._isolateEntryPoint`）は、`TtsEngineType` ごとにエンジンを 1 つ持つ。`irodori` のエンジンは audio.cpp の `IrodoriTtsEngine` だけである。
  - `doSynthesize` は、ガイダンスの 2 つのスケールと step 数が null でないことを前提にしている（`!`）。
- **中断**
  - `TtsAbortHandle` は、`TtsEngineType` をキーにしたマップに入っている。qwen3 用と audio.cpp 用の 2 つで、どちらもそのライブラリ自身が確保したフラグである。
  - `TtsIsolate.abort()` はすべてのハンドルを立てる。worker は合成の前に `resetAbort()` を呼ぶ。
  - speech.cpp の中断は、リクエスト単位の `speech_request_cancel` か、コールバックが 0 以外を返すことで行う。
    - 進捗コールバックは、サンプラーの step ごとに呼ばれる。MF は 4 step。
    - 音声コールバックは、デコードの窓ごとに呼ばれる。
    - どちらのコールバックも、合成を呼んだスレッドの上で同期的に走る。
- **スパイクのバインディング**（`speech_cpp_native_bindings.dart`）
  - モデルの読み込み、voice の登録、リクエスト、合成までは揃っている。
  - 中断は `SpeechCppRequest.cancelAt(address)` で、リクエストのアドレスを別の isolate に渡す方式である。テストでは、中断を送るまでリクエストを解放しないことで成り立たせていた。アプリでは中断が来ないこともあるので、この方式は使えない。worker がリクエストを解放するのと、メインから中断するのが競合して、解放後のメモリに触れるためである。
- **iOS ビルド**
  - `ios/Frameworks/*.xcframework` は、Runner の「Embed Native Frameworks」フェーズが自動で同梱して署名する。
  - speech_cpp.xcframework を置いておけば、それだけで普段の iOS ビルドに入る。
- **iOS の参照音声**
  - `VoiceReferenceSection` は `desktop_drop` の `DropTarget` で包まれている。録音ボタンとフォルダを開くボタンも、常に表示されている。
  - iOS では Qwen3 も Irodori も使えなかったので、この画面ごと出していなかった。
  - `Info.plist` では Files アプリからの共有がすでに有効で、`file_picker` は依存に入っている。
- **再生の待ち表示**
  - モデルの読み込み中は、`TtsPlaybackState.waiting` で `_waitingSpinner` が出ている。読み込み専用の表示は無い。

## Goals / Non-Goals

**Goals:**
- speech.cpp のエンジンを、audio.cpp のエンジンと同じ形で worker に差し込む。形とは `loadModel`、`synthesize`、`abort`、`resetAbort`、`dispose`、`isLoaded` である。worker の分岐は実行系の違いだけにする。
- 長い文の分割を、ネイティブなしでテストできる Dart の純粋なロジックにする。
- 中断で、isolate をまたいで speech.cpp のポインタを共有しない。

**Non-Goals:**
- モデルの常駐。再生のたびに読み込み、10〜12 秒待つ作りのまま。別の change で扱う。
- 読み込み専用の進捗表示。今の待ちのスピナーで足りるかは、実機で確かめる。
- デスクトップで speech.cpp を使うこと。audio.cpp の分割合成や中断の方式は変えない。
- 参照音声の voice ファイル（`.voice.gguf`）を作って保存すること。登録は WAV からの都度とし、キャッシュは worker の中だけで持つ。
- seed を設定から固定すること。speech.cpp が文ごとに seed を選ぶ。分割した部分どうしでは同じ seed を使う。

## Decisions

### D1. 実行系は variant が持ち、プラットフォームは実行系を答える

- `IrodoriModelVariant` に `runtime`（`audioCpp` / `speechCpp`）を持たせ、`v4.1-mf` を追加する。
- `PlatformCapabilities` は `irodoriRuntime` を答える（iOS は speechCpp、それ以外は audioCpp）。
- 選択肢のプロバイダは、`IrodoriModelVariant.values` から runtime が一致するものを返す。
- `irodoriModelVariantProvider` は、保存値が選択肢に無ければ選択肢の最初を返し、保存値は書き換えない。
- 実行系の enum `IrodoriRuntime` は `platform_capabilities.dart` に置き、`IrodoriModelVariant` がそれを参照する。`ProgressSyncSignIn` と同じ置き方で、shared 層から features 層への依存を作らない。

他に考えた案:
- **エンジンの種類を分ける**（`irodoriSpeechCpp` を足す）。UI ではエンジンが 2 つ並び、DB のセグメントに記録されたエンジンの扱いも分かれる。ユーザーにとっては同じ Irodori なので採らない。
- **プラットフォームから直接エンジンを選ぶ**。variant がどの GGUF を指すかと、どの実行系で動くかが分かれてしまい、1 か所で決まらなくなるので採らない。

`IrodoriModelVariant` には、ほかに次の欄を足す。
- `acceptsGuidance`: MF は false。
- `downloadUrl`: 取得元を variant ごとにする。既存の 2 つは今の `_baseUrl` から組み立てる。
- `sha256`: 既存の 2 つは null。

ファイル名などは、スパイクの `SpeechCppVariant.f16` と同じ値を使う。

| 欄 | 値 |
|---|---|
| `modelDirName` | `Irodori-TTS-v4.1-Small-MF-GGUF` |
| `ggufFileName` | `Irodori-TTS-866M-MF-v4.1-F16.gguf` |
| `expectedFileSize` | 1,920,321,792 |
| `sha256` | `e237dc3eefe469b8bba87872beacf12fb7fe00dbdf85767edca8ec04ab910d13` |
| `needsDurationCorrection` | false |
| `supportsCaption` | true |

### D2. worker への受け渡し

- `LoadModelMessage` に `irodoriRuntime` を足す。
- `TtsSession` は `IrodoriEngineConfig` から次のように渡す。
  - `runtime == speechCpp` のときは、`modelDir` に GGUF のパス（`p.join(modelDir, variant.ggufFileName)`）を入れて送る。speech.cpp はファイルを読み、audio.cpp はディレクトリを読むためである。
  - `IrodoriModelSpecInstaller.install` は audio.cpp のときだけ呼ぶ。speech.cpp の GGUF に audio.cpp の契約ファイルを置かない。
- worker は `irodori` のとき、runtime に応じて `IrodoriTtsEngine` か `SpeechCppIrodoriEngine` を開く。2 つのエンジンが共有するのは、Dart の小さなインターフェース（上の 6 メンバー）だけにする。
- `doSynthesize` の Irodori 分岐は、ガイダンスの値をインターフェースの名前付き引数で渡す。null 許容にはしない。今の呼び出し側の不変条件（必ず値を入れる）を崩さないためである。
- `SpeechCppIrodoriEngine` は、ガイダンスの値を受け取っても speech.cpp に渡さない。

### D3. 中断: worker を起動するときに確保する Int32 のフラグを、コールバックが読む

- `TtsAbortHandle` のマップのキーを、`TtsEngineType` から、ネイティブの系統（`qwen3`、`audioCpp`、`speechCpp`）に変える。
- speechCpp のハンドルは、`calloc<Int32>` で確保した 1 ワードである。speech.cpp のライブラリは使わない。
  - `abort()` は 1 を書き、`free()` は worker が終わった後に `calloc.free` する。
  - ライブラリに依存しないので、framework が無いビルドでも確保できる。
- `TtsSession` は、config の実行系から系統を選び、そのアドレスを `LoadModelMessage.abortHandleAddress` で送る。
- `SpeechCppIrodoriEngine` は、このアドレスを `Pointer<Int32>.fromAddress` で持つ。
  - `resetAbort()` は 0 を書く。
  - 合成の間は、バインディングに「停止を求めるか」の関数として `() => flag.value != 0` を渡す。
  - `dart:ffi` には atomic な操作が無い。正しさは、境界の揃った 32 bit の 1 回の書き込みと読み込みに頼る。最悪でも、止まるのが step 1 つ分遅れるだけである。このことをハンドルのクラスのコメントに書く。
  - 中断を取りこぼす隙は、既存のハンドルと同じである。worker が `resetAbort()` した直後に `abort()` が来る場合で、コントローラが中断の後に次の `SynthesizeMessage` を送らないことで防いでいる。
- バインディングは、合成の前にこの関数を isolate のグローバルに置き、2 つのコールバックの中で呼ぶ。2 つとは、`speech_request_set_progress` に渡す進捗コールバックと、既存の音声コールバックである。true なら 1 を返して止める。
  - コールバックが同期的に同じスレッドで走ることは、`speech.h` に書かれている。
  - 進捗コールバックの `Pointer.fromFunction` は、音声コールバックと同じく exceptionalReturn を 1 にする。判定の関数で Dart の例外が起きても、0 を返して合成が続かないようにするためである。
  - 止めた結果は `SpeechCppCancelled` とする。音声コールバックの中の例外（`callbackError`）とは区別する。今の `synthesisOutcome` は、callbackError が無いときの CANCELLED を中断として返すので、この区別はそのまま使える。
- `SpeechCppRequest.cancelAt` と、そのための `address` は削除する。スパイクの計測テスト（`integration_test/speech_cpp_ios_test.dart`）も、別の isolate からフラグを立てる方式に書き換える。`speech-cpp-ios-build` の「別のスレッドから中断」は、この方式でも満たせる。
  - 書き換えたテストは、コンパイルと `flutter analyze` が通るところまでを確かめる。実機での実行は見送る。`flutter drive` がアプリとデータを消すためである。
  - 実機での中断は、アプリの読み上げで確かめる（D8）。計測テストを実機で再び走らせるのは、バックアップから戻す前提で別に行う。
- `speech_request_cancel` のシンボルは、確認の一覧から外す。`speech_request_set_progress` は加える。

他に考えた案:
- **リクエストのアドレスを共有し、ロックで寿命を守る**。Dart の isolate 間でロックを持つ手段が無い。
- **worker 側で中断のメッセージを受け取る**。worker は合成中は同期で塞がっているので、メッセージを受け取れない。

中断が効くまでの遅れは、step 1 つ分かデコードの窓 1 つ分になる。iPad では、125 字で合成全体が数秒なので、1 秒以下と見込む。実機で確かめる。

### D4. 長い文の分割は、合成関数を注入する純粋な Dart で行う

- `IrodoriSentenceSplitter`（仮称）を作る。テキストと基準の長さ L を受け取り、部分のリストを返す。
  - L 以下の文はそのまま 1 つにする。
  - L を超える文は、読点の直後で切れる位置のうち、L を超えない最も後ろで切る。これを残りに繰り返す。
  - L を超えない位置に読点が無いときは、L より後ろの最初の読点の直後で切る。その部分は L を超えるが、読点 1 つ分で収まる。
  - 読点がまったく無い残りは、L を超えても 1 つのままにする。
  - 分けた部分を元の順につなぐと、元のテキストに戻る。
- `SpeechCppIrodoriEngine.synthesize` は、部分ごとにリクエストを作って合成し、音声をつなぐ。
  - 各部分の合成の前に、中断のフラグを確かめる。
  - 最初の部分で seed を固定する。speech.cpp にオプション `seed` を渡し、同じ値を残りの部分にも使う。seed の値は Dart 側で乱数を引いて決める。speech.cpp が選んだ seed を結果から読む API をバインディングに足さないためである。
- つなぎ目の処理は、次の関数にする。前の音声の末尾の無音と、次の音声の先頭の無音を測り、足りない分だけ 0 を補う。この関数もネイティブなしでテストする。
  - 無音の閾値は、speech.cpp の ADR と同じ −40 dBFS とする。
- 部分の合成が `out_of_range` で拒否されたら、それ以上分けない。部分のテキストと speech.cpp の詳細を含むエラーで止める。
- 初期値:
  - L = 80 字。Irodori-TTS-Server が 80 字以上の入力を句読点で分けるのに合わせた。speech.cpp の文書では、崩れが約 100 字から始まるとされている。
  - 補う無音は 0.3 秒。読点の間は、文と文の間（0.9 秒）より短くする。
  - どちらも iPad での試聴で決め直し、design に書き戻す（tasks で扱う）。

他に考えた案:
- **`TextSegmenter` で分ける**。セグメントは DB の保存単位とハイライトの単位でもあり、デスクトップの読み上げにも影響する。Irodori の speech.cpp だけの理由で単位を変えたくないので採らない。
- **拒否されたときだけ分ける**（speech.cpp の worker の方式）。拒否されなくても 100 字を超えると崩れるので、それだけでは足りない。

### D5. 参照音声の登録とキャッシュ

- `SpeechCppIrodoriEngine` は、`Map<String, String>`（参照音声のパス → voice の名前）を持つ。
  - 名前は `ref0`、`ref1` と連番で付ける。speech.cpp の voice 名がモデルの中で重ならないようにするためである。
  - パスで見つかればその名前を使い、無ければ `addVoice` で登録してから使う。
  - モデルを読み直すときと `dispose()` では、マップを空にする。
- ファイルの内容が同じパスで差し替わる場合は、考えない。
  - 再生のたびに isolate を作り直すので、キャッシュは 1 回の再生の間しか生きない。
  - 名前を変えずにファイルを上書きできるのは Files アプリ経由だけで、再生中にそうすることは想定しない。
- 参照音声が無いときは `voice=none` にする。
- 登録に失敗したら、そのまま `SpeechCppException` を投げる。`none` に切り替えて続けることはしない（spec のとおり）。

### D6. 参照音声の画面

- `PlatformCapabilities` に `voiceRecording`、`voiceFileDragDrop`、`voicesFolderReveal` を足す（iOS ではすべて false）。対応するプロバイダも作る。
- `VoiceReferenceSection` の変更:
  - `voiceFileDragDrop` が false のときは、`DropTarget` で包まない。
  - 録音ボタンとフォルダを開くボタンは、それぞれのプロバイダが true のときだけ表示する。
  - ファイルを選ぶボタンを足す（全プラットフォーム）。`file_picker` の `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ..., allowMultiple: true)` を使う。
    - iOS では、選んだファイルがアプリの一時ディレクトリに複製されてから渡る。それを `addVoiceFile` でコピーする。
- 一覧に出す拡張子は、選択中のエンジンと variant から決める。
  - これを「受け付ける参照音声の拡張子」として `TtsEngineConfig` に持たせる。speechCpp の variant は `{'.wav'}`、それ以外は `{'.wav', '.mp3'}` とする。
  - `listVoiceFiles({Set<String>? extensions})` で絞る。
  - ファイルを選ぶ画面にも、同じ拡張子を渡す。
- 保存されている参照音声の名前が、選択中のエンジンが受け付けない拡張子なら、config の解決でその参照音声を null（参照音声なし）にする。今の画面は、一覧に無い名前を「なし」と表示するので、合成もそれに合わせる。セグメントごとに DB に保存した参照音声も同じ扱いにする（`resolveRefWavPath` の手前で判定する）。
  - エンジンの「読めない参照音声はエラー」は、それでも届いた読めないファイルに対する扱いである。
- `settings_dialog.dart` の Irodori 分岐は今のままで、iOS でも参照音声の画面を出せる。
- Irodori の設定画面の変更:
  - `variant.acceptsGuidance` が false のときは、`_IrodoriSynthesisParams` を出さない。
  - 選択肢が 1 つのときは、ドロップダウンの代わりに名前を出す。
- 文言は ja / en / zh で追加する。対象は、ファイルを選ぶボタンのツールチップ、MF の名前、ガイダンスを使わない旨の注記。

### D7. ダウンロード

- `IrodoriModelDownloadService` は、`variant.downloadUrl` から取る。
- 完了したら、サイズに加えて、`variant.sha256` がある variant ではハッシュも確かめる。
  - ハッシュは `package:crypto` で、ファイルをストリームで読みながら計算する。依存に入っている。1.9 GB をメモリに載せないためである。
  - 一致しなければ、ファイルを消して `IrodoriDownloadHashMismatchException` を投げる。
- `isModelDownloaded` は、これまでどおりサイズだけを確かめる。起動のたびに 1.9 GB を読ませないためである。
- 保存先は、既存の models ディレクトリの下の `Irodori-TTS-v4.1-Small-MF-GGUF/` とする。「GGUF を 1 本だけ置く」既存の規則は、そのまま当てはまる。

### D8. 実機での確かめ方

- `scripts/build_speech_ios.sh` で xcframework を作り、`scripts/build_app.sh ios --release` でアプリをビルドする。
- 実機には `xcrun devicectl device install app --device 00008130-000A0DD42181001C <Runner.app>` で、今のアプリの上から入れる。
  - `flutter drive` と `flutter run` は使わない。前者はアプリとデータを消す。
- バックアップは、2026-10-24 に取った `~/Backups/NovelViewer-iPad-20261024/` を使う（ユーザーの判断）。
- インストールの前にユーザーの確認を取る。インストールの後は、ライブラリが残っていることを最初に確かめる。
- アプリ内で、参照音声とキャプションを指定して 1 話を読み上げ、次を確かめる。
  - 最後まで読み上がること
  - 中断できること
  - 長い文の分割とつなぎ目が聞いて自然なこと
- メモリと待ち時間は、Xcode の Instruments か `devicectl` で取得し、design に書き戻す。
  - メモリはピーク値と空きの最小値を取る。
  - 待ち時間は、モデルの読み込みと、最初の音が出るまでを取る。

## Risks / Trade-offs

- [実際のアプリはテストよりメモリを使い、上限に近づく] → スパイクでは空きの最小値が 1,349 MiB あった。実際のアプリでは UI、画像、オンデバイス LLM の分が上乗せされるので、実機で空きの最小値を測る。余裕が 512 MiB を切ったら報告し、Q8_0 に切り替えるかをユーザーと相談する。
- [再生のたびに 10〜12 秒待つ] → 待ちのスピナーは今のまま出る。改善は別の change で扱う（ユーザーと合意済み）。
- [読点の無い長い文は、分けても崩れる] → 語の途中では切らず、そのまま合成する。崩れは残るが、語が途中で切れるよりは聞き取りやすいと判断した。拒否されたらエラーにする。
- [中断が効くまで、step 1 つ分かデコードの窓 1 つ分遅れる] → 1 秒以下と見込み、実機で確かめる。
- [iOS では MP3 の参照音声が一覧に出ない] → 画面にその旨の注記を出すかは、実機で見て決める。ファイルそのものは消さない。
- [speech.cpp を開けないビルド（xcframework が無い）] → 読み込むときに、ビルド手順を案内する既存のエラーが出る。機能を隠しはしない（`platform-capabilities` の方針）。

## Migration Plan

- 保存されている設定は書き換えない。iOS で `irodori` や `v3` が保存されていても、解決の段階で `v4.1-mf` を使う。
- iOS で初めて Irodori を選んだときは、モデルが未ダウンロードと表示され、既存のダウンロードの UI から取得する。
- 元に戻すときは、`irodoriTts` を iOS で false に戻せば、これまでの状態に戻る。追加したファイルと設定値は、そのまま残しても害がない。
- main へは、実機での確認が終わってから、`feat/speech-cpp-ios-spike` ごとマージする。

## Open Questions

- 基準の長さ L とつなぎ目の無音の最終値（初期値は 80 字と 0.3 秒）。試聴で決めて design に書き戻す。spec は design を参照しているので、spec は変えない。
- iOS で MP3 が一覧に出ないことを画面で注記するか。実機で見て決める。注記を出す場合も、文言を足すだけで済む。
