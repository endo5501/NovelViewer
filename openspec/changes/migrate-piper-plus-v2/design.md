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
- `BUILD_TESTS` は既定のまま(gtest の取得が走らないこと)をビルドログで確認する。

### D9. Windows のビルドスクリプトは DLL 名だけを変える

`-DPIPER_PLUS_BUILD_SHARED=ON --target piper_plus` に変え、`build\Release\piper_plus.dll`(見つからなければ `build\piper_plus.dll`)を runner の出力ディレクトリへコピーする。ONNX Runtime DLL の探索は今の再帰検索のままでよい。`release.yml` の DLL 存在検証と、ONNX Runtime のライセンスを探すグロブ(`onnxruntime-win-*`)は v2 のディレクトリ構成で通るかを確認し、必要なら直す。

## Risks / Trade-offs

- [C API 経由の合成結果が CLI 経由と違う可能性がある(探索の実測は CLI で行った)] → `piper_plus_synthesize` は内部で同じ `textToAudioFloat` を通る。とはいえ実装タスクの中で、C API 経由(アプリ実機)で旧モデルが合成できることを手動確認する手順を設ける。
- [英単語を含む文で、v1.8 と読み飛ばし方が変わる可能性がある(どちらも CMU 辞書なしで動く)] → 統合確認で英語交じりの文を v1.8 と聴き比べる。CMU 辞書の同梱は別の change の候補とする。
- [合成音声の末尾や長さが v1.8 と少し変わる(EOS trim 修正、本家の推論改善)] → 仕様どおりの変化として受け入れる。実機確認で、聴いて違和感がないかを判断する。
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
