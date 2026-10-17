# Design

## Context

動機は proposal.md の Why を参照。現状と、探索段階で確かめた制約は次のとおり。

- **呼び出し経路**: `TtsIsolate` → `PiperTtsEngine` → `PiperNativeBindings` → ネイティブライブラリ。エンジンは isolate 内で同期的に呼ばれ、`loadModel` の直後に `setLengthScale` / `setNoiseScale` / `setNoiseW` が呼ばれる(`tts_isolate.dart`)。Piper の設定値(`TtsEngineConfig`)は 3 パラメータとも必須なので、アプリからは常に値が渡る。
- **フォークの C API**: 実体は `piper::initialize` / `loadVoice` / `textToAudio` の薄いラッパーである。パラメータはコンテキストが保持し、合成結果(int16)を float32 に変換してコンテキスト内に置く。言語 ID は v1.8 の `piper.cpp` で 0 に固定されている(旧モデルの `language_id_map` では `ja: 0`)。
- **本家 v2.0.2 の C API**(`src/cpp/piper_plus.h`、API version 1):
  - `piper_plus_create(&PiperPlusConfig, &engine)` は失敗するとエラーステータスと NULL を返す。
  - `piper_plus_synthesize(engine, text, &opts, &samples, &n, &sr)` は呼び出し側が所有する float32 バッファを返し、`piper_plus_free_audio` で解放する。
  - エラーは `piper_plus_get_last_error()` で取得する。保存先は `thread_local` なので、エンジン単位ではなくスレッド単位になる。
  - `PiperPlusSynthOptions` の既定値は noise 0.4 / length 1.0 / noise_w 0.5 / 文間無音 0.2 秒 / language_id -1(自動判定)。
  - 共有ライブラリは `PIPER_PLUS_BUILD_SHARED=ON` のときだけビルドされる。出力名は `piper_plus` で、macOS では VERSION/SOVERSION が付く(`libpiper_plus.2.0.2.dylib` / `libpiper_plus.1.dylib` のシンボリックリンク群)。
