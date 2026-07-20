## Context

`third_party/audio.cpp` (endo5501 フォーク) は Linux / Windows 向けのビルドドキュメントのみを持ち (`docs/build/linux.md`, `docs/build/windows.md`)、macOS は上流で公式サポートされていない。`scripts/build_irodori_macos.sh` は Windows 版スクリプトを写経して書かれたもので、実行検証されていない。

本 change の調査フェーズで、実機 (Apple Silicon / macOS 25.5.0 / Homebrew CMake) にて以下を実測済み。

**現状の失敗点**

`third_party/audio.cpp/CMakeLists.txt:109` の `find_package(OpenMP REQUIRED COMPONENTS CXX)` が失敗する。AppleClang は OpenMP ランタイムを同梱せず、Homebrew の `libomp` は keg-only (`/opt/homebrew/opt/libomp` に隔離され `/opt/homebrew/lib` にリンクされない) ため CMake の既定探索パスに現れない。

**OpenMP は無効化できるか**

`audio.cpp` 自身の DSP 実装が `#pragma omp parallel for` を広範に使用している (`src/framework/audio/resampling.cpp`, `istft_graph.cpp`, `dsp.cpp`, `conversion.cpp`, `chunking.cpp`, `src/framework/sampling/torch_random.cpp` ほか)。無効化しても機能的には正しく動くが、合成のホスト側前処理・後処理が単スレッド化する。

**発見された後続問題**

1. OpenMP を共有ライブラリ (`libomp.dylib`) で解決すると、成果物が `/opt/homebrew/opt/libomp/lib/libomp.dylib` という `.app` 外の絶対パスに依存する。既存の4つの dylib (qwen3 / lame / piper / onnxruntime) はいずれもシステムフレームワーク以外に依存しておらず、一貫性を欠く。
2. `macos/Runner.xcodeproj/project.pbxproj:396-421` の `Embed Native Libraries` ビルドフェーズが `libaudiocpp_ffi.dylib` を列挙していない。このフェーズは `fvm flutter build macos` だけでなく `fvm flutter run -d macos` でも実行されるため、**バイナリ配布の有無に関わらず** dylib は `.app` に入らず、`audiocpp_native_bindings.dart:81` の `DynamicLibrary.open` が必ず失敗する。
3. model spec (`model_specs/irodori_tts.json`) を `.app` 内へ運ぶ処理が存在しない。

**model spec の解決順序** (`third_party/audio.cpp/src/audiocpp_c_api.cpp:143-159`)

```
resolve_model_spec(model_dir):
  ① dladdr(&audiocpp_init) の親ディレクトリ / model_specs / irodori_tts.json
  ② <model_dir> / irodori_tts.json
```

## Goals / Non-Goals

**Goals:**
- `scripts/build_irodori_macos.sh` が Apple Silicon 上でエラーなく完走し、Metal バックエンド有効な `libaudiocpp_ffi.dylib` を生成する
- 成果物 dylib が実行時に `.app` 外のライブラリへ依存しない (`otool -L` がシステムフレームワークのみ)
- OpenMP による並列化を有効に保つ
- `fvm flutter run -d macos` / `fvm flutter build macos` のどちらでも dylib と model spec が `Runner.app` 内に配置される
- Windows 版と同じ「ライブラリ隣に model_specs を同梱」方式に揃え、プラットフォーム間で挙動を分岐させない

**Non-Goals:**
- macOS 版のバイナリ配布、コード署名、公証 (macOS は開発者自身のローカルビルド運用)
- CI での macOS ビルド自動化 (`ci-tts-dll-build` は Windows 対象のまま)
- Intel Mac / universal binary 対応 (既存 dylib も arm64 単独)
- `third_party/audio.cpp` 本体 (submodule) への変更
- Windows ビルド経路への変更

## Decisions

### D1: OpenMP は libomp を「静的リンク」して解決する

`libomp.a` を `OpenMP_libomp_LIBRARY` に直接指定する。

```
OMP=$(brew --prefix libomp)
-DOpenMP_C_FLAGS="-Xclang -fopenmp -I$OMP/include"
-DOpenMP_CXX_FLAGS="-Xclang -fopenmp -I$OMP/include"
-DOpenMP_C_LIB_NAMES=libomp
-DOpenMP_CXX_LIB_NAMES=libomp
-DOpenMP_libomp_LIBRARY=$OMP/lib/libomp.a
```

これらは CMake の `FindOpenMP` が探索をスキップして値をそのまま採用する変数であり、`find_package(OpenMP REQUIRED)` を通過させつつリンク対象を `.a` に差し替えられる。

**実測による検証結果 (調査フェーズで確認済み)**

| 項目 | 結果 |
|---|---|
| ビルド | 終了コード 0 / `[100%] Built target audiocpp_ffi` |
| `otool -L` の libomp | 消失 (Accelerate / Metal / MetalKit / Foundation / CoreFoundation / libSystem / libc++ / libobjc のみ) |
| 未解決 OpenMP シンボル | 0 |
| 埋め込み OpenMP シンボル | 564 |
| 成果物 | arm64 / 13MB / `audiocpp_*` 13シンボルを export |

**検討した代替案**

