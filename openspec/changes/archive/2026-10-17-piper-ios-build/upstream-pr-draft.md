# upstream PR の下書き(未提出)

ayutaz/piper-plus への PR として準備した文面。本家は GitHub の PR をタスク管理の仕組みの一部として使っているように見えるため、いきなり PR を出すのは控え、文面だけをここに残す(2026-10-17、ユーザ判断)。提出するときは、本家の運用(Issue を先に立てるか、`/create-pr` 相当の手順があるか)を確かめてから出す。

- 差分: `patches/piper-plus/0001-ios-enable-openjtalk.patch`(作業ブランチ `ios-enable-openjtalk`、`third_party/piper-plus` の worktree `build/piper-plus-patch-work`、ベースは v2.0.2 = `f90333e3`)
- 提出時は `dev` に rebase する。v2.0.2 以降に `src/cpp/openjtalk_*.c` や `cmake/PiperCommon.cmake` が変わっていれば、衝突を解消する
- PR タイトルは本家の慣例(日本語、Conventional Commits の接頭辞)に合わせる

---

**タイトル:** fix(ios): iOS で OpenJTalk をプロセス内で動かし、日本語を音素化できるようにする

## Summary

iOS(Apple embedded)向けのビルドでは、`openjtalk_wrapper.c` と `openjtalk_dictionary_manager.c` がビルド対象から外れています。そのうえ `openjtalk_ios_stub.c` の `openjtalk_is_available()` が常に 0 を返すため、`dict_dir` に辞書を渡しても日本語の文から音素が得られず、合成結果は 0 サンプルになります。

実際に App Sandbox で禁止されている処理(外部プロセスの起動)を使っているのは、バイナリ版へのフォールバックと、辞書のダウンロード・チェックサム確認だけです。主経路は r9y9/open_jtalk の C ライブラリをプロセス内で呼んでおり、iOS でも動きます。この PR では、この 2 ファイルを iOS でもビルドし、プロセスを起動する部分だけを `PIPER_PLUS_APPLE_EMBEDDED` で外します。辞書は Android と同じく、`dict_dir` / `OPENJTALK_DICTIONARY_PATH` で渡してもらう前提です。

## Affected Components

- [ ] Python (src/python/, pyproject.toml)
- [ ] Rust (src/rust/)
- [ ] C# (src/csharp/)
- [x] C++ (src/cpp/, CMakeLists.txt)
- [ ] Go (src/go/)
- [ ] WASM/npm (src/wasm/)
- [ ] Docker (docker/)
- [ ] CI/CD (.github/workflows/)
- [ ] Documentation (docs/, README*)

## Type

- [x] Bug fix
- [ ] New feature
- [ ] Refactoring
- [ ] Documentation
- [ ] CI/CD
- [ ] Dependencies

## Risk Level

- [x] **patch** — bug fix / internal refactor / docs only
- [ ] **minor** — new feature / additive API / no breaking change
- [ ] **major** — breaking change (API removal, schema migration, behavior reversal)

デスクトップ(Linux / macOS / Windows)と Android のビルドは、コンパイルされる内容が変わりません。変更が効くのは `PIPER_APPLE_EMBEDDED` のときだけです。

## Contract Impact

- [x] None (Python/runtime-internal change only)

## 変更内容

- `cmake/PiperCommon.cmake`
  - `PIPER_APPLE_EMBEDDED` のとき、`openjtalk_wrapper.c` と `openjtalk_dictionary_manager.c` もビルドする。
  - その場合に限り、コンパイル定義 `PIPER_PLUS_APPLE_EMBEDDED` を付ける(`PIPER_PLUS_EMBEDDED_*` の命名に合わせた)。
- `src/cpp/openjtalk_wrapper.c`
  - iOS では、`find_openjtalk_binary()` を常に `NULL` を返す版に差し替える。そのため、バイナリ版へのフォールバックは何も起動せずに失敗する。
  - `execute_openjtalk_argv()` は iOS では `piper_run_argv()` を呼ばない。
  - バイナリのパスを持つためのスレッドローカル変数とミューテックスは、iOS では定義しない(未使用変数の警告を出さないため)。
