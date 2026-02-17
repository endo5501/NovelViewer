## Context

NovelViewerはFlutterデスクトップアプリで、Windows/macOS向けにビルドできる。現在ビルドは完全にローカル手動で行っており、配布手段がない。Windowsではポータブルレイアウト（exe横にDB・テキストファイルを配置）を採用しており、ZIPを展開するだけで動作する設計になっている。

リポジトリはGitHub上でpublic公開されており、GitHub Actionsの無料枠を十分に活用できる。

## Goals / Non-Goals

**Goals:**
- タグ（`v*`）push時にWindows releaseビルドを自動実行する
- ビルド成果物をZIPに固めてGitHub Releasesに自動アップロードする
- 手動介入なしでリリースが完了するフローを構築する

**Non-Goals:**
- macOSビルドの自動化（ローカルビルドで十分）
- インストーラー（MSIX / Inno Setup等）の作成
- 自動アップデート機能
- コード署名

## Decisions

### 1. ビルドトリガー: タグpush（`v*` パターン）

**選択**: `v1.0.0` 形式のタグpushでワークフローを発火させる。

**理由**: リリースは明示的な意思決定であり、タグpushが最も自然なトリガー。mainへのpush毎にビルドすると不要なArtifactが蓄積する。

**代替案**:
- mainへのpush毎 → 不要なビルドが多くなる
- 手動dispatch → 手間がかかり自動化のメリットが薄い

### 2. Flutter セットアップ: `subosito/flutter-action`

**選択**: `subosito/flutter-action` を使い、`.fvmrc` の設定を参照してFlutterバージョンを決定する。

**理由**: fvmはCI上では不要。`subosito/flutter-action` はFlutter CI の事実上の標準で、チャンネル指定でセットアップできる。`.fvmrc` に `"flutter": "stable"` が定義されているため、`channel: stable` を指定すればローカルと同じ環境を再現できる。

**代替案**:
- CI上でもfvmをインストール → セットアップが複雑になるだけでメリットなし

### 3. ZIP作成: PowerShell `Compress-Archive`

**選択**: Windows runner上のPowerShellでビルドフォルダをZIPに固める。

**理由**: Windows runnerにはPowerShellが標準で入っており、追加ツール不要。`Compress-Archive` で十分。

**代替案**:
- 7-Zip等をインストール → 不要な依存追加

### 4. Releases公開: `softprops/action-gh-release`

**選択**: `softprops/action-gh-release` アクションでGitHub Releasesにアップロードする。

**理由**: GitHub Releases へのアップロードに広く使われているアクション。タグからリリースノートの自動生成も対応。

**代替案**:
- `gh release create` コマンド → 動作するが、アクションのほうが宣言的で管理しやすい

### 5. ZIPファイル名にバージョンを含める

**選択**: `novel_viewer-windows-x64-v1.0.0.zip` のようにタグ名をファイル名に含める。

**理由**: ダウンロードしたユーザーがどのバージョンか一目で分かる。

## Risks / Trade-offs

- **Flutterバージョンのズレ** → `stable` チャンネル指定のため、ローカルとCIで微妙にバージョンが異なる可能性がある。ただし、stableの範囲内であれば互換性問題は稀。必要に応じて具体バージョンを `.fvmrc` にピン留めすることで対処可能。
- **Windows runner のみ** → macOSビルドが欲しくなった場合はワークフローにmacOS jobを追加する必要がある。ただしこれはNon-Goalsとして明示的に除外しており、将来の拡張として容易に対応可能。