| 案 | 判断 |
|---|---|
| `-DENGINE_ENABLE_OPENMP=OFF` で無効化 | 却下。DSP が単スレッド化し合成が遅くなる。ggml 側の `find_package(OpenMP)` は非 REQUIRED (`external/ggml/src/ggml-cpu/CMakeLists.txt:76`) なので configure は通るが、性能を捨てる理由がない |
| `-DOpenMP_ROOT=$(brew --prefix libomp)` で dylib 解決 | 却下。1行で configure は通り実測でもビルド成功したが、`.app` 外の絶対パス依存が残る |
| `libomp.dylib` を `macos/Frameworks/` に同梱し `install_name_tool -change` で `@rpath` 化 | 却下。静的リンクと同じ結果をより多くの手数 (コピー + install_name 書き換え + pbxproj への追加 + 署名対象増) で得るだけ |

**受容するトレードオフ**: 成果物が OpenMP ランタイムのシンボルを 951 個 export する。単独ロードの FFI ライブラリであり、同一プロセス内に他の OpenMP ランタイムは存在しないため実害はない。`-fvisibility=hidden` 等での抑制は費用対効果が見合わないため行わない。

### D2: libomp の存在を事前チェックし、親切に失敗させる

CMake の生エラーは原因 (Homebrew の keg-only) を示さない。スクリプト先頭で `brew --prefix libomp` の成否と `libomp.a` の実在を確認し、無ければ `brew install libomp` を案内して終了する。`set -euo pipefail` 下なので `brew --prefix` の失敗を握り潰さない書き方にする。

### D3: model spec は「dylib の隣」に置く (提案の案1)

`resolve_model_spec` の①経路を使う。`Runner.app/Contents/Frameworks/model_specs/irodori_tts.json` に配置する。

**代替案 (②経路 = `<model_dir>/irodori_tts.json`) を却下した理由**: pbxproj への追加が不要になる代わり、モデルディレクトリを用意するたびに手作業で json を置く必要が生じ、Windows (DLL 隣に同梱) と macOS で挙動が分岐する。将来のデバッグコストが上回る。

`Contents/Frameworks/` にコード以外のリソースを置くのは Bundle 規約上は非正規で、`codesign --deep` や公証で問題になりうる。ただし macOS はバイナリ配布しない (Non-Goals) ため顕在化しない。配布を始める場合は再検討する。

### D4: pbxproj は既存フェーズの拡張にとどめる

新規ビルドフェーズを作らず、既存の `Embed Native Libraries` (`DEAB09493DDFC189F4811359`) に追記する。変更は4箇所。

```
inputPaths   += ${SRCROOT}/Frameworks/libaudiocpp_ffi.dylib
outputPaths  += ${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/libaudiocpp_ffi.dylib
shellScript  : for ループの DYLIB_NAME 一覧に libaudiocpp_ffi.dylib を追加
shellScript  : model_specs ディレクトリの再帰コピー処理を追加
```

既存 `shellScript` は `if [ -f "$DYLIB_SRC" ]` でガードしているため、`libaudiocpp_ffi.dylib` を未ビルドの開発者環境でもビルドは壊れない。model_specs のコピーも同様に存在チェックで囲む。`inputPaths` に未存在ファイルを列挙するとフェーズが毎回再実行されるだけで、エラーにはならない。

### D5: Metal ライブラリの埋め込みは既定に任せる

`build_tts_macos.sh` は `-DGGML_METAL_EMBED_LIBRARY=ON` を明示しているが、`external/ggml/CMakeLists.txt:242` の既定値が `${GGML_METAL}` であり `ENGINE_ENABLE_METAL=ON` で自動的に ON になる。実測でも `ggml-metal-embed.metal` が生成され `default.metallib` の外出しは発生しなかった。明示指定は追加しない。

## Risks / Trade-offs

**[上流が macOS を公式サポートしていない]** → `docs/build/` に macos.md が無く、Metal バックエンドで Irodori のオペレータが全て実装されているかはビルド成功だけでは保証されない。ビルド完走とは別に、実機で1文合成する E2E 確認をタスクに含める。ここで未実装オペレータに当たった場合は本 change のスコープを超えるため、GPU 初期化失敗時の CPU フォールバック (`irodori-tts-native-engine` の既存要件) が機能するかを確認したうえで、別 change として切り出す。

**[Homebrew への依存]** → macOS ビルドに `brew install libomp` が必要になる。D2 の事前チェックと README への追記で吸収する。成果物側の実行時依存は増えない。

**[libomp のバージョン非互換]** → 静的リンクのため、将来 `brew upgrade libomp` で ABI が変わっても既存の成果物は影響を受けない。再ビルド時にコンパイルエラーが出る可能性は残るが、`-Xclang -fopenmp` は AppleClang の安定インターフェースであり実質的なリスクは低い。

**[pbxproj の手編集]** → Xcode GUI 経由ではなくテキスト編集するため、フォーマット崩れでプロジェクトが開けなくなる可能性がある。編集後に `xcodebuild -list -project macos/Runner.xcodeproj` でパース可能性を検証する。

**[arm64 限定]** → 既存 dylib 群も arm64 単独であり、Intel Mac は元々サポート範囲外。本 change で状況は悪化しない。
