## MODIFIED Requirements

### Requirement: Build artifacts packaged as ZIP
ビルド成果物（exe、DLL、data/ディレクトリ）をZIPファイルに固めなければならない（SHALL）。ZIPファイル名にはタグ名を含めなければならない（SHALL）。

#### Scenario: ZIP creation with version in filename
- **WHEN** `v1.2.3` タグでビルドが完了する
- **THEN** `novel_viewer-windows-x64-v1.2.3.zip` という名前のZIPファイルが作成される

#### Scenario: ZIP contains all required files
- **WHEN** ZIPファイルが作成される
- **THEN** ZIPには `novel_viewer.exe`、`flutter_windows.dll`、`sqlite3.dll`、`qwen3_tts_ffi.dll`、`data/` ディレクトリが含まれる
