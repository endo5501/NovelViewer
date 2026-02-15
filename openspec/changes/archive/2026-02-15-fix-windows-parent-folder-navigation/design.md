## Context

`file_browser_panel.dart` の `_navigateToParent()` メソッドがパス区切り文字 `/` をハードコードしている。Windowsではパスが `C:\Users\name\novels` のようにバックスラッシュを使うため、`lastIndexOf('/')` が `-1` を返し、親フォルダへの遷移が失敗する。

プロジェクトでは既に `path` パッケージ (`package:path/path.dart`) を `p` としてインポートし、他の箇所（`file_system_service.dart` 等）でクロスプラットフォームのパス操作に使用している。コミット 57e958c でも同様のハードコード問題が `p.join()` で修正された前例がある。

## Goals / Non-Goals

**Goals:**

- `_navigateToParent()` を `path` パッケージの `p.dirname()` を使ったクロスプラットフォーム対応に修正する
- ルートディレクトリ（`/` や `C:\`）に達した場合にそれ以上遡らないようにする
- Windowsパスを想定したユニットテストを追加する

**Non-Goals:**

- ファイルブラウザ全体のリファクタリング
- 他のパス操作箇所の修正（今回のスコープ外）
- ネットワークパス（UNC パス）のサポート

## Decisions

### `p.dirname()` を使用する

**選択**: `currentDir.substring(0, currentDir.lastIndexOf('/'))` を `p.dirname(currentDir)` に置き換える。

**理由**: `p.dirname()` はプラットフォームのパスセパレータを自動認識し、ルートディレクトリの処理も適切に行う。プロジェクト内で既に `path` パッケージが使われており、一貫性がある。

**代替案**:
- `Platform.pathSeparator` を使って手動分割 → `p.dirname()` の方がエッジケース対応が堅牢
- 正規表現で `/` と `\` 両方を検出 → 不要な複雑さ

### ルートディレクトリ到達の判定

**選択**: `parent != currentDir` でルート到達を判定する。

**理由**: `p.dirname()` はルートディレクトリに対して同じパスを返す（例: `p.dirname('/')` → `/`、`p.dirname('C:\')` → `C:\`）。この性質を利用すれば、プラットフォーム固有のルート判定ロジックが不要になる。

## Risks / Trade-offs

- **[リスク] テストでのパスセパレータ差異** → Flutterのテスト環境はテスト実行プラットフォームのセパレータを使用するため、Windowsパスのテストは実際のWindows環境で実行する必要がある。`p.dirname()` の動作はプラットフォーム依存なので、テストケースではこの点を考慮する。
- **[リスク] 既存テストへの影響** → `p.dirname()` は既存の `/` ベースパスでも正しく動作するため、Mac/Linux環境での既存テストに影響なし。
