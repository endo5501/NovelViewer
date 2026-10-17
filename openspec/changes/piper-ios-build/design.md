## Context

動機は proposal.md を参照。ここでは方式を左右する現状と制約だけを記す。

- **upstream の iOS ビルド(v2.0.2)**
  - `PIPER_APPLE_EMBEDDED` のとき、piper_plus は静的ライブラリ(`.a`)としてビルドされる(`cmake/PiperPlusShared.cmake`)。
  - fmt / spdlog / OpenJTalk(`libopenjtalk.a`)/ hts_engine_stub は、POST_BUILD の `xcrun libtool -static` で1つの archive にまとめられる。
  - 次の 4 ファイルはビルドから外され、代わりに `openjtalk_ios_stub.c` が入る(`cmake/PiperCommon.cmake`)。
    - `openjtalk_wrapper.c`
    - `openjtalk_optimized.c`
    - `openjtalk_dictionary_manager.c`
    - `model_manager.cpp`
  - スタブの `openjtalk_is_available()` は常に 0 を返す。`phonemize_openjtalk_with_prosody()` はこの戻り値を最初に確かめるので、iOS では日本語が一切音素化されない。
- **パッチに使える部品**
  - OpenJTalk 本体(MeCab / NJD / JPCommon)と、それを直接呼ぶ `openjtalk_api.c` は、iOS でもビルドされて archive に含まれている。
  - iOS で禁じられている `popen` / `system` / プロセスの起動を使うのは、次の 2 つだけである。
    - `openjtalk_wrapper.c` の `_binary` フォールバック経路
    - `openjtalk_dictionary_manager.c` の辞書ダウンロード
  - C API の `piper_plus_create` は、`dict_dir` を `OPENJTALK_DICTIONARY_PATH` に `setenv` する。`get_openjtalk_dictionary_path()` は最初にこの環境変数を読む。
- **upstream CI の iOS 手順**(`release-shared-lib.yml`)
  - ONNX Runtime 1.20.0 を CDN(`pod-archive-onnxruntime-c-1.20.0.zip`、SHA-256 `50891a8a…`)から取得する。
  - 取得した ORT を `ONNXRUNTIME_DIR` / `ONNXRUNTIME_LIB` / `ONNXRUNTIME_INCLUDE_DIR` で外から与え、`cmake/ios.toolchain.cmake` で SDK ごとにビルドする。
  - deployment target は 15.0。ただし、CDN の ORT framework の `Info.plist` が宣言している `MinimumOSVersion` はまだ確かめていない(D4 で確かめる)。
  - CDN の ORT は動的な `onnxruntime.framework` で、スライスは `ios-arm64`(約 31MB)、`ios-arm64_x86_64-simulator`(約 67MB)、`macos-arm64_x86_64` の 3 つ。
- **NovelViewer の iOS プロジェクト(main)**
  - `IPHONEOS_DEPLOYMENT_TARGET = 15.0`。
  - ネイティブライブラリを同梱する仕組みは無い。
  - `integration_test` は未導入。
- **`feat/irodori-ios-build`(未マージ)で確立した手法**
  - `ios/Frameworks/*.xcframework` をグロブで走査して同梱・署名する Run Script フェーズ(`7cfb3573`、`5835525d`)。
  - deployment target のガードテスト(`4295a0b4`)。
  - 実機の integration test は `flutter drive --profile` でしか動かないという知見。
  - Simulator での Metal の制約は Piper(CPU で動く ORT)には関係しない。
- **アプリ側**
  - モデルと辞書の配置先は `p.join(p.dirname(libraryPath), 'models')`。iOS では `Documents/models/` になる。
  - Piper のモデル(`tsukuyomi-chan-6lang-fp16`)と辞書は、`PiperModelDownloadService` で取得できる。

## Goals / Non-Goals

**Goals:**
- iOS(Simulator と実機)で、`PiperTtsEngine` がアプリと同じ isolate 経路で日本語を合成できる状態にする。
- upstream に取り込まれたときに、パッチを外すだけで移行できる構成にする。
- xcframework を一度もビルドしていないチェックアウトでも、ビューアの iOS ビルドを壊さない。

