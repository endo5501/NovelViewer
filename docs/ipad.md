# iPad 版

iPad 版は小説ビューア、LLM 要約、Piper と Irodori-TTS による読み上げを提供します。配布経路は無く、各自でビルドして実機にインストールします。

- [提供する機能・しない機能](#提供する機能しない機能)
- [LLM 要約](#llm-要約)
- [読み上げ](#読み上げ)
- [ビルドとインストール](#ビルドとインストール)
- [ライブラリの場所](#ライブラリの場所)
- [共有シートから登録する](#共有シートから登録する)
- [狭い画面でのレイアウト](#狭い画面でのレイアウト)
- [コンテキストメニューをタッチで開く](#コンテキストメニューをタッチで開く)

## 提供する機能・しない機能

デスクトップ版にある次の機能は UI ごと表示されません。

| 機能 | iPad で提供しない理由 |
| --- | --- |
| 読み上げエンジン Qwen3-TTS | iOS 向けのライブラリが無い。エンジンの選択欄には Piper と Irodori-TTS だけが出る |
| Irodori-TTS の v3 / v4 とガイダンスの調整 | デスクトップの audio.cpp 版のモデルは、iPad でアプリが使えるメモリに収まらない。iPad では speech.cpp で動く v4.1 Small MF（F16）だけを使う。このモデルはガイダンスと推論ステップ数を自身で扱うので、調整用のスライダーは出ない |
| 参照音声の録音・ドラッグ＆ドロップ・フォルダを開くボタン | マイクの経路は未確認で、ドロップのプラグインは iOS に無い。参照音声は、ファイルを選ぶボタンか Files アプリで追加する（[下記](#読み上げ)） |
| MP3 書き出し | 書き出しに使う LAME の iOS 向けビルドが無い |
| 画面ロック中の読み上げ | 未対応。アプリが前面にあるあいだだけ再生する |
| アプリ内の更新確認 | 配布経路が無く、更新は下記の手順でビルドし直して入れ替える |

外付けキーボードを接続した場合、ショートカットの既定修飾キーは macOS と同じ ⌘ です。

## LLM 要約

デスクトップ版と同じく、次のプロバイダを設定画面から選べます。

| プロバイダ | 接続先 |
| --- | --- |
| Ollama / OpenAI互換API | 同じネットワーク上の PC などで動かしている LLM サーバ |
| オンデバイス (Apple) | iPad 内の Apple のオンデバイス AI モデル。サーバ不要で、本文は端末の外に送られない |

**LLM サーバに接続する場合:** 既定のエンドポイント `http://localhost:11434` は iPad 自身を指すため、サーバを動かしている PC のアドレス（例: `http://192.168.1.100:11434`）に書き換えてください。初回接続時に「ローカルネットワーク上のデバイスの検出と接続」の許可を求められるので、許可してください。拒否した場合は iPad の設定アプリ > プライバシーとセキュリティ > ローカルネットワークから変更できます。Ollama は既定で PC 自身からの接続しか受け付けないため、PC 側で `OLLAMA_HOST=0.0.0.0` を設定して起動する必要があります。

**オンデバイスを使う場合:** Apple Intelligence に対応した iPad で、設定アプリから Apple Intelligence を有効にしてください。無効な場合やモデルの準備中は、選択肢が選べない状態で理由が表示されます。非対応の端末・OS では選択肢自体が表示されません。

解析結果は小説フォルダ内のデータベースに保存され、左カラムの「解析履歴」タブから一覧できます。デスクトップで作成した解析結果も、小説フォルダごと持ち込めば同様に参照できます。本文中の解析済みの語にポインタを合わせてポップアップで内容を読む操作は、トラックパッド（Magic Keyboard など）を接続している場合に限られます。

## 読み上げ

読み上げのエンジンは Piper と Irodori-TTS から選べます。使えるのは、生成・再生・一時停止・停止、編集ダイアログでの区間ごとの再生と再生成、生成した音声の削除、読み上げ辞書です。

1. 設定 > 読み上げ で、エンジンを選んでモデルをダウンロードする（初回のみ）
   - Piper: モデルと OpenJTalk 辞書
   - Irodori-TTS: v4.1 Small MF（F16、約 1.9GB）。ダウンロードの後、サイズと SHA-256 で照合します
2. 本文を開き、右下の読み上げボタンを押す

**Irodori-TTS の参照音声（声のクローン）:** 参照音声の欄の「＋」ボタンでファイルを選ぶか、Files アプリで、ライブラリのフォルダ（`Documents/NovelViewer/`）と同じ階層にある `voices` フォルダに WAV を置き、更新ボタンを押します。iPad の Irodori-TTS が読めるのは WAV だけで、MP3 は一覧に出ません（フォルダからは消えません）。参照音声を選ばないと、声はモデルが選びます。区間ごとのメモは、声の説明（キャプション）として使われます。

**Irodori-TTS の待ち時間:** 再生を始めるたびにモデルを読み込むので、最初の音が出るまで 10 秒ほどかかります。長い文は読点で区切って合成し、つなぎ目に短い間を入れます。

読み上げのライブラリは別にビルドしてアプリに同梱します（[下記](#5-読み上げttsのネイティブライブラリ)）。同梱していないアプリで読み上げボタンを押すと、framework（`piper_plus.framework` または `speech_cpp.framework`）がこのビルドに無いことと、ビルドの手順を示すエラーが出ます。

## ビルドとインストール

```bash
scripts/build_app.sh ios --release
xcrun devicectl device install app --device <デバイスUDID> build/ios/iphoneos/Runner.app
```

`build_app.sh` は macOS 版と同じく commit ハッシュを埋め込みます。デバイスの UDID は `xcrun devicectl list devices` の Identifier 列で確認できます。

ビルドには以下の準備が必要です。

### 1. Xcode の iOS platform component

`xcodebuild -showsdks` が iOS SDK を表示していても、platform component が未導入だとビルドは `iOS ... is not installed` で失敗します。Xcode > Settings > Components から導入するか、以下を実行してください（数 GB のダウンロードが発生します）。

```bash
xcodebuild -downloadPlatform iOS
xcrun simctl list runtimes   # iOS のランタイムが列挙されれば導入済み
```

### 2. 署名設定

Team ID をリポジトリに含めないため、`ios/Flutter/Local.xcconfig`（Git 管理外）を各自で作成します。

```
DEVELOPMENT_TEAM = XXXXXXXXXX
```

Team ID は Xcode > Settings > Accounts、または `security find-identity -v -p codesigning` で確認できます。このファイルが無い状態でもビルド構成は壊れず、署名時にのみ失敗します。

無料プロビジョニング（Apple ID のみ、有料の Developer Program に未加入）でインストールしたアプリは **7 日で失効**します。失効後は Xcode から再インストールしてください。

### 3. debug ビルドは実機のホーム画面から起動できない

iOS 14 以降、debug ビルドは JIT を必要とするため Flutter ツール経由でしか起動できません。ホーム画面のアイコンから起動すると次のメッセージだけが表示されます。

```
In iOS 14+, debug mode Flutter apps can only be launched from Flutter tooling,
IDEs with Flutter plugins or from Xcode.
```

常用する場合は上記のとおり `--release` でビルドしてインストールしてください。開発中にホットリロードを使いたい場合は `fvm flutter run -d <デバイスUDID>` で、ツールに接続したまま起動します。

### 4. 依存の管理方式

iOS は Swift Package Manager 単独構成です（CocoaPods は使用しません）。`ios/Podfile` は存在せず、依存のピンは 2 つの `xcshareddata/swiftpm/Package.resolved` が保持します。macOS は従来どおり CocoaPods です。

### 5. 読み上げ（TTS）のネイティブライブラリ

読み上げを使うには、アプリをビルドする前に Piper エンジンのライブラリをビルドしておきます。Irodori-TTS のライブラリは[次節](#6-speechcpp-による-irodori-tts)でビルドします。読み上げを使わないなら、この手順は不要です。

```bash
scripts/build_piper_ios.sh           # ios/Frameworks/piper_plus.xcframework を生成（約 1 分）
scripts/test/verify_piper_ios.sh     # 成果物の検証
```

- 成果物（実機用と Simulator 用、約 17MB ずつ）は **Git で管理していません**。iOS で読み上げを試す場合は、チェックアウトごとに上のスクリプトを実行してください。成果物が無ければ、アプリは読み上げのライブラリを含まずにビルドされます。
- ONNX Runtime 1.20.0 を Microsoft の配布元から取得し（SHA-256 で検証）、piper-plus と一緒に 1 つの framework にリンクします。iOS 向けの ONNX Runtime は静的ライブラリとして配布されているので、単独の framework は作りません。
- Runner の Run Script フェーズ「Embed Native Frameworks」が、`ios/Frameworks/` にある xcframework をすべて `.app` に同梱して署名します。Xcode の設定を変える必要はありません。
- xcframework を外すと、次のビルドで `.app` からも取り除かれます。ただし、このフェーズが同梱したものの記録を始める前のビルド成果物には、記録がありません。そのため初回だけは、外す前に `fvm flutter clean` でビルド成果物を消してください。

**piper-plus へのパッチ:** upstream の piper-plus v2.0.2 は、iOS では OpenJTalk を無効にしてビルドされます。そのため日本語の文から音素が得られず、音声も出ません。`scripts/build_piper_ios.sh` は、サブモジュールを `git archive` で取り出したコピーに `patches/piper-plus/` のパッチを当ててからビルドします（サブモジュールは変更しません。macOS / Windows のビルドにも当てません）。同じ修正を upstream に提案する予定です（PR の文面は `openspec/changes/archive/2026-10-17-piper-ios-build/upstream-pr-draft.md`、未提出）。取り込まれたリリースにサブモジュールを上げたら、パッチを削除します。パッチが当たらなくなるとスクリプトはエラーで止まるので、そのときは upstream の対応状況を確認してください。

**合成テスト:** `integration_test/piper_ios_synthesis_test.dart` は、アプリと同じ経路で Piper を読み込み、日本語の音素化と合成を確かめて、所要時間とメモリを記録します。モデルと辞書が無ければ、アプリのダウンロード処理で取得します。

```bash
# Simulator（`xcrun simctl list devices` の UDID）
fvm flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/piper_ios_synthesis_test.dart -d <Simulator の UDID>

# 実機（profile ビルドが必須。`fvm flutter devices` が表示する ID を指定）
fvm flutter drive --profile --driver=test_driver/integration_test.dart \
  --target=integration_test/piper_ios_synthesis_test.dart -d <デバイス ID>
```

- 実機で実行するには、Mac に Rosetta（`sudo softwareupdate --install-rosetta --agree-to-license`）と、ターミナルへのローカルネットワークの許可（システム設定 > プライバシーとセキュリティ > ローカルネットワーク）が必要です。Flutter が USB 接続に使う `iproxy` が Intel 用のバイナリのためです。
- 実機では `flutter test` は使えません。debug ビルド（JIT）は、iPadOS 26 ではデバッガ無しだと起動直後に終了します。
- 計測結果はホストの `build/integration_response_data.json` と、端末の `Documents/benchmarks/piper_ios_<日時>.json` に出力されます。
- **実機でも Simulator でも、`flutter drive` は実行が終わるとアプリを削除します。** アプリのデータ（取得したモデル、小説、設定）も一緒に消えるので、実機で実行する前に、次節の手順でアプリのデータを Mac にバックアップしてください。モデルは毎回取得し直しになります。一方、[ビルドとインストール](#ビルドとインストール)の `xcrun devicectl device install app` で release ビルドを入れたときは、今のアプリの上に入れ替わり、データはそのまま残ります。

### 6. speech.cpp による Irodori-TTS

iPad の Irodori-TTS は [speech.cpp](https://github.com/nyosegawa/speech.cpp)（`third_party/speech.cpp`）で動きます。Irodori-TTS を使うビルドでは、アプリをビルドする前にこのライブラリをビルドし、`ios/Frameworks/` に置いたままにしてください。ビューアや Piper だけなら、この手順は不要です。

```bash
scripts/build_speech_ios.sh          # ios/Frameworks/speech_cpp.xcframework を生成
scripts/test/verify_speech_ios.sh    # 成果物の検証
```

- 成果物（実機用と Simulator 用、約 8MB ずつ）は **Git で管理していません**。Apple の `Speech.framework` と取り違えないよう、上流の `libspeech` を `speech_cpp` という名前の framework にしています。
- 同梱は Piper と同じく「Embed Native Frameworks」フェーズが行います。Xcode の設定を変える必要はありません。

**計測テスト:** 次の計測テストは、アプリに組み込む前に、メモリと速度が足りるかを確かめるために作ったものです。 `integration_test/speech_cpp_ios_test.dart` は、Irodori-TTS v4.1 Small MF を GPU で読み込み、参照音声つきで中程度の文（51字）・125字の文・中程度の文の10回連続を合成し、別スレッドからの中断も確かめます。各段階のメモリの余裕と所要時間を記録し、事前に決めた基準（完走、メモリの余裕 512 MiB 以上、125字の文の RTF 1.0 未満）で合否を判定します。モデルは固定したリビジョンから取得し、サイズと SHA-256 で照合します。

**実行する前に、アプリのデータをバックアップしてください。** 実機テストのインストールでアプリのデータが消えたことがあります。Files アプリで見える `Documents/` に加えて、設定が入る `Library/` も Mac に取り出しておきます。

```bash
for d in Documents Library; do
  xcrun devicectl device copy from --device <デバイス UDID> \
    --domain-type appDataContainer --domain-identifier com.endo5501.novelViewer \
    --source "$d" --destination ~/Backups/NovelViewer-iPad-$(date +%Y%m%d)/"$d"
done
```

量子化は `--dart-define=SPEECH_CPP_VARIANT=` で1つずつ選び、`q4_k` → `q8_0` → `f16` の順に実行します。1回の実行で1つだけ計測するのは、ピークメモリがプロセスの中で前の計測に引きずられないようにするためです。小さいものから実行すれば、大きいものがメモリ不足で強制終了されても、それまでの結果は残ります。

```bash
fvm flutter drive --profile --driver=test_driver/integration_test.dart \
  --target=integration_test/speech_cpp_ios_test.dart \
  --dart-define=SPEECH_CPP_VARIANT=q4_k -d <デバイス ID>
```

- 実機の前提（Rosetta、ローカルネットワークの許可、profile ビルド）は Piper の合成テストと同じです。
- 結果はホストの `build/integration_response_data.json` に出力されます。実行ごとに上書きされるので、量子化ごとに別名でコピーしてください。端末の `Documents/benchmarks/` にもレポートと、参照音声と各文の WAV が保存されます。ただし、実行が終わるとアプリと一緒に消えます。端末のファイルが残るのは、強制終了されてアプリが削除されなかった場合だけです。
- モデル（Q4_K 約 0.9GB、Q8_0 約 1.2GB、F16 約 1.9GB）は、実行のたびに `Documents/models/speech-cpp/` へ取得されます。
- 実行が終わったらアプリが消えているので、`scripts/build_app.sh ios` で作った release ビルドを `xcrun devicectl device install app` でインストールし直します。そのうえで、アプリを起動する前に、バックアップを `xcrun devicectl device copy to`（`--domain-type appDataContainer`）で `Documents/NovelViewer`・`Library/Application Support`・`Library/Preferences` に書き戻します。
- Simulator では framework を開いてバージョンを読むだけで、モデルの取得と合成は行いません。Simulator の Metal では、モデルの読み込み中にプロセスが止められるためです。

## ライブラリの場所

小説は端末内の `Documents/NovelViewer/` に保存され、Files アプリの「このiPad内 > NovelViewer」から参照・追加・削除できます。

蔵書全体のメタデータ（`novel_metadata.db`）は Files アプリに露出しない `Library/Application Support/` に置かれます。一方、各小説フォルダの中にある `novel_data.db` / `episode_cache.db` / `tts_audio.db` は、小説フォルダごと持ち運ぶ設計のため Files アプリからも見えます。

> **注意:** `novel_data.db` にはブックマークと LLM 要約が入っており、破損時に自動復旧しません（意図的な設計です）。Files アプリで小説フォルダを整理する際は、`.txt` 以外のファイルを消したり、`-wal` / `-shm` を欠いた状態でコピーし直したりしないでください。フォルダごと丸ごと移動・コピーするのは安全です。

## 共有シートから登録する

URL スキーム `novelviewer://download?url=...`（[README](../README.md#url-スキームでダウンロードを依頼する) 参照）を、Safari の共有シートから呼び出せるようにします。

iOS の共有シートに直接 NovelViewer を出すには App Extension が要るため、現時点ではショートカットアプリを経由します。一度作れば、Safari の共有シートに項目として並びます。

1. ショートカットアプリで新規ショートカットを作る
2. 詳細（ⓘ）を開き、「共有シートに表示」をオンにする。受け取る種類は「URL」だけにする
3. アクションとして「URL を展開」→「テキスト」に `novelviewer://download?url=` と入力し、続けて受け取った URL をエンコードして連結する（「テキストをエンコード」アクションを使う）
4. 最後に「URL を開く」アクションを置く
5. 分かりやすい名前（例: NovelViewer に送る）を付けて保存する

Safari で小説の目次ページを開き、共有 → 作成したショートカットを選ぶと、NovelViewer が前面に来てダイアログがその URL 入りで開きます。

共有シートに NovelViewer を直接出すには App Extension が必要です。Apple Developer Program への加入を前提に保留しており、着手するときの設計は [`plans/2026-09-11-share-extension-phase2.md`](plans/2026-09-11-share-extension-phase2.md) にあります。

## 狭い画面でのレイアウト

表示幅が 800pt 未満のときは、左カラム（ファイル・ブックマーク）と検索結果が画面内に並ばず、それぞれ Drawer として本文に重なる形で開きます。本文は画面幅いっぱいを使います。iPad mini の縦向き（744pt）が該当し、横向き（1133pt）は従来どおりの 3 カラムです。

デスクトップも同じ規則で動きます。既定 1280pt および保存サイズの復元（800pt 以上に補正）では 3 カラムのままですが、ウィンドウを 800pt 未満まで縮めると同じ Drawer 表示になります。この幅では 3 カラムだと本文が 248pt しか残らないため、意図した動作です。

| 操作 | 開くもの |
| --- | --- |
| AppBar 左端の ≡ | ファイル・ブックマーク |
| AppBar の 🔍 | 検索（キーボードがあれば ⌘F も同じ） |

Drawer は **AppBar のボタンからのみ**開きます。画面端からのスワイプで開く動作は無効にしてあります——縦書き表示では画面端の水平スワイプがページ送りだからです。Drawer を閉じるには本文側をタップするか、ファイルを選んでください（選ぶと自動で閉じます）。

## コンテキストメニューをタッチで開く

右クリックに相当する操作がマウス以外に無いため、コンテキストメニューには指で届く入口を用意しています。項目・並び・動作は右クリックで開いた場合と同一です。

| メニュー | 指での開き方 |
| --- | --- |
| ファイル一覧の小説・フォルダ（更新・タイトル変更・移動・削除） | タイルを**長押し** |
| ブックマーク一覧（削除） | 項目を**長押し** |
| 解析履歴一覧（コピー・削除・詳細を表示） | 項目を**長押し** |
| 縦書き表示の選択メニュー（コピー） | 範囲選択したあと、**選択範囲の内側をタップ** |

これらの入口はいずれも、**副ボタンを持たないポインタ**（指・スタイラス）に限って有効です。マウスは右クリックで同じメニューに到達できますし、マウスに長押しやタップを割り当てると「遅い左クリックでタイルを開く」「クリックで選択を解除する」という既存の操作が失われるためです。トラックパッドを接続した iPad では、従来どおり右クリックが使えます。

縦書きで選択範囲の外側をタップした場合は、これまでどおり選択が解除されます。列と列の間の余白は選択範囲の内側として扱われます（何も描画されておらず、指で文字を狙うとそこに落ちるため）。ドラッグによる範囲選択とスワイプによるページ送りに変更はありません。
