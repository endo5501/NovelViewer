## Why

現在、NovelViewerのWindows向けバイナリを配布する手段がなく、ビルドは完全にローカル手動で行っている。GitHub Actionsを使ってタグpush時に自動ビルド・ZIP化・GitHub Releasesへの公開を行うことで、Windows向けの配布フローを確立する。

## What Changes

- GitHub Actionsワークフローファイルを追加し、タグ（`v*`）push時にWindows releaseビルドを実行
- ビルド成果物（exe + DLL + data/）をZIPに固めてGitHub Releasesに自動アップロード
- `fvm` の代わりに `subosito/flutter-action` でFlutter stable環境をセットアップ

## Capabilities

### New Capabilities
- `github-actions-release`: GitHub Actionsによるタグトリガーの自動ビルド・ZIP化・GitHub Releases公開ワークフロー

### Modified Capabilities
（なし）

## Impact

- `.github/workflows/` ディレクトリにワークフローYAMLファイルが追加される
- 既存のアプリケーションコードへの変更はなし
- GitHub Actions（Windows runner）の利用が開始される（publicリポジトリのため無料枠内）