- **ONNX Runtime**: 本家 CMake が 1.20.0 を取得する(v1.8 は 1.14.1)。macOS では `build/ort/lib`、Windows では `build/onnxruntime/onnxruntime-win-*` に置かれる。
- **モデル互換性(実測済み)**: ピン留め中のモデル(eb9b882)の ONNX 入力は `input / input_lengths / scales / lid / prosody_features` である。v2.0.2 はセッションの入力名を見て送る入力を決める。v2.0.2 CLI で日本語文を合成したところ、エラーも音素欠落の警告も出なかった。
- **EOS trim と旧モデル(実装中に判明)**: v2.0.2 は合成のたびに文末の EOS 区間(`ceil(durations[-1])` フレーム)を削る(`trim_helpers.hpp`、Issue #499、`TRIM_EOS_MAX_FRAMES = 0` の定数で、無効化する設定はない)。旧モデル eb9b882 は最終母音の後半を EOS 区間で生成するため、母音が削られる。実測では「彼はそういった」の最後の「た」が、v1.8 の約 100ms から約 40ms に短くなった。スクラッチ環境で trim を無効にすると v1.8 と同じ長さ(0.931 秒)に戻ることも確かめた。新しいモデル(36b59c8 / zs-v1)では、trim がかかっても最終音節は欠けない。
- **英語・中国語の音素化辞書**(`cmudict_data.json` / `pinyin_*.json`): v1.8 も v2.0.2 も、実行時にモデルのディレクトリ → 実行ファイルからの相対パス → 環境変数の順で探す。アプリはどちらも同梱していないため、英単語の部分は v1.8 でも v2.0.2 でも読み飛ばされる(実測: 「今日はGitHubでcodeを書いた。Hello world!」で、両版とも英語部分がほぼ無音)。これは移行前からある制約で、この change では変えない。言語 ID に `ja` を明示しても、v2.0.2 は文字種による区間分割を止めない(`language_id` を使うのは、ラテン系言語の既定を選ぶときだけ)。
- **OpenJTalk 辞書の自動ダウンロード**: v1.8 も v2.0.2 も、辞書が見つからないと自動でダウンロードしようとする(`PIPER_PLUS_AUTO_DOWNLOAD_DICT=0` で無効化)。アプリは取得済みを検証した `dict_dir` を必ず渡すので、この経路には入らない。挙動は移行前と同じ。
- **macOS への同梱**: Xcode の Embed フェーズは `macos/Frameworks/*.dylib` をグロブで丸ごと同梱する。そのため、Frameworks に置いたファイルがそのままバンドルの中身になる。

## Goals / Non-Goals

**Goals:**

- `PiperTtsEngine` の公開 API を変えず、上位(`TtsIsolate`、設定、UI)を一切変更しない。
- 構造体のレイアウトずれやバッファの解放漏れを、単体テスト(モックバインディング)とロード時の API バージョン検査で確実に検出できるようにする。
- 合成言語と合成パラメータについて、v1.8 と同じ挙動を保つ。

**Non-Goals:**

- 本家 C API の追加機能(ストリーミング、ユーザー辞書、音素タイミング、GPU プロバイダ)は使わない。
- 本家 v2.0.2 の C++ ソースは変更しない。パッチを当てる必要が出たら、この change を止めて方針を見直す。

## Decisions

### D1. サブモジュールの参照先を本家に変え、タグ `v2.0.2` のコミットに固定する

`.gitmodules` の URL を `https://github.com/ayutaz/piper-plus.git` に変え、サブモジュールのコミットを `v2.0.2` のコミットに合わせる。

- 他の案: フォークを本家 v2.0.2 にリベースして運用を続ける案。独自の C API が不要になった以上、フォークを残すと保守コストだけが残るので採らない。
- 本家のリポジトリにはタグが多く(docker-*、rust-* など)、clone も大きい。サブモジュールは通常どおりの checkout でよく、CI は既に `submodules: recursive` を使っている。

### D2. 合成パラメータは Dart 側で保持し、合成のたびにオプション構造体へ詰めて渡す

`PiperTtsEngine` は `lengthScale` / `noiseScale` / `noiseW` を nullable のフィールドとして持つ。`synthesize()` では次の順でオプションを組み立てる。

1. `piper_plus_default_options()` で既定値の構造体を受け取る
2. 設定されているパラメータだけを上書きする
3. `language_id` を設定する(D3)
4. `synthesize` に渡す

予約領域(`_reserved`)は既定値の構造体のものをそのまま使うため、Dart 側でゼロ埋めし忘れる心配がない。

- 他の案: Dart 側で構造体をゼロから組み立てる案。本家が既定値を変えたときに追従できず、予約領域をゼロにする責任も Dart 側に移るので採らない。
- 未設定時の既定値は v1.8(モデル config の 0.667 / 0.8)と v2(0.4 / 0.5)で異なる。ただしアプリからは常に 3 値が渡るので(Context 参照)、ユーザーから見える差は出ない。spec では「未設定時は本家の既定値」と定めた。

### D3. 合成言語はロード時に一度だけ `ja` の ID を引き、以後の合成に使う

`loadModel` が成功したら `piper_plus_language_id(engine, "ja")` を呼び、結果をフィールドに保存して毎回の `language_id` に使う。`ja` が見つからない場合、関数は -1 を返すので、それがそのまま自動判定の指定になる。

- 他の案 A: v2 の既定である自動判定(-1)に任せる案。日本語の小説では大半が `ja` と判定されるはずだが、英数字だけの文や記号だけの行で判定が揺れうる。v1.8 との挙動差を持ち込む理由がないので採らない。
- 他の案 B: ID を 0 にハードコードする案。モデルの `language_id_map` に依存したマジックナンバーになるので採らない。

### D4. 合成結果のバッファは try/finally で必ず解放する

`synthesize()` はネイティブ呼び出しの出力として `Pointer<Pointer<Float>>` / `Pointer<Int32>` ×2 を `calloc` で確保する。返ってきたバッファが非 NULL なら、`Float32List.fromList(ptr.asTypedList(n))` でコピーしてから、finally で `free_audio` を呼ぶ。サンプル数 0 を例外にする判定は、コピーの前でも後でもよいが、解放は必ず finally に置く。

- モックバインディングは `free_audio` の呼び出し回数と渡されたポインタを記録する。テストでは「ちょうど 1 回、返したポインタで呼ばれた」ことを確かめる(spec: Native audio buffer ownership)。

### D5. エラーメッセージは失敗した呼び出しの直後に同期的に取得する

`piper_plus_get_last_error()` は `thread_local` に保存される。Dart の isolate は、イベントループのターンが変わると別の OS スレッドで動くことがある。ただし「ネイティブ呼び出し → ステータス判定 → エラー取得」が同じ同期区間(`await` を挟まない)にあれば、同じスレッドで実行される。そのため、エラー取得は必ずステータス判定の直後に置き、間に `await` を入れない。現状の `PiperTtsEngine` は完全に同期なので、この形は自然に守られる。

### D6. ロード時に C API バージョンを検査する

`loadModel` の冒頭で `piper_plus_api_version()` を呼び、1 以外ならエンジンを作らずに `TtsEngineException` を投げる。FFI の構造体レイアウトは `PIPER_PLUS_API_VERSION 1` の `piper_plus.h` に合わせて手書きしている。サブモジュールを将来上げたとき、ABI が変わったまま気づかずに合成すると、メモリ破壊として表に出る。ロード時に止めて原因を明示する。

### D7. FFI バインディングは手書きし、ffigen は導入しない

使う関数は 8 個程度で、構造体は 2 つだけである。既存の `TtsNativeBindings` / `IrodoriNativeBindings` も手書きなので、それに揃える。

- 構造体の定義(`final class PiperPlusConfig extends Struct`):
  - フィールドは `Pointer<Utf8>` ×3 → `Int32` ×2 → `Pointer<Utf8>` → `@Array(7) Array<Int32>` の順で、ヘッダと完全に一致させる。
  - `PiperPlusSynthOptions` は `Int32` ×2 → `Float` ×4 → `Pointer<Float>` → `Int32` → `@Array(5) Array<Int32>`。
- `piper_plus_default_options()` は構造体を値で返す。`dart:ffi` は構造体の値返しに対応しているので、そのまま受け取ってから `calloc<PiperPlusSynthOptions>()` にコピーし、ポインタで渡す。

### D8. macOS のビルドスクリプトは、シンボリックリンクを実体化した unversioned 名だけを Frameworks に置く

`cmake --build ... --target piper_plus` の後、次の手順で配置する。

1. `cp -L build/libpiper_plus.dylib macos/Frameworks/libpiper_plus.dylib` でシンボリックリンクを実体化してコピーする。
2. `install_name_tool -id @rpath/libpiper_plus.dylib` で自身の install name を書き換える。本家の既定は SOVERSION 付きの `@rpath/libpiper_plus.1.dylib` になるはずだが、`otool -D` で確認する。
3. ONNX Runtime への参照を `install_name_tool -change` で `@rpath/libonnxruntime.dylib` に揃える。
4. ONNX Runtime も今と同じく `cp -L` で unversioned 名に実体化する。

あわせて、古いビルドの残骸を消す。具体的には、Frameworks に残っている `libpiper_tts_ffi.dylib` をスクリプトが削除する。Embed フェーズはグロブで同梱するので、残しておくと同梱集合の検証(`verify_macos_bundle.sh`)で検出される。

- `-DCMAKE_OSX_ARCHITECTURES=arm64` と CPU のみのビルド(`USE_CUDA` OFF)は現状どおり。
- **最低対応 OS は 13.3 にする**(実装中にユーザーと決定)。本家が取得する ONNX Runtime 1.20.0 のビルド済みバイナリは最低対応が macOS 13.3 で、これが Piper の実際の下限になる。指定しないと CMake はビルドしたマシンの OS(今回は 27.0)を使う。そのため `MACOSX_DEPLOYMENT_TARGET=13.3` を export し、`-DCMAKE_OSX_DEPLOYMENT_TARGET` にも同じ値を渡す。export が必要なのは、OpenJTalk / fmt / spdlog が ExternalProject でビルドされ、親の CMake キャッシュ変数を引き継がないため。アプリの deployment target 12.0 を下回らないのは ONNX Runtime 側の制約である。他の同梱 dylib(qwen3 / audiocpp / lame)は既に最低対応が 26.0 なので、実際の動作要件は変わらない。他のビルドスクリプトの最低対応の扱いはこの change の範囲外とする。
- `BUILD_TESTS` は既定のまま(gtest の取得が走らないこと)をビルドログで確認する。

### D9. Windows のビルドスクリプトは DLL 名だけを変える

`-DPIPER_PLUS_BUILD_SHARED=ON --target piper_plus` に変え、`build\Release\piper_plus.dll`(見つからなければ `build\piper_plus.dll`)を runner の出力ディレクトリへコピーする。ONNX Runtime DLL の探索は今の再帰検索のままでよい。`release.yml` の DLL 存在検証と、ONNX Runtime のライセンスを探すグロブ(`onnxruntime-win-*`)は v2 のディレクトリ構成で通るかを確認し、必要なら直す。

### D10. モデルのピン留めを 36b59c8 に更新する(実装中にユーザーと決定)

EOS trim はランナーの固定の後処理で、C API からは変えられない。旧モデルを使い続けるには、本家にパッチを当てる(フォークに戻る)か、本家に設定の追加を依頼するしかない。そこで、ランナーが想定しているモデルの側を合わせる。

- 採用: `36b59c825c36bd386b8960cf3f604382f52f2a87`(2026-06-13)。MB-iSTFT-VITS2 デコーダで、`phoneme_id_map` の PUA 修正後の版。ファイル名(`tsukuyomi-chan-6lang-fp16.onnx`)と config の取得パス(リポジトリ直下の `config.json`)は eb9b882 と同じなので、変更は `modelRevision` の値だけで済む。config の推論既定値(0.667 / 0.8)もアプリの設定の既定値と同じ。
- 他の案 A: zs-v1(2026-10-14)。パスとファイル名が変わり(`releases/zs-v1/tsukuyomi.onnx`)、推論の既定値も 0.4 / 0.5 に変わる。そのためダウンロード処理と設定の初期値まで見直す必要があり、quality も `experimental` なので見送る。
- 他の案 B: 本家に、EOS trim を無効にするオプションの追加を依頼する。取り込まれるまで移行が止まるので見送る。
- 既存ユーザーへの影響: 完了マーカーには eb9b882 が記録されているので、`areModelsDownloaded()` が不一致と判定する。アプリは読み上げ開始時と設定画面で再ダウンロードを促す(既存の仕組みで、追加の実装は不要)。

### D11. 漢字だけの文は、zh を除いた config で日本語として読ませる(実装中にユーザーと決定)

本家の `UnicodeLanguageDetector`(`language_detector.cpp:281-284`)は、モデルが ja と zh の両方を持つとき、漢字を「文中にかながあれば ja、なければ zh」と判定する。指定した言語 ID は判定に使われない。アプリは pinyin 辞書を同梱しないので、「多分。」「「父様。」「失敗失敗。」のような文は音素「.」だけになる。36b59c8 の対応表では「.」の ID がないため、ID 列は空になる。v1.8 ではこれが無音になっていた(移行前からの品質問題)。

判定に使う言語の集合は、config の `language_id_map` のキーから作られる。そこで `PiperTtsEngine.loadModel` は、ダウンロード済みの `<model>.onnx.json` を読み、`ja` と `zh` の両方があれば `zh` だけを除いた config を `<model>.onnx.ja.json` に書き出し、`PiperPlusConfig.config_path` に渡す。他の言語の ID は変わらないので `lid` の値も変わらない。`num_languages` も別のフィールドなので変わらない。実験では、3 文とも日本語の音素(「多分」→ `t a [ b u N`)になった。

- 他の案 A: `[[ 音素 ]]` 記法で、日本語として音素化した結果を渡す。日本語の韻律情報(A1/A2/A3)が失われるので採らない。
- 他の案 B: 本家の判定で、指定した言語を使うよう修正を依頼する。本来はこれが筋なので、issue の提案はユーザーの判断で別途行う。取り込まれたら D11 は外せる。
- リスク: 判定が `language_id_map` のキーに依存するという本家の内部挙動を前提にしている。→ 実物の dylib を使うテスト(「多分。」が日本語の音素で合成できる)で固定し、サブモジュールを更新したときに気づけるようにする。
- 書き出しに失敗した場合(ディスクが一杯など)は、ダウンロードした config のままで読み込みを続ける。漢字だけの文の改善は失われるが、Piper 自体は使える(Codex のレビューで指摘された)。
- 中国語の文は日本語の音読みで読まれる。日本語の小説を読み上げるアプリとしては、無音よりよい。

### D12. 発音できない文は合成せず、0.2 秒の無音を返す(実装中にユーザーと決定)

v2.0.2 は、ID 列が空でもそのまま推論を実行し、ONNX Runtime の `Invalid input shape: {0}` で失敗する。v1.8 は同じ文で無音(約 0.27 秒)を返していた。英語だけの文(「Hello world.」)も同じ経路に入る。

`synthesize()` は合成の前に `piper_plus_phonemize(engine, text, "ja")` を呼び、返った音素(空白区切り)のうち、config の `phoneme_id_map` に載っているものが 1 つもなければ、ネイティブの合成を呼ばずに 0.2 秒の無音(`sampleRate × 0.2` 個の 0)を返す。`phoneme_id_map` のキーは `loadModel` のときに config から読んでおく。

- 0.2 秒は、本家の文間の無音の既定値(`sentence_silence_sec`)と同じ長さ。
- 他の案 A: 専用の例外を投げ、ストリーミング・一括生成・編集画面の各経路で「スキップ」として記録する。経路ごとの変更が増え、v1.8 との挙動の差も大きくなるので採らない。
- 他の案 B: 合成を呼んで `PIPER_PLUS_ERR_ORT` が返ったら無音にする。ORT のエラーを一括りに握りつぶすことになるので採らない。
- 音素化を 2 回(事前の確認と合成)行うコストは、1 文あたり数 ms 以下なので無視できる。
- `piper_plus_phonemize` が返すポインタは借用で、次の呼び出しまでしか有効でないので、その場で Dart の文字列にコピーする。

## Risks / Trade-offs

- [C API 経由の合成結果が CLI 経由と違う可能性がある(探索の実測は CLI で行った)] → `piper_plus_synthesize` は内部で同じ `textToAudioFloat` を通る。とはいえ実装タスクの中で、C API 経由(アプリ実機)で旧モデルが合成できることを手動確認する手順を設ける。
- [英単語を含む文で、v1.8 と読み飛ばし方が変わる可能性がある(どちらも CMU 辞書なしで動く)] → 統合確認で英語交じりの文を v1.8 と聴き比べる。CMU 辞書の同梱は別の change の候補とする。
- [モデル更新で Piper の声質が変わる] → ユーザーが聴き比べたうえで 36b59c8 を選んだ。統合確認で、日本語の読み上げを改めて聴いて確認する。
- [ONNX Runtime 1.20.0 で macOS の最低 OS バージョン要件が上がる可能性がある] → ビルド後に `otool -l` で `LC_BUILD_VERSION` の minos を確認し、アプリの deployment target(macOS)を超えていないかを見る。
- [サブモジュールの URL 変更で、既存の clone の `.git/config` に旧 URL が残る] → `git submodule sync --recursive` の実行を README のビルド手順と tasks に入れる。
- [既存の `third_party/piper-plus/build` の CMake キャッシュが新しいソースツリーと合わない] → ビルドスクリプトは既存の build ディレクトリを使い回す作りである。そのため移行時は build ディレクトリを削除して作り直すよう tasks で明示する。スクリプト側でキャッシュの食い違いを検出する仕組みは入れない(1 回限りの移行のため)。
- [Windows の実ビルドは macOS 開発機から確認できない] → CI の release ワークフローは タグ push でしか走らない。そのため Windows 機での手動ビルド、または `workflow_dispatch` 相当の確認を最終確認の前に行う。

## Migration Plan

1. サブモジュールを切り替え(`.gitmodules` 更新 → `git submodule sync` → v2.0.2 を checkout)、build ディレクトリを作り直す。
2. ビルドスクリプトを更新して macOS でビルドし、`otool` で install name と依存を確認する。
3. Dart のバインディングとエンジンを TDD で書き換える。
4. アプリを実機で起動し、Piper で日本語の読み上げができることを確認する。
5. Windows でビルドを確認する。

**ロールバック**: サブモジュールの参照、ビルドスクリプト、Dart のバインディングを 1 つのブランチで一緒に戻せば、v1.8 構成に復帰できる。ユーザーのデータ(モデル、辞書、設定)の形式は変えないので、データ側の巻き戻しは不要。
