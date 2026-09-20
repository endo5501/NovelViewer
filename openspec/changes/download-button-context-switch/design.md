## Context

動機は proposal.md「Why」を参照。ここでは実装を決めるうえで効く現状の制約だけを挙げる。

- **Drawer は AppBar を覆う。** `Scaffold.drawer` はスキャフォルド全高に敷かれるため、ファイルブラウザを開いている間 AppBar のボタンには触れない。これが「ライブラリ操作中の新規ダウンロード入口を Drawer 内に置く」必然性である。
- **本文とファイルブラウザの現在地は独立している。** `selectedFileProvider`（表示中のファイル）と `currentDirectoryProvider`（ブラウザの現在地）は、Drawer 化以降は自由にずれる。
- **更新対象の解決規則は既にある。** `lib/shared/utils/novel_id_resolver.dart` の `resolveNovelFolderPath(libraryRoot, path, registeredFolderNames)` が、任意のパスから最も近い登録済み小説フォルダの絶対パスを返す。reading-progress やフォルダ別 DB が既に依存している共有ルール。
- **更新の実行部は完成している。** `DownloadNotifier.refreshNovel(folderName, parentPath:)`（`lib/features/text_download/providers/text_download_providers.dart:356`）と `cancel()`（同 `:74`）。本変更でパイプラインには触れない。
- **更新の起動と進捗ダイアログはファイルブラウザに私有されている。** `_startRefresh`（`file_browser_panel.dart:656`）と `_RefreshProgressDialog`（同 `:822`）はいずれも private。AppBar からも使うには切り出しが要る。

## Goals / Non-Goals

**Goals:**

- AppBar ボタンの2状態を、ウィジェットを組み立てずに検証できる単一の導出値に閉じ込める。
- 更新の起動（並行ガード → 開始 → 進捗ダイアログ）を、呼び出し元がファイルブラウザか AppBar かを知らない1つの入口にまとめる。
- 進捗ダイアログをウィジェットテストから直接組み立てられる形にする。

**Non-Goals:**

- ダウンロード／更新パイプラインの変更。`refreshNovel` の署名も挙動も据え置く。
- 保存先選択ロジックの変更（proposal.md「非目標」参照）。
- ファイルブラウザのツールバーの再設計。ボタンを1つ増やすだけで、既存の2つには触れない。

## Decisions

### D1: 更新対象は導出プロバイダ1本に閉じる

`selectedFileProvider` / `libraryPathProvider` / `allNovelsProvider` から `RefreshTarget?` を導く `refreshTargetProvider` を新設する（`lib/features/novel_refresh/providers/refresh_target_provider.dart`）。`RefreshTarget` は `folderName` / `parentPath` / `title` を持つ。

`null` が返る条件は spec の定めるとおり（未表示 / 登録済み小説フォルダ無し / Web コレクション）。AppBar のアイコン選択もボタンの挙動も、この1つの値だけを見る。

- **なぜ:** ボタンの分岐はこの変更の中心であり、もっともテストしたい部分である。プロバイダに閉じれば `ProviderContainer` で全分岐をユニットテストでき、ウィジェットテストは「アイコンが切り替わること」だけを見ればよくなる。
- **代案:** `home_screen.dart` の `build` 内で直接計算する。ウィジェットテストでしか分岐を踏めず、Web コレクションや入れ子の検証が重くなる。却下。

### D2: 情報源は `selectedFileProvider`、解決は `resolveNovelFolderPath`

- **なぜ `currentDirectoryProvider` ではないか:** ブラウザの現在地は読者が読んでいる小説を表さない。読書中に Drawer でライブラリルートへ上がった状態で更新ボタンを押すと、対象が消える（あるいは別の小説になる）という事故になる。
- **なぜ `p.dirname()` の2回適用ではないか:** 入れ子の深さに依存しない共有ルールが既にあり、reading-progress や per-folder DB と同じキーで対象が定まる。さらに `null` が返る条件が「更新できない」条件と完全に一致するため、`refreshNovel` の「メタデータが見つかりません」エラー経路がこの入口からは構造的に到達不能になる。

### D3: Web コレクションは押下時のエラーではなく、対象解決の段階で除外する

`refreshNovel` は Web コレクション（`siteType='web'`）を拒否してエラー状態にする（`text_download_providers.dart:381`）。この判定を `refreshTargetProvider` 側へ前倒しし、コレクション表示中はボタンを「新規ダウンロード」として提示する。

