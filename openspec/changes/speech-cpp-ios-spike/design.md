## Context

動機は proposal.md の Why を参照。ここでは方針を決めるのに要る現状だけを書く。

- `main` には Piper の iOS 対応で入った次の仕組みがある。`ios/Frameworks/*.xcframework` を走査して同梱・署名する `Embed Native Frameworks` フェーズ（`ios-build-target`）、`.gitignore` の `/ios/Frameworks/*.xcframework`、`integration_test/piper_ios_synthesis_test.dart` と `test_driver/integration_test.dart`、`os_proc_available_memory` と `ProcessInfo.maxRss` を段階ごとに記録するレポート（`integration_test/piper/piper_ios_report.dart`）。
- iOS Runner の `IPHONEOS_DEPLOYMENT_TARGET` は 15.0。
- scratchpad での事前検証（2026-10-24、speech.cpp 0.8.11 / `d074e1b`）で、次のことがわかっている。
  - speech.cpp は CMake の標準的な iOS クロスコンパイルで、手を加えずにビルドできる。`-DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF -DGGML_BLAS=OFF`、ターゲットは `speech`（共有ライブラリ）のみ。最小 OS 15.0 でもビルドでき、バイナリの minos は 15.0 になる。成果物は約 8 MB で、依存はシステムのフレームワークだけ。公開シンボルは `speech_*` の118個だけ（上流の CMake が `-exported_symbol,_speech_*` を指定している）。
  - mac での計測値は proposal.md の Why のとおり。MF モデルは `incremental = no`（全部作ってから音声を返す）で、オプションは `voice`（必須、`none` か追加した参照音声）、`seed`、`speed`、`seconds`、`duration_scale`、`steps`（既定 4）、`instructions` など。`max_seconds` は無い。
- `irodori-ios-build` の実機計測で得た知見：実機の integration test は `flutter drive --profile` でなければ起動直後に強制終了される。実機テストのインストールでアプリのデータが消えたことがある。

## Goals / Non-Goals

**Goals:**
- iPad mini 実機で、speech.cpp + Irodori-TTS v4.1 Small MF が、量子化ごとにメモリ上限内で実用的な速度で合成できるかを、事前に定めた基準で判定できる計測結果を得る
- 後続 change（アプリへの統合）がそのまま使える、ビルドスクリプト・検証スクリプト・バインディングを残す

**Non-Goals:**
- バインディングを `TtsEngine` 系の抽象や `TtsIsolate` に組み込むこと（後続 change で、計測結果を見てから設計する）
- デスクトップ（macOS / Windows）向けの speech.cpp のビルド
- 音声の品質（声の似方・読みの正確さ）の自動判定。計測で保存した WAV を人が聞いて確認する

## Decisions

### D1: upstream の speech.cpp を直接 submodule にする（フォークしない）

`third_party/speech.cpp` に `https://github.com/nyosegawa/speech.cpp` の `d074e1b`（0.8.11）を置く。ggml は speech.cpp 自身の submodule（`nyosegawa/ggml` の `cbdeccf`）を使う。CI の checkout は既に `submodules: recursive` なので、入れ子の submodule も取得される。

- 既存の qwen3-tts.cpp と audio.cpp は、中断 ABI や長さ補正などのパッチを持つため自前のフォークを参照している。speech.cpp は、計測に要る機能（中断 `speech_request_cancel`、参照音声、Metal）が upstream の C API に揃っており、iOS ビルドにも変更が要らなかったため、フォークは保守コストを増やすだけである。
- 代替案：自前のフォークを作る案。パッチが必要になった時点で作ればよく、今は採らない。

### D2: framework の名前を `speech_cpp` にする

成果物は `speech_cpp.xcframework` / `speech_cpp.framework/speech_cpp`、install name は `@rpath/speech_cpp.framework/speech_cpp` とする。上流のライブラリ名 `libspeech.dylib` をコピーするときに名前を変え、`install_name_tool -id` で install name を書き換える。