**Non-Goals:**
- iOS で TTS の UI を有効にすること、`platform-capabilities` を変えること(後続の `ios-tts-piper` で扱う)。
- LAME(MP3 出力)の iOS ビルド。
- x86_64 の Simulator(Intel Mac)。
- CoreML Execution Provider による高速化(CPU のみで計測し、必要なら後で検討する)。
- CI での iOS ビルド。
- App Store 向けの Archive と、`PrivacyInfo.xcprivacy` の対応。

## Decisions

### D1: パッチの中身 — iOS でも wrapper と dictionary_manager をビルドし、プロセスを起動する部分だけを外す

`cmake/PiperCommon.cmake` の iOS 分岐を変え、`openjtalk_wrapper.c` と `openjtalk_dictionary_manager.c` を iOS でもビルド対象に入れる。2 つのファイルの中で、外部プロセスとダウンロードに関わる部分だけを `#if` で外す。

- `openjtalk_wrapper.c`
  - `_binary` 経路(一時ファイルと `execute_openjtalk_argv`)と `find_openjtalk_binary()` を外す。
  - iOS の `openjtalk_is_available()` は、辞書パスが存在するかだけで判定する。
  - `openjtalk_text_to_phonemes_with_prosody()` は、`_api` 経路が失敗したらフォールバックせずに NULL を返す。
- `openjtalk_dictionary_manager.c`
  - `download_and_extract_dictionary()` を外す。
  - iOS の `ensure_openjtalk_dictionary()` は、パスが解決できなければ失敗を返す。
  - パスは `OPENJTALK_DICTIONARY_PATH` から得る。システムパスや exe からの相対パスでの探索は、iOS では意味が無いので外す。
- `openjtalk_ios_stub.c`
  - wrapper と dictionary_manager が提供するようになったシンボルを削る。
  - `openjtalk_optimized.c` と `model_manager.cpp` のスタブは残す。
- `src/cpp/piper_proc_exec.c` は iOS ではビルドしない。wrapper の中でこれを参照する箇所も `#if` の内側に入れる。

判定には、upstream の CMake が既に定義している `PIPER_APPLE_EMBEDDED` を、コンパイル定義として渡して使う。`TARGET_OS_IPHONE` では、Mac Catalyst を除外している CMake 側の判定と食い違うからである。

代替案 1: スタブの中に `_api` 経路を複製する。パッチは小さくなるが、wrapper.c と同じ処理が 2 か所に分かれ、upstream で二重管理になる。upstream に受け入れられにくい。
代替案 2: `_api` 経路を新しいファイルに切り出し、デスクトップと iOS で共有する。設計としてはきれいだが、差分が大きく、upstream の判断に委ねたほうがよい。PR の議論で求められたら切り替える。

### D2: パッチの当て方 — `git archive` で取り出したコピーに `git apply` する

`git -C third_party/piper-plus archive HEAD` で `build/piper-ios/src/` にツリーを取り出し、`patches/piper-plus/*.patch` を名前順に `git apply` する。CMake はこのコピーに対して実行する。サブモジュールの作業ツリーには触れない。

- パッチは upstream PR のコミットから `git format-patch` で作る。
- 当たらなければ即座に失敗する。成果物は一時ディレクトリで組み立て、最後に `ios/Frameworks/` へ移す。そのため失敗しても既存の成果物は壊れない。
- upstream が修正をリリースしたら、サブモジュールを新しいタグに上げる。パッチが当たらなくなるか空になるので、それを合図にパッチを削除する。

代替案 1: サブモジュールに直接 `git apply` し、ビルド後に `git apply -R` で戻す。途中で失敗すると作業ツリーが汚れたまま残る。
代替案 2: フォークに切り替える(audio.cpp と同じ方式)。iOS のためだけにフォークを持つ維持費が見合わない。

### D3: ライブラリの形 — upstream の静的 archive を、自前で動的 framework に包む

