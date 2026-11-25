# Spec Delta

## MODIFIED Requirements

### Requirement: Piper関連ライセンスファイルをリリースに含める

piper-plus（MIT）のライセンスファイルを `PIPER_LICENSE_MIT.txt` として、onnxruntime（MIT）のライセンスファイルを `ONNXRUNTIME_LICENSE_MIT.txt` として、リリースビルド出力ディレクトリにコピーしなければならない（MUST）。onnxruntime のライセンスファイルは、ビルドに使った NuGet パッケージ `Microsoft.ML.OnnxRuntime` に同梱の `LICENSE` でなければならない（MUST）。

#### Scenario: piper-plusライセンスがコピーされる
- **WHEN** ライセンスコピーステップが実行される
- **THEN** `build/windows/x64/runner/Release/PIPER_LICENSE_MIT.txt` が存在し、内容は `third_party/piper-plus/LICENSE.md` と同一である

#### Scenario: onnxruntimeライセンスがコピーされる
- **WHEN** ライセンスコピーステップが実行される
- **THEN** `build/windows/x64/runner/Release/ONNXRUNTIME_LICENSE_MIT.txt` が存在し、内容はビルドに使った NuGet パッケージ `Microsoft.ML.OnnxRuntime` に同梱の `LICENSE` と同一である