- `src/cpp/openjtalk_dictionary_manager.c`
  - iOS では `verify_checksum()` と `download_and_extract_dictionary()` をビルドしない。
  - `ensure_openjtalk_dictionary()` は、辞書が無ければ Android と同じ案内を出して失敗を返す。
- `src/cpp/openjtalk_ios_stub.c`
  - wrapper と dictionary_manager が実体を持つようになったので、それらのスタブを削除する。
  - ビルド対象外のままの `openjtalk_optimized.c` のシンボル(`openjtalk_text_to_phonemes_optimized`)だけを残す。
  - CI(`cpp-tests.yml`)がこのファイルの単体コンパイルを確かめているので、ファイル自体は残す。

## Test Plan

**デスクトップ(macOS arm64):** `cmake -B build -DBUILD_TESTS=ON && cmake --build build -j && ctest --test-dir build` を実行した。修正前も修正後も 51/51 が通った。

**iOS Simulator(iPad mini A17 Pro、iOS 27.0、arm64):** `cmake/ios.toolchain.cmake` でビルドした。ORT は CDN の 1.20.0、`-DCMAKE_OSX_DEPLOYMENT_TARGET=15.0` を指定した。`libpiper_plus.a` と ORT をリンクした最小の C プログラムを、`xcrun simctl spawn` で実行した。モデルは tsukuyomi-chan-6lang-fp16 で、`dict_dir` には `open_jtalk_dic_utf_8-1.11` を渡した。

| | 修正前(v2.0.2 そのまま) | 修正後 |
|---|---|---|
| `piper_plus_phonemize("こんにちは、世界。", "ja")` | `lang=ja`、0 音素 | `lang=ja`、18 音素 |
| 「こんにちは、世界。」の合成 | 0 サンプル | 30522 サンプル(rms 0.136) |
| 「多分。」の合成 | 0 サンプル | 11636 サンプル(rms 0.202) |

**iPad 実機(iPad mini A17 Pro、iPadOS 26.6.2):** 修正後のライブラリを動的 framework としてアプリに組み込んだ。音素化は `ja` で 18 音素。中程度の長さの文(8.4 秒)の合成は約 0.25 秒(RTF 0.03)、ピーク RSS は 361MiB だった。

**未定義シンボル:** iOS 向けの `libpiper_plus.a` の `nm -u` に、`popen` / `system` / `posix_spawn` / `fork` / `exec*` は現れなかった。

## Checklist

- [x] Tests pass locally
- [x] No GPL/LGPL dependencies added ([License Policy](../CONTRIBUTING.md#license-policy))
- [ ] Documentation updated (if applicable)

ドキュメントについて: `docs/guides/platform/ios-integration.md` の Step 4 は、「辞書を同梱して `dict_dir` を渡せば日本語を合成できる」としています。この PR で、ようやくその記述どおりに動くようになります。ただし Troubleshooting 表の「iOS stub returns NULL when `dict_dir` is unset」は、スタブではなく dictionary_manager の挙動を指すようになるので、文言の更新が必要かもしれません。本家の書き方に合わせたいので、この PR では触れていません。

## 補足(この PR の範囲外)

iOS への組み込み中に、ドキュメントと実物の食い違いに気づきました。`docs/reference/ios-shared-lib.md` §2.1 では、CDN の `pod-archive-onnxruntime-c-1.20.0.zip` に入っている `onnxruntime.framework/onnxruntime` は動的ライブラリとされています。しかし手元で確かめたところ(SHA-256 `50891a8a…`、2026-10-17)、中身は静的ライブラリ(ar アーカイブ、`prelinked_objects.o`、`minos 13.0`)でした。`file` の出力は `current ar archive random library` です。

## Related Issues

#377(iOS の配布形式。スタブのコメントが参照している Issue)
