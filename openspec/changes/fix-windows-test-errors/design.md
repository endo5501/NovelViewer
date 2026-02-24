## Context

TTSモデルダウンロード機能で、`TtsModelDownloadService.resolveModelsDir()` は Dart の `path` パッケージ（`p.join`, `p.dirname`）を使用してパスを組み立てている。これらの関数はプラットフォームに応じたセパレーターを使用するため、Windows では `\`、macOS では `/` が返される。

一方、テストコードでは期待値のパスを文字列補間（`'${tempDir.path}/models'`）でハードコードしており、常に `/` を使用している。`tempDir.path` 自体がWindowsでは `C:\Users\...\` のような `\` を含むパスを返すため、結果として `C:\Users\...\temp_dir/models` のような混在パスが期待値となり、実際の出力 `C:\Users\...\temp_dir\models` と一致しない。

## Goals / Non-Goals

**Goals:**
- Windows と macOS の両方で6つの失敗テストをパスさせる
- テストの期待値をプラットフォーム非依存な方法で構築する

**Non-Goals:**
- 実装コード（`tts_model_download_service.dart`, `tts_model_download_providers.dart`）の変更
- パスセパレーターの正規化ロジックの追加（実装は既に正しい）
- TTS機能以外のテストの修正

## Decisions

### Decision 1: テスト期待値で `p.join()` を使用する

テストの期待値で文字列補間 `'${tempDir.path}/models'` の代わりに `p.join(tempDir.path, 'models')` を使用する。

**理由:** 実装コードが `p.join` を使用しているため、テストの期待値も同じメカニズムで組み立てることで、プラットフォームによらず一致する。

**却下した代替案:**
- `Platform.pathSeparator` を使った文字列結合 → `p.join` の方がシンプルで読みやすい
- 期待値のパスを正規化（すべて `/` に変換）→ 実装コードの出力を変えることになり不適切
- UI テストで `contains` マッチャーを使用 → テストの精度が下がる

### Decision 2: UIテストでは `find.textContaining` を使用する

`tts_model_download_ui_test.dart` では、パスがUIウィジェット内のテキストとして表示される。`find.text('${tempDir.path}/models')` の代わりに `find.textContaining(p.basename(modelsPath))` や `find.textContaining('models')` を使用するか、あるいは `p.join` で組み立てた正しいパスを `find.text` に渡す。

**理由:** UIに表示されるパスは実装コードが生成したものであり、テスト側の期待値も同じパス構築メソッドを使うべき。

## Risks / Trade-offs

- [Low] `path` パッケージの `import` 追加が必要 → 既に実装コードで使われているパッケージであり、追加のリスクはない
- [Low] macOSでのテスト結果に影響する可能性 → `p.join` はmacOSでも同じ動作をするため影響なし