各 SDK でビルドした `libpiper_plus.a` を、`clang++ -dynamiclib` で動的ライブラリにリンクし直す。指定するオプションは次のとおり。

- `-Wl,-force_load`
- `-framework onnxruntime`(`-F` で SDK に合う ORT スライスを指す)
- `-install_name @rpath/piper_plus.framework/piper_plus`
- `-Wl,-exported_symbol,_piper_plus_*`
- `-mios-version-min=15.0` / `-mios-simulator-version-min=15.0`

できたバイナリを、`Info.plist` と一緒に flat な `piper_plus.framework` に包み、`xcodebuild -create-xcframework` でまとめる。

- 公開シンボルを `piper_plus_*` に絞る。静的 archive には visibility が効かないため、fmt / spdlog / OpenJTalk のシンボルがそのまま外に出てしまい、ORT など他の framework と衝突する恐れがあるからである。
- `PiperNativeBindings` は、macOS / Windows と同じく `DynamicLibrary.open` で開く(iOS では `piper_plus.framework/piper_plus`)。

代替案 1: Runner に静的リンクし、`DynamicLibrary.process()` で参照する。リンカが未参照のシンボルを削る恐れがあり、Runner のリンク設定(`-force_load`)を pbxproj に書く必要もある。irodori の D4 と同じ理由で採らない。
代替案 2: upstream の CMake を書き換え、iOS でも SHARED でビルドする。パッチが大きくなり、upstream の「iOS は static」という方針とぶつかる。

### D4: ONNX Runtime — CDN の xcframework を iOS の arm64 スライス 2 つに絞って作り直す

CDN の zip を SHA-256 で検証して展開する。そのうえで次の 2 つを、`xcodebuild -create-xcframework` で `ios/Frameworks/onnxruntime.xcframework` にまとめ直す。

- `ios-arm64/onnxruntime.framework`(そのまま使う)
- `ios-arm64_x86_64-simulator/onnxruntime.framework`(`lipo -thin arm64` で arm64 だけにする)

macOS スライスと x86_64 は捨てる。ビルド時に使う ORT のヘッダと framework も、この展開物から CMake に渡す。upstream CI と同じ `ONNXRUNTIME_*` 変数を使う。

- 成果物(実機と Simulator を合わせて約 65MB の見込み)は Git で管理しない。`ios/Frameworks/*.xcframework` を `.gitignore` に入れ、iOS で TTS を使う開発者が `scripts/build_piper_ios.sh` で各自ビルドする。macOS の dylib は Git で管理しているので前例とは異なるが、リポジトリの肥大を避けることを優先した(ユーザ判断)。同梱フェーズは xcframework が無ければ何もしないので、ビルドしていないチェックアウトでもビューアのビルドは壊れない。
- 展開した ORT スライスの `Info.plist` から `MinimumOSVersion` を読む。Runner の deployment target(15.0)を超えていれば、Runner をその値に引き上げる(`ios-build-target` の最小 OS の要件)。
- ORT の install name は `@rpath/onnxruntime.framework/onnxruntime` のまま使う。Runner の `LD_RUNPATH_SEARCH_PATHS` にある `@executable_path/Frameworks` から解決される。piper_plus の依存も同じ名前で解決される。

代替案: ORT を SPM(`onnxruntime-swift-package-manager`)で入れる。Flutter が生成する SPM の構成にパッケージを手で足すことになり、`ios-build-target` の「SPM は Flutter プラグイン由来のみ」という前提を崩す。ビルド時に参照する ORT と実行時の ORT が別経路になる点も避けたい。

### D5: 同梱の仕組みは irodori の Run Script フェーズをそのまま取り込む

`7cfb3573` と `5835525d` のフェーズ(`Embed Native Frameworks`)を取り込む。これらのコミットは `openspec/changes/irodori-ios-build/` や audiocpp 用のスクリプトにも触れている。そのため cherry-pick はせず、`git checkout <commit> -- <path>` で必要なファイルだけを取り込む。このフェーズはエンジンの名前を含まず、xcframework の `Info.plist` からスライスを選ぶので、2 つの xcframework に対してそのまま動く。

