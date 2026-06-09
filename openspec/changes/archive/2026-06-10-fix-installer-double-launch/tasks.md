## 1. 原因の再確認

- [x] 1.1 `installer/novel_viewer.iss` の `[Run]`（L86）と `[Code]` `CurStepChanged`（L103-110）の2つの起動経路を確認する
- [x] 1.2 Inno Setup の `postinstall` フラグがサイレント時もデフォルト実行される（抑止には `skipifsilent` が必要）ことをドキュメントで再確認する

## 2. 修正の実装

- [x] 2.1 `[Run]` の postinstall 起動エントリ（L86）の `Flags:` に `skipifsilent` を追加する（`nowait postinstall` → `nowait postinstall skipifsilent`）
- [x] 2.2 L82-85 のコメントを実挙動に合わせて修正する（「サイレント時は `[Run]` が実行されないため `[Code]` で起動する」→「`[Run]` は `skipifsilent` でサイレント時に抑止し、サイレント時の起動は `[Code]` に一本化する」旨に更新）

## 3. インストーラのビルドと手動検証

> `.iss` の変更はビルド生成物にしか反映されず `fvm flutter test` では検証できないため、実インストーラで以下を確認する。

- [x] 3.1 `fvm flutter build windows` でアプリをビルドする
- [x] 3.2 `ISCC.exe installer\novel_viewer.iss /DAppVersion=<version>` でインストーラ EXE を生成する
- [x] 3.3 シナリオ①: `installer.exe /SILENT /UPDATELAUNCH` を実行し、起動する NovelViewer ウィンドウが**ちょうど1つ**であることを確認する（二重起動が解消されている）
- [x] 3.4 シナリオ②: `installer.exe /SILENT`（`/UPDATELAUNCH` なし）を実行し、アプリが**起動しない**ことを確認する
- [x] 3.5 シナリオ③: インタラクティブインストールで完了画面の起動チェックを有効にし、ウィンドウが**ちょうど1つ**起動することを確認する
- [x] 3.6 補助確認: `installer/novel_viewer.iss` の `[Run]` セクションに `skipifsilent` を含む postinstall 起動エントリが存在することを確認する

## 4. 最終確認

- [x] 4.1 code-reviewスキルを使用してコードレビューを実施
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