- iOS には Apple の `Speech.framework` がある。大文字と小文字を区別しないファイルシステムや dyld の探索で `speech.framework` と取り違えると、原因のわかりにくい読み込み失敗になる。既存の `piper_plus` / `audiocpp_ffi` と同じく、プロジェクトに固有の名前にする。
- 代替案：上流の名前（`speech.framework`）のまま使う案。上記の衝突の恐れがあるので採らない。

### D3: 最小 OS は Runner と同じ 15.0 にする

`CMAKE_OSX_DEPLOYMENT_TARGET=15.0` でビルドし、framework の `MinimumOSVersion` も 15.0 とする。Runner の設定は変更しない。

- 事前検証で 15.0 でビルドでき、minos が 15.0 になることを確認した。audio.cpp では float の `std::to_chars` を使っていたため 16.3 が必要だったが、speech.cpp のソースは使っていない。
- 代替案：16.3 に上げる案。理由が無いので採らない。対象端末は iPadOS 26 なので、どちらでも計測には影響しない。

### D4: ビルドスクリプトは `build_piper_ios.sh` と同じ構成にする

SDK ごとにビルドディレクトリを分けて2回ビルドし、それぞれのライブラリを flat な `.framework`（バイナリ + `Info.plist`）に包んでから、`xcodebuild -create-xcframework` でまとめる。ビルドディレクトリは submodule の外（`build/speech-ios/`）に置き、submodule の作業ツリーを汚さない。xcframework はまず一時ディレクトリに作り、成功したときだけ `ios/Frameworks/` の既存のものと置き換える（失敗したときに既存の成果物を壊さないため）。

- 検証スクリプト `scripts/test/verify_speech_ios.sh` も `verify_piper_ios.sh` の項目立てに合わせ、Metal シェーダーの埋め込み（`kernel void` の文字列）を加える。シェーダー名（`kernel_mul_mat` など）は、mac で動いているライブラリでも文字列として見つからなかったため、検査に使わない。

### D5: バインディングは計測に要る C API だけを、アプリ本体と同じ場所に置く

`lib/features/tts/data/speech_cpp_native_bindings.dart` に置く。後続 change でアプリに統合するときに、そのまま使えるようにするためである。アプリ本体からはまだ参照しない。

対象の関数：`speech_version`、`speech_status_name`、`speech_last_error`、`speech_load_params_*`（new / free / set_device / set_threads）、`speech_model_load` / `speech_model_free`、`speech_model_get_info` / `speech_model_info_free` / `speech_model_info_sample_rate`、`speech_voice_add`、`speech_option_from_name`、`speech_request_new` / `speech_request_free` / `speech_request_set_text` / `speech_request_set_string` / `speech_request_set_int`、`speech_request_cancel`、`speech_synthesize`。

- **オプションは名前で指定する。** `speech_option_from_name` で実行時に識別子を求める。`speech_option` の番号はヘッダの版（3.x）で増えており、Dart 側に数値を固定すると、submodule を更新したときに黙って別のオプションを設定してしまう。
- **音声のコールバックは isolate ローカルにする。** `speech_synthesize` は、呼び出したスレッドの上で同期的に `on_audio` を呼ぶ。そのため `Pointer.fromFunction`（isolate ローカル）でサンプルを受け取り、`Float32List` に連結する。`NativeCallable.listener` は非同期に配送されるため、合成の終了とサンプルの到着の順序が保証されず、使わない。
- **中断は別の isolate から行う。** `speech_synthesize` は呼び出した isolate を塞ぐ。計測テストでは合成を専用の isolate で行い、合成の前にリクエストのアドレスを `SendPort` で主 isolate に渡す。主 isolate はそのアドレスに対して `speech_request_cancel` を呼ぶ（ヘッダは、リクエストが生きている間、どのスレッドから呼んでもよいと定めている）。リクエストを解放するのは、合成した isolate が合成から戻った後だけとする。
- **失敗は状態名と詳細で報告する。** 負の `speech_status` を受けたら、`speech_status_name` と `speech_last_error`（スレッドローカル）を読んで例外にする。読む前に別の speech.cpp の呼び出しを挟まない。中断（`SPEECH_CANCELLED`）は、状態名で判別して専用の結果にする。
- 代替案：C のラッパー（shim）を書いて Dart からの呼び出しを単純にする案。framework の外に C のコードが増え、ビルドが2段になる。C API が既に Dart から直接呼べる形（不透明ポインタ・状態値・C のコールバック）なので採らない。