- piper_plus は onnxruntime に依存するが、どちらも同じ `Frameworks/` に置かれ、`dlopen` 時に dyld が解決する。そのため同梱する順序は問わない。
- deployment target のガードテスト(`4295a0b4`)も取り込む。ただし、テストが期待する値は 16.3 ではなく、現在の 15.0 に合わせる。`d8f4d9d0`(16.3 への引き上げ)は取り込まない。

### D6: 合成の確認は integration test で行い、モデルはアプリのダウンロード処理で取得する

`integration_test/piper_ios_synthesis_test.dart` を置く。iOS 以外ではスキップする。

- **モデル**
  - `Documents/models/` に Piper のモデルと辞書が無ければ、`PiperModelDownloadService` で取得する(合わせて約 100MB 未満の見込み)。
  - Irodori のときは 1.5GB 以上あったので Finder で事前に置いたが、今回はその手間が要らない。
  - ダウンロード処理もアプリと同じものを通るので、iOS 上でのパス解決と書き込みも同時に確かめられる。
- **経路**: `TtsIsolate` に Piper エンジンを読み込ませ、アプリと同じ FFI と isolate の経路を通す。
- **音素化の確認**: `piper_plus_phonemize` で「こんにちは、世界。」を音素化し、日本語の音素(OpenJTalk 由来の `k o N n i ch i w a` 系)が返ることを確かめる。ピンインや空の結果は不合格とする。問題の本体は音素化なので、合成結果が無音でないことだけでは証拠として弱い。
- **確認する文**
  - かな交じりの短文と中文
  - 漢字だけの文(「多分。」)
  - 中文を 10 回続けて合成
- **合否**: 音声が無音でないことと、強制終了しないこと。
- **記録**
  - 次の値を `reportData` と `Documents/benchmarks/piper_ios_<timestamp>.json` に出力する。
    - モデルの読み込み時間
    - 各文の合成時間と RTF
    - `ProcessInfo.maxRss`
    - `os_proc_available_memory`
  - 開発者はこれを `benchmarks/` に持ち帰る。
- **実行方法**: Simulator でも実機でも `flutter drive` を使う。`flutter test` は終了時にアプリをアンインストールしてデータごと消すので、毎回モデルを取得し直すことになる。`flutter drive` ならモデルが残る。
  - Simulator: `fvm flutter drive --driver=test_driver/integration_test.dart --target=integration_test/piper_ios_synthesis_test.dart -d <sim>`
  - 実機: `fvm flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/piper_ios_synthesis_test.dart -d <UDID>`(`flutter test` が使う JIT のデバッグビルドは、iPadOS 26 の実機では起動直後に強制終了される)

**次の change(`ios-tts-piper`)に進む条件**
1. Simulator と実機の両方で、日本語の合成テストが成功する。
2. 実機での中文の平均 RTF が 1.0 以下である。
3. 実機で連続合成している間、`os_proc_available_memory` が常に 1GiB 以上ある。

### D7: upstream PR

D1 と同じ内容の PR を ayutaz/piper-plus の `dev` に出す。PR を出すことは本 change のタスクに含めるが、取り込まれることは完了条件にしない。PR の URL はパッチの先頭に書く。PR を出すまでは、仮に「upstream PR 未提出」と書いておく。

## Risks / Trade-offs

