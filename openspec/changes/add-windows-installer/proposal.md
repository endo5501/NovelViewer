## Why

現状の Windows リリースは `flutter build windows --release` の成果物を ZIP に固めて GitHub Releases に置くだけで、ユーザーは毎回 ZIP を展開し、古いフォルダと差し替えて運用する必要がある。スタートメニュー / アンインストーラ / ショートカットといった一般的なデスクトップアプリの体験がなく、フォルダごと意図せず消えてしまったり、上書きで差分が壊れたりするリスクがある。インストーラ化することで「腰を据えて長期運用できる」配布形態を提供しつつ、動作確認やポータブル用途向けに ZIP も並行配布したい。

## What Changes

- `.github/workflows/release.yml` に Inno Setup を使った Windows インストーラビルドステップを追加する。
- リポジトリに `installer/novel_viewer.iss` を新規追加する（Inno Setup 6 用スクリプト）。
- インストーラはユーザ単位インストール（`PrivilegesRequired=lowest`、`{userpf}\NovelViewer`）とし、UAC を要求しない。
- スタートメニューショートカットを常に作成し、デスクトップショートカットは Tasks セクションでオプトイン（デフォルト OFF）。
- アンインストーラを「プログラムと機能」に登録し、固定 `AppId` (GUID) で同一アプリの上書きアップグレードを可能にする。
- インストール完了後に `novel_viewer.exe` を自動起動する（postinstall, nowait）。
- ユーザデータ (`{app}\NovelViewer\` サブフォルダ) はインストーラの `[Files]` 対象外なので、更新・再インストール・アンインストールで触らない（既存設計の保全）。
- GitHub Releases の同梱物に SHA256 を追加。最終的に 4 ファイル: `novel_viewer-setup-v*.exe`、`novel_viewer-setup-v*.exe.sha256`、`novel_viewer-windows-x64-v*.zip`（既存）、`novel_viewer-windows-x64-v*.zip.sha256`（新規）。
- ZIP 版の挙動は変更しない（後続 change `add-in-app-update-check` で、ZIP 版は「ブラウザでリリースページを開く」フローに振り分ける）。
- アウトオブスコープ: コード署名（将来 SignPath.io で別途検討）、アプリ内自動更新、macOS インストーラ。

## Capabilities

### New Capabilities
- `windows-installer`: Inno Setup 6 で生成されるユーザ単位インストーラの構造・配置・アップグレード挙動・配布アーティファクトの要件を定義する。

### Modified Capabilities
- `github-actions-release`: 配布アーティファクトを ZIP 単独から「インストーラ + ZIP + 各々の SHA256」の 4 種に拡張し、Inno Setup 実行ステップと SHA256 生成ステップを必須化する。

## Impact

- **CI/CD**: `.github/workflows/release.yml` のステップ追加（Inno Setup インストール、`ISCC.exe` 実行、SHA256 生成、`softprops/action-gh-release` への追加ファイル指定）。ビルド時間が数十秒〜1分程度増加。
- **新規ファイル**: `installer/novel_viewer.iss`（Inno Setup スクリプト、約 60〜100 行を想定）。
- **アプリコード**: 変更なし。アプリ本体のビルド成果物・データ配置は一切変更しない。
- **依存追加**: ランナー上の `choco install innosetup -y`。Flutter / Dart 依存パッケージへの追加なし。
- **配布**: GitHub Releases のアセット数が増える（2 → 4）。ダウンローダや既存 ZIP リンクへの後方互換性は維持。
- **ユーザ影響**: 既存 ZIP ユーザに破壊的影響なし。インストーラ版を選んだユーザは初回のみ手動セットアップが必要で、データは `%LOCALAPPDATA%\Programs\NovelViewer\NovelViewer\` 配下に蓄積される。
- **ライセンス**: 既存の同梱ライセンス（LAME LGPL、Piper MIT、ONNX Runtime MIT）はインストーラにもそのまま含まれる。