### D6: 計測テストは量子化を1つずつ、小さいものから実行する

量子化は `--dart-define=SPEECH_CPP_VARIANT=q4_k|q8_0|f16` で選ぶ（既定は `q4_k`）。1回の `flutter drive` で1つだけ計測する。`ProcessInfo.maxRss` はプロセスの中で単調に増えるため、1回の実行で複数の量子化を読み込むと、後の量子化のピーク値が意味を持たなくなるからである。手順書では Q4_K → Q8_0 → F16 の順に実行する。大きい量子化で強制終了されても、小さい量子化の結果は先に得られている。

モデルは `sakasegawa/Irodori-TTS-v4.1-Small-MF-GGUF` のリビジョン `9db7da1bec3d1069ef8e29732e0497be60c7b047` から取得し、次の値で照合する（第三者のリポジトリなので、サイズだけでなく SHA-256 も固定する）。置き場所は、アプリのモデルディレクトリ（`modelsDirectoryPathProvider`）の下の `speech-cpp/Irodori-TTS-v4.1-Small-MF/` とする。

| 量子化 | ファイル | バイト数 | SHA-256 |
|---|---|---|---|
| Q4_K | `Irodori-TTS-866M-MF-v4.1-Q4_K.gguf` | 863926048 | `1913bf74000a3300c703eb91c985a4e5c4d7a2bbeb0cc7fe07d1583c4fea9729` |
| Q8_0 | `Irodori-TTS-866M-MF-v4.1-Q8_0.gguf` | 1207133984 | `2d161b0bbcd74f906f6b07e03d031075f8ae916db1b8bd4daf16cb37b451086a` |
| F16 | `Irodori-TTS-866M-MF-v4.1-F16.gguf` | 1920321792 | `e237dc3eefe469b8bba87872beacf12fb7fe00dbdf85767edca8ec04ab910d13` |

取得は `package:http` のストリーミングで `.part` に書き、照合してから名前を変える。既存のダウンロードサービスは対象のモデルが決まっているため流用せず、計測テストの補助コードとして持つ。後続 change でダウンロード UI を作るときに、既存のサービスに倣って作り直す。

### D7: 参照音声は、テストの中で作って使う

最初に `voice=none`（モデルが自分で声を選ぶ）で短い文を `seed` 固定で合成し、その音声を 48 kHz・16bit の WAV として `Documents/benchmarks/` に保存する（中程度の文と125字の文の合成結果も同じ場所に保存し、後で人が聞いて確かめる）。それを `speech_voice_add` で `ref` という名前で追加し、以降の合成はすべて `voice=ref` で行う。

- アプリの Irodori の使い方（参照音声つきの合成）と、mac での事前計測の条件を揃えるためである。参照音声を足すと、話者の特徴を求める処理とそのメモリが加わる。
- 音声ファイルをリポジトリやテストのアセットに持たずに済む。WAV の書き出しは既存の `wav_writer.dart` を使う。
- 代替案：mac で作った参照音声をアセットとして同梱する案。ライセンスの確認とアセットの管理が増えるので採らない。

### D8: 判定基準は計測の前に固定する

spec「計測結果を事前に定めた基準で判定する」のとおり、完走・メモリの余裕 512 MiB 以上・125字の文の RTF 1.0 未満を基準とする。

