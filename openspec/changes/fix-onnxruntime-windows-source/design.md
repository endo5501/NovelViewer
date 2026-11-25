# Design

## Context

piper-plus の `cmake/find_onnxruntime_windows.cmake` は、Windows では次の順で ONNX Runtime を用意する（動機は proposal.md「Why」参照）。

1. 探索パス（`${PIPER_PHONEMIZE_DIR}/lib`、`build/_deps/onnxruntime-src/lib` など）で探す。このプロジェクトでは、ここで見つかったことはない。
2. 見つからなければ、`build/onnxruntime/onnxruntime.zip` が**無いときだけ**ダウンロードする（49行）。
3. その zip を `build/onnxruntime/` に展開し、`onnxruntime-win-x64-<ver>/{include,lib/onnxruntime.lib,lib/onnxruntime.dll}` を使う（66–78行）。

この展開レイアウトに依存しているものが、ほかに2つある。
- `scripts/build_piper_windows.bat`: `dir /s /b` で `build` 配下の `onnxruntime.dll` を探してコピーする。
- `release.yml`: `build/onnxruntime/onnxruntime-win-*/LICENSE` をライセンスとしてコピーする。

NuGet の `Microsoft.ML.OnnxRuntime` 1.20.0 の中身は次のとおり。
- `build/native/include/*.h`: 9本。GitHub 版にあった `onnxruntime_training_*.h` 3本は無いが、piper-plus の `src/cpp` は include していない。
- `runtimes/<rid>/native/`: win-x64 / win-x86 / win-arm64 などの各アーキテクチャ版。
- 直下の `LICENSE`、`ThirdPartyNotices.txt`。

win-x64 の `onnxruntime.dll` / `.lib` とヘッダーのサイズは、GitHub 版と一致した。

## Goals / Non-Goals

**Goals:**
- サブモジュール（piper-plus）を書き換えずに、ローカルと CI の両方で同じ経路を通す。
- CMake には、これまでの成功ビルドと同じ分岐（zip 展開）を通らせる。

**Non-Goals:**
- ONNX Runtime の版を上げること。
- GitHub Releases が戻ったときに自動で元の取得元へ戻すこと。

## Decisions

### D1: CMake が見る `onnxruntime.zip` を先に置く
置いた zip は CMake が 49 行目の分岐で使い、ダウンロードを飛ばして 66 行目以降で展開する。展開結果のレイアウトは今までと同じになる。

代替案と退けた理由:
- `-DONNXRUNTIME_LIB` / `-DONNXRUNTIME_INCLUDE_DIR` を渡す案: CMake が「piper-phonemize で見つかった」側の分岐に入る。このプロジェクトでは通したことがなく、`release.yml` のライセンスパスも変える必要がある。
- サブモジュールにパッチを当てる案: `patches/piper-plus/` は iOS 用に既にあるが、Windows のためにパッチの管理対象を増やしたくない。
- 展開済みディレクトリだけを置く案: CMake は zip が無いとダウンロードしに行くので、効かない。

### D2: 版はサブモジュールの cmake から読み、ハッシュは版ごとに固定する
`find_onnxruntime_windows.cmake` の `set(ONNXRUNTIME_VERSION "x.y.z")` を正規表現で読む。
- これでサブモジュールを更新したときも「Piper と同じ版」が保たれる。
- nupkg の SHA256 はスクリプト内の版→ハッシュ表で持つ。表に無い版は失敗させる。黙って未検証のバイナリを使わないため。
- 版を上げるときに要るのは、ハッシュを1行足すことだけになる。

### D3: nupkg は一時ディレクトリで扱い、必要なエントリだけ取り出す
nupkg には win-x86 / win-arm64 の `onnxruntime.dll` も入っている。`piper-plus/build` 配下で展開すると、`.bat` の `dir /s /b`（最後の一致を採る）が別アーキの DLL を拾うおそれがある。

そのため、nupkg は `$env:TEMP` 配下で扱い、`System.IO.Compression.ZipFile` で以下のエントリだけ取り出す。`.nupkg` 拡張子は `Expand-Archive` が受け付けないので、それを避ける意味もある。
- `build/native/include/`
- `runtimes/win-x64/native/`
- `LICENSE`、`ThirdPartyNotices.txt`

### D4: zip は `cmake -E tar --format=zip` で作る
展開する側と同じ cmake で作るので、形式の相性問題を避けられる。cmake は Windows ビルドの前提として既に PATH 上にある。

### D5: テスト用の差し替え口
スクリプトの引数で次を差し替えられるようにする。テストは偽 nupkg と偽サブモジュールで走り、ネットワークには出ない。
- `-PackageSource`: URL またはローカルパス
- `-PiperDir`
- `-HashTable`: テスト用の版とハッシュ。JSON 文字列で渡す。

## Risks / Trade-offs

- [nuget.org からも消える、または中身が変わる] → SHA256 照合で失敗に気づける。そのときは別の入手経路を検討する。
- [NuGet 版と GitHub 版のバイナリが違う] → 実装時に確認した（1.20.0）。
  - nupkg の SHA256: `36dbafacb1bc532e92d02371bd70582a61105872561fc9982314854d1c7ebf72`
  - win-x64 `onnxruntime.dll`: `52f8ebe8f08f369a44fed6d1cb680c7c89169795e1c2949ee25b88b538ef0948`
  - `onnxruntime.lib`: `99775efef44710c4fb19e644143491e1ead6a3245f0b6d9065814025d3da891e`
  - `LICENSE`: `c250d6278f0b47a6439fb7592b08b58a55eb9f535aa49a1db63211c3f982b674`
  - DLL・lib・LICENSE の3つとも、旧 GitHub 版とバイト単位で一致した。
- [ローカルに旧 GitHub 版の zip が残っていると検証が偽の成功になる] → 実ビルドでの確認は `third_party/piper-plus/build` を消してから行う。
- [108 MB のダウンロードで CI が遅くなる] → GitHub 版の zip を取っていたのと同程度なので許容する。

## Migration Plan

- 既存の作業ツリーで旧 zip が残っている場合は、それがそのまま使われる。中身は同じ版なので問題ない。
- 戻すときは、`.bat` からスクリプトの呼び出しを外せば元の挙動（GitHub から取得）に戻る。
