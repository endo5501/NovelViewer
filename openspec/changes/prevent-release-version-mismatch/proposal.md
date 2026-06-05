## Why

リリースは「git タグ」と「`pubspec.yaml` の `version`」という 2 つの独立した値からバージョンが決まっており、両者が一致しているかを誰も検証していない。`pubspec.yaml` の更新を忘れてタグだけを push すると、Release 名やインストーラは新バージョン（例: `v1.2.0`）になる一方、バイナリに焼き込まれた `PackageInfo.version` は旧バージョン（例: `1.1.0`）のままになる。その結果、インストール済みアプリが自分を旧バージョンと認識し、`isNewer` 判定で常に「アップデートあり」を出し続ける壊れた Release が公開されてしまう。

## What Changes

- **新規**: ローカルのリリース実行スクリプト `scripts/release.ps1`（PowerShell）と `scripts/release.sh`（bash）を追加する。引数 `X.Y.Z` を受け取り、以下を一括実行する。
  - 事前検証: 引数が `X.Y.Z` 形式 / 作業ツリーが clean / `main` ブランチ / タグ `vX.Y.Z` が未使用 / 新バージョンが現バージョンより後退していないこと
  - `pubspec.yaml` の `version` を `X.Y.Z+(N+1)`（N は現ビルド番号）に書き換える
  - commit → `git tag vX.Y.Z` → `git push`（main とタグ）
- **修正**: `.github/workflows/release.yml` の冒頭に「タグ == `pubspec.yaml` の version」を照合する検証ステップを追加し、不一致なら `exit 1` してビルド・Release 公開を行わない（保険）。
- ビルド番号 `N` は表示用であり更新判定には影響しない（`version_comparator.dart` の `_stripBuild` がビルドメタを除去するため）。スクリプトでは単調に +1 する。

## Capabilities

### New Capabilities
- `release-version-guard`: ローカルでリリース手順（バージョン更新・commit・tag・push）を一括実行し、タグと `pubspec.yaml` の不整合や不正なリリース状態を push 前に防ぐスクリプト群。

### Modified Capabilities
- `github-actions-release`: リリースワークフローに、ビルド前にタグと `pubspec.yaml` の version 整合性を検証し、不一致なら失敗させる要件を追加する（公開前の最終防御）。

## Impact

- 追加: `scripts/release.ps1`, `scripts/release.sh`
- 変更: `.github/workflows/release.yml`（先頭に検証ステップ追加）
- 変更（ドキュメント）: `.claude/CLAUDE.md`, `README.md` / `README_en.md` / `README_zh.md`（リリース手順を release スクリプト推奨に更新）
- 影響なし（挙動は変えない）: `pubspec.yaml` の version 体系、`lib/features/app_update/` の更新判定ロジック
- 開発フロー: 今後のリリースは原則 release スクリプト経由で行う運用に変わる
