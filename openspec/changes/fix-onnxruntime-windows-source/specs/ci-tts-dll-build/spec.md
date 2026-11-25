# Spec Delta

## ADDED Requirements

### Requirement: Windows用 ONNX Runtime を NuGet から版とハッシュを固定して取得する

`scripts/build_piper_windows.bat` は cmake の実行前に ONNX Runtime を準備しなければならない（MUST）。
- 取得元: NuGet の `Microsoft.ML.OnnxRuntime`。GitHub Releases は使ってはならない（MUST NOT）。
- 版: piper-plus の CMake（`cmake/find_onnxruntime_windows.cmake` の `ONNXRUNTIME_VERSION`）が指定する版と同一でなければならない（MUST）。
- 照合: 取得したパッケージの SHA256 を、版ごとに固定した値と照合しなければならない（MUST）。
- 置き方: win-x64 のヘッダー・`onnxruntime.lib`・`onnxruntime.dll`・`LICENSE` を `onnxruntime-win-x64-<版>/{include,lib,LICENSE}` のレイアウトにまとめる。これを zip にし、`third_party/piper-plus/build/onnxruntime/onnxruntime.zip` として置かなければならない（MUST）。

取得を省略してよいのは、この zip が既に存在し、かつ zip として読めて、その版の `onnxruntime-win-x64-<版>/` の必要なファイルを含む場合だけでなければならない（MUST）。
それ以外の場合（空ファイル、壊れた zip、別の版の zip）は、作り直さなければならない（MUST）。
`third_party/piper-plus/build/onnxruntime/` 配下に別の版の展開ディレクトリが残っている場合は、それを削除しなければならない（MUST）。
x64 以外のアーキテクチャの DLL を `third_party/piper-plus/build` 配下に置いてはならない（MUST NOT）。

#### Scenario: NuGet から取得して既存レイアウトで置く
- **WHEN** `third_party/piper-plus/build/onnxruntime/onnxruntime.zip` が存在しない状態で Piper TTS DLL ビルドステップを実行する
- **THEN** zip が作られ、中に `onnxruntime-win-x64-<版>/include/onnxruntime_cxx_api.h`、`lib/onnxruntime.lib`、`lib/onnxruntime.dll`、`LICENSE` が含まれる
- **AND** cmake の configure は GitHub からの ONNX Runtime ダウンロードを行わない

#### Scenario: 版は piper-plus の CMake に従う
- **WHEN** piper-plus の `ONNXRUNTIME_VERSION` が `X.Y.Z` である
- **THEN** 取得するパッケージの版は `X.Y.Z` であり、zip 内のディレクトリ名は `onnxruntime-win-x64-X.Y.Z` である

#### Scenario: ハッシュが一致しない場合はエラー
- **WHEN** 取得したパッケージの SHA256 が固定値と一致しない
- **THEN** ビルドステップはエラー終了し、`onnxruntime.zip` は作られない

#### Scenario: ハッシュが未登録の版はエラー
- **WHEN** piper-plus の `ONNXRUNTIME_VERSION` に対応する SHA256 が登録されていない
- **THEN** ビルドステップはエラー終了し、ハッシュの追加が必要であることを示す

#### Scenario: その版の zip が既にあれば取得しない
- **WHEN** `third_party/piper-plus/build/onnxruntime/onnxruntime.zip` が既に存在し、その版の必要なファイルを含む
- **THEN** パッケージの取得を行わずに次の処理へ進む

#### Scenario: 使えない zip は作り直す
- **WHEN** 既存の `onnxruntime.zip` が空、zip として読めない、または別の版のものである
- **THEN** パッケージから zip を作り直し、別の版の展開ディレクトリは削除される

### Requirement: Piper TTS DLL ビルドスクリプトは途中の失敗で止まる

`scripts/build_piper_windows.bat` は、ONNX Runtime の準備、cmake configure、cmake build のいずれかが失敗した場合、ただちに非0で終了しなければならない（MUST）。

#### Scenario: ONNX Runtime の準備に失敗するとビルドしない
- **WHEN** ONNX Runtime の準備が失敗する
- **THEN** スクリプトは cmake を実行せずに非0で終了する