- **なぜ:** ボタンが押す前に何が起きるかを示すという原則を守れる。押せるが必ず失敗する更新ボタンを出すのは、状態依存ボタンの利点を打ち消す。
- **代案:** ダウンロードダイアログを対象コレクション選択済みで開く。ダイアログのコレクション選択 UI は URL 入力後にしか現れない（`download_dialog.dart` の `_isWebArticle` 判定）ため、URL 未入力の間も選択を保持する新しい状態が要る。独立した変更に値する規模なので却下。
- **注意:** `refreshNovel` 側の拒否は残す。右クリック「更新」という別入口があり、そちらの防御は依然必要。

### D4: 更新の起動と進捗ダイアログを `features/novel_refresh` へ切り出す

`lib/features/novel_refresh/presentation/refresh_progress_dialog.dart` に以下を置く。

- `RefreshProgressDialog`（`_RefreshProgressDialog` の public 化 + キャンセルボタン追加）
- `startNovelRefresh(BuildContext, WidgetRef, {folderName, parentPath, title})` — 並行ガードの SnackBar → `refreshNovel` → ダイアログ表示。現在の `_startRefresh` の中身と同一。

`home_screen.dart` と `file_browser_panel.dart` はどちらもこれを呼ぶ。

- **なぜ `features/novel_refresh` か:** capability 名と一致し、`novel_delete` と同じ粒度になる。`text_download` に置くと、ダウンロードそのものと更新という別レベルの関心が1ディレクトリに混ざる。
- **副次的な効果:** 現在の `test/features/file_browser/presentation/refresh_progress_dialog_test.dart` は、private ゆえに本物のダイアログを組み立てられず、状態表示を模した代替ウィジェットを検証している（ファイル冒頭のコメントがそう明言している）。public 化により本物を直接テストできる。

### D5: 更新側のアイコンは `Icons.sync`

新規ダウンロードは `Icons.download` のまま。更新は `Icons.sync` とする。

- **なぜ `Icons.refresh` ではないか:** アプリ内で `Icons.refresh` は既に「その場で取り直す／作り直す」に使われている（設定の再スキャン、LLM 要約の再生成、TTS セグメントの再合成）。小説更新は「サイトと同期して差分を取り込む」であり、`Icons.sync` の方が既存の用法と衝突しない。
- ツールチップが最終的な意味の担い手であることは変わらない。アイコンは、押す前に2状態を見分けられるだけの差があればよい。

### D6: キャンセルは既存機構をそのまま呼ぶ

`RefreshProgressDialog` の `downloading` 状態に、`downloadProvider.notifier.cancel()` を呼ぶボタンを足す。`DownloadDialog`（`download_dialog.dart:539`）と同一。`cancelled` 状態の表示と「閉じる」ボタンは現在の実装に既にある。

- 文字列は `common_cancelButton` / `download_cancelledMessage` を再利用するため、キャンセル関連の `.arb` 追加は無い。
- 再開可能性（保存済みエピソードの保持）は `download-cancellation` が既に保証しており、更新は `startDownload` を経由するので自動的に満たされる。

### D7: 新規文字列は2つだけ

- AppBar の更新ツールチップ（`homeScreen_downloadTooltip` に対する更新版）
- ファイルブラウザのダウンロードボタンのツールチップ

いずれも en/ja/zh の3ファイルに追加する。

## Risks / Trade-offs

- **[同じボタンが文脈で別の処理を起こすことへの戸惑い]** → アイコンとツールチップを同時に切り替え、更新側にはキャンセル可能な進捗ダイアログを置く。誤って押しても止められる。
- **[一度何かを読むと、AppBar から新規ダウンロードに戻れない]** → アプリは起動時に Drawer を開く設計であり（`adaptive-shell-layout`）、Drawer のツールバーに新規ダウンロードボタンが常設される。新規ダウンロードは常に「Drawer を開く → 押す」の2手で届く。
- **[AppBar タイトルとボタンが食い違う]** → タイトルは `currentDirectoryProvider` 由来のため、読書中にブラウザをライブラリルートへ移すとタイトルだけ `NovelViewer` に戻る一方、ボタンは更新のままになる。Drawer 化が露出させた既存の症状で、本変更が作るものではない。proposal.md「非目標」のとおり別変更として扱う。
- **[更新中に表示中のエピソード本文がディスク上で書き換わる]** → 既に右クリック「更新」で起こりうる挙動であり、本変更で新規に生じるものではない。更新完了後にファイル一覧とメタデータが再読込される既存の挙動（`novel-refresh`「UI refreshes after completion」）に従う。本変更では本文の再読込は導入しない。
- **[`features/novel_refresh` という新ディレクトリの追加]** → `novel_delete` に倣った粒度であり、capability 名と対応する。移動するのは既存の private 2要素のみで、新しい抽象は導入しない。