- [パッチを当てた iOS ビルドで、`_api` 経路が依存する別のシンボル(dictionary_manager の内部関数など)がリンクできない] → 最初のタスクで Simulator スライスだけをビルドし、リンクと日本語の音素化を確かめる(スパイク)。うまくいかなければ、D1 の代替案 2(ファイルの切り出し)に切り替える。
- [辞書をパスでしか解決しないことで、upstream の他の利用者(Swift の SPM 利用者)の挙動が変わる] → iOS は現状まったく動かないので、悪くなる利用者はいない。PR の説明にそう明記する。
- [`-exported_symbol` で絞った結果、C API の内部から参照されるシンボルが解決できなくなる] → 公開範囲を絞るのはエクスポートだけで、リンク時の解決には影響しない。検証スクリプトで `piper_plus_*` がすべて公開されていることを確かめ、integration test で実際に呼び出す。
- [ORT 1.20.0 の CDN の配布物が差し替えられる、または消える] → SHA-256 の照合で検知する。成果物を Git で管理しないので、配布物が消えると新しいチェックアウトでは iOS 向け TTS をビルドできなくなる。そのときは ORT のバージョンを upstream に合わせて上げる。
- [成果物を Git で管理しないため、チェックアウトしただけでは iOS 版に TTS のライブラリが入らない] → `docs/ipad.md` にビルド手順を書く。後続の `ios-tts-piper` で UI を有効にする際は、ライブラリを読み込めないときに TTS を隠すかどうかを検討する。
- [upstream が別の方式(たとえば Swift の OpenJTalk バインディング)で直す] → パッチは当たらなくなるか不要になり、D2 の手順で削除する。C API が変わらなければ、アプリ側の変更は無い。
- [無料プロビジョニングの再署名が 7 日ごとに要る] → テストは再実行できるので、影響は小さい。

## Migration Plan

- 本 change の時点では iOS の TTS の UI は非表示のままなので、利用者に見える変化は無い。iOS 版アプリのサイズだけが増える。
- 元に戻すときは、`ios/Frameworks/` の xcframework を削除すればビューアだけのビルドに戻る。同梱フェーズは、xcframework が無ければ何もしない。
- upstream に取り込まれたら、次の手順で移行する。
  1. サブモジュールを修正の入ったタグに上げる。
  2. `patches/piper-plus/` を削除する。
  3. `scripts/build_piper_ios.sh` と macOS / Windows のビルドを実行する。
  4. 検証スクリプトと integration test を通す。

## スパイクの結果(2026-10-17、タスク 1)

- **パッチの実装**: D1 の方針どおり。wrapper では `find_openjtalk_binary()` を iOS 用の `return NULL` 版に差し替え、`execute_openjtalk_argv` は `piper_run_argv` を呼ばないようにした。dictionary_manager では `verify_checksum` と `download_and_extract_dictionary` を `#ifndef` で外し、`ensure_openjtalk_dictionary` は Android と同じく失敗を返す。スタブには、ビルドから外れたままの `openjtalk_optimized.c` のシンボルだけを残した(スタブを参照している upstream の CI があるので、ファイル自体は残す)。マクロは `PIPER_PLUS_APPLE_EMBEDDED` とし、upstream の `PIPER_PLUS_EMBEDDED_*` の命名に合わせた。
- **デスクトップ**: 修正前も修正後も、`ctest` は 51/51 通った。
- **iOS Simulator(iPad mini A17 Pro, iOS 27.0)**: 最小の C ハーネスを `xcrun simctl spawn` で実行した。
  - パッチあり: `piper_plus_phonemize("こんにちは、世界。")` は `lang=ja`、18 音素を返した。「こんにちは、世界。」(rms 0.136)と「多分。」(rms 0.202)はどちらも無音ではない音声になった。
  - パッチなし(対照): 音素は 0 個、合成結果は 0 サンプルだった。
- **ライブラリ**: `-force_load` で包んだ dylib(ORT 込みで約 29MB)は、`piper_plus_*` 以外のシンボルを公開しなかった。`nm -u` には `popen` / `system` / `posix_spawn` 系のシンボルが無かった。
- **ONNX Runtime について、D4 の前提が誤っていた**: Microsoft の CDN が配る 1.20.0 の `onnxruntime.framework` は、upstream の文書にある動的ライブラリではなかった。中身は静的ライブラリ(ar アーカイブ。`prelinked_objects.o` を 1 つ含む)で、`minos 13.0` だった。そのため、ORT を独立した動的 framework として同梱することはできない。スパイクでは piper_plus の dylib に静的にリンクした。この扱いは別途決める。

## Open Questions

- 中文の RTF が 1.0 を超えた場合の対策(CoreML EP、`intra_op_num_threads` の調整、文の分割を短くする)。D6 の計測結果を見て `ios-tts-piper` で決める。
