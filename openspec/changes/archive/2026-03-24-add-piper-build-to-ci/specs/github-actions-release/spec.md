## MODIFIED Requirements

### Requirement: Build artifacts packaged as ZIP
ビルド成果物（exe、DLL、data/ディレクトリ）をZIPファイルに固めなければならない（SHALL）。ZIPファイル名にはタグ名を含めなければならない（SHALL）。

#### Scenario: ZIP creation with version in filename
- **WHEN** `v1.2.3` タグでビルドが完了する
- **THEN** `novel_viewer-windows-x64-v1.2.3.zip` という名前のZIPファイルが作成される

#### Scenario: ZIP contains all required files
- **WHEN** ZIPファイルが作成される
- **THEN** ZIPには `novel_viewer.exe`、`flutter_windows.dll`、`sqlite3.dll`、`qwen3_tts_ffi.dll`、`piper_tts_ffi.dll`、`onnxruntime.dll`、`data/` ディレクトリが含まれる

## ADDED Requirements

### Requirement: Piper関連ライセンスファイルをリリースに含める

piper-plus（MIT）のライセンスファイルを `PIPER_LICENSE_MIT.txt` として、onnxruntime（MIT）のライセンスファイルを `ONNXRUNTIME_LICENSE_MIT.txt` として、リリースビルド出力ディレクトリにコピーしなければならない（MUST）。

#### Scenario: piper-plusライセンスがコピーされる
- **WHEN** ライセンスコピーステップが実行される
- **THEN** `build/windows/x64/runner/Release/PIPER_LICENSE_MIT.txt` が存在し、内容は `third_party/piper-plus/LICENSE.md` と同一である

#### Scenario: onnxruntimeライセンスがコピーされる
- **WHEN** ライセンスコピーステップが実行される
- **THEN** `build/windows/x64/runner/Release/ONNXRUNTIME_LICENSE_MIT.txt` が存在し、内容はonnxruntimeダウンロード先のLICENSEファイルと同一である