- 512 MiB：アプリ本体（Flutter の UI、テキスト表示）と、後続 change で加わる再生・ストリーミングのバッファの分を残すための値。前回の audio.cpp v3 は、読み込んだ後の余裕が約 1.4 GiB で、合成中に 1.6 GiB を確保しようとして落ちた。
- RTF 1.0 未満：アプリの読み上げは、次の文の合成を再生中に済ませる（`tts-streaming-pipeline`）。合成が再生より速くなければ、文の間で再生が途切れる。mac では RTF が約 0.07 だったので、iPad で何倍か遅くても通る見込みだが、基準は実用の下限にする。
- 全体で合格した量子化のうち、最も精度の高いもの（F16 > Q8_0 > Q4_K）を、後続 change の第一候補とする。どれも合格しなければ、ここで撤退し、design.md にその判断を記録する。

### D9: Simulator ではライブラリの読み込みだけを確かめる

speech.cpp の Metal 推論は実機でしか動かないとされている（irodori-tts-iphone の README）。Simulator の Metal の制約に起因する失敗を、計測の結果と混同しないため、Simulator では framework を開いて `speech_version` を読むだけにする。モデルの取得（約 0.9〜1.9 GB）も行わない。

実装中に、この判断を裏づける事象を確認した（2026-10-24、iOS 26.5 Simulator）。最初の実装は環境変数 `SIMULATOR_DEVICE_NAME` で Simulator を判定していたが、アプリのプロセスにはこの変数が渡されない。そのため Simulator でもモデルを読み込み、`speech_model_load` → `ggml_metal_buffer_set_tensor` → Simulator の Metal ドライバ（`MTLSimDevice newBufferWithLength`）の中の `_xpc_api_misuse` でプロセスが止められた。判定は、Simulator がアプリを置く `.../Library/Developer/CoreSimulator/Devices/` を実行ファイルのパス（`Platform.resolvedExecutable`）に含むかどうかで行う。

## Risks / Trade-offs

- [mac と iPad でメモリの数え方が違う] → 判定は iPad 実機の `os_proc_available_memory`（強制終了までの余裕）で行い、mac の数値は見込みとしてだけ使う。
- [F16 の計測で強制終了され、`flutter drive` が結果を受け取れない] → レポートを段階ごとにデバイスに書き直す（Piper の計測と同じ）。結果は `devicectl device copy from` で取り出す。
- [実機テストのインストールでアプリのデータが消える] → 実機で実行する前に `Documents/` と `Library/` をバックアップし、ユーザーの了承を得てから実行する（tasks に独立した手順として置く）。
- [計測のたびに最大 1.9 GB をダウンロードする] → 一致するファイルがあれば再取得しない。ただし、インストールでデータの領域が作り直されると再取得になる。Wi-Fi 環境での実行を前提とする。
- [モデルが `Documents/` の下に置かれ、ファイル App から見える] → 既存の Piper のモデルと同じ扱いである。計測の後に不要なら手順書に従って削除する。置き場所の見直しは、後続 change のモデル保存場所の検討で扱う。
- [upstream の speech.cpp は更新が速い（10月だけで 0.8.x が続いている）] → submodule をコミットで固定し、更新は別の作業として、ビルドと検証スクリプトをやり直してから行う。
- [バインディングがアプリ本体から使われないまま残る] → 後続 change で統合しないと決めたときは、その change で削除する。

## Migration Plan

アプリの挙動は変わらない（iOS の TTS は Piper のみのまま）。xcframework は Git 管理外で、無くてもビューアと Piper はビルドできる。やめるときは、submodule・スクリプト・バインディング・計測テストを削除すれば元に戻る。

## Open Questions

- 中断を何ミリ秒後に送れば、確実に合成の途中に当たるか。合成時間は実機で測るまでわからないので、中程度の文の合成時間を測ってから、その半分程度の時点で送る（テストの中で前の段階の計測値から決める）。
