# URL スキーム受信の手動確認

`novelviewer://download?url=...` を受け取ってダウンロードダイアログを開く経路のうち、OS への登録と配送は Flutter のテストでは検証できない。Dart 側（リンクの解釈、保留リクエスト、ダイアログの反映と拒否、ダイアログの起動）は自動テストで押さえてあるので、ここで確かめるのは **OS がアプリにリンクを届けるか** だけである。

対応は iOS と macOS のみ。Windows と Linux にはスキームを登録していない（Windows はスキーム起動が別プロセスを立ち上げ、同じ SQLite ファイルを 2 つのプロセスが掴むため、単一インスタンス化が先に必要）。

## 準備（macOS）

```bash
fvm flutter build macos

# 登録内容の確認（novelviewer が出れば OK）
plutil -extract CFBundleURLTypes json -o - \
  build/macos/Build/Products/Release/novel_viewer.app/Contents/Info.plist

# LaunchServices にこのビルドを登録する
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f build/macos/Build/Products/Release/novel_viewer.app
```

確認に使うリンク（実在するがダウンロードは開始しない。押さない限り何も起きない）:

```bash
open "novelviewer://download?url=https%3A%2F%2Fncode.syosetu.com%2Fn9669bk%2F"
```

## チェックリスト

### macOS

- [x] **未起動からの起動**: アプリを終了した状態で上記の `open` を実行する。アプリが起動し、ダウンロードダイアログが `https://ncode.syosetu.com/n9669bk/` 入りで開く。
- [x] **起動中の受信**: アプリを起動したまま同じ `open` を実行する。ダイアログが同じ URL 入りで開く。
- [x] **二重に開かない**: ダイアログが開いたまま、別の URL のリンクを `open` する。ダイアログは 1 枚のままで、URL 欄が新しい URL に差し替わる。
- [x] **ダウンロード中は受け付けない**: ダウンロードを開始し、進行中に `open` する。進行中の表示は変わらず、ダイアログ内に「URL を受け取りましたが、取り込みませんでした」と表示され、ダウンロードは中断しない。
- [x] **勝手に始まらない**: どの場合も、開始ボタンを押すまでダウンロードが始まらない。
- [x] **不正なリンクは無視される**: `open "novelviewer://download?url=file%3A%2F%2F%2Fetc%2Fpasswd"` を実行しても、ダイアログは開かず何も起きない。

### iPad

ショートカットの作り方は README の「iPad で共有シートから登録する」を参照。

- [x] **共有シートから**: Safari で小説の目次ページを開き、共有 → 作成したショートカットを選ぶ。NovelViewer が前面に来て、ダイアログがそのページの URL 入りで開く。
- [x] **対応サイト以外**: 小説サイト以外のページを同じ手順で送る。ダイアログが開き、「取り込み先」としてコレクションを選ぶ UI が出る（汎用 Web 記事として扱われる）。
- [x] **勝手に始まらない**: どちらの場合も、開始ボタンを押すまでダウンロードが始まらない。

## 確認したこと

| 日付 | 確認者 | 対象 | 結果 |
| --- | --- | --- | --- |
| 2026-09-11 | endo5501 | macOS | 全項目パス |
| 2026-09-11 | endo5501 | iPad | 全項目パス |
