## 1. データ層: BookmarkRepositoryとDBマイグレーション

- [x] 1.1 `NovelDatabase`のDBバージョンを2→3に上げ、`onUpgrade`で`bookmarks`テーブルを作成する（`onCreate`にも追加）
- [x] 1.2 `Bookmark`モデルクラスを作成する（id, novelId, fileName, filePath, createdAt）
- [x] 1.3 `BookmarkRepository`クラスを作成する（add, remove, findByNovel, exists メソッド）
- [x] 1.4 `BookmarkRepository`のユニットテストを作成する

## 2. 状態管理: Riverpod Providers

- [x] 2.1 `bookmarkRepositoryProvider`（Provider）を作成する
- [x] 2.2 `currentNovelIdProvider`を作成する（currentDirectoryProviderとlibraryPathProviderから作品IDを導出）
- [x] 2.3 `bookmarksForNovelProvider(novelId)`（FutureProvider.family）を作成する
- [x] 2.4 `isBookmarkedProvider`を作成する（現在選択中のファイルがブックマーク済みかを判定）
- [x] 2.5 ブックマークの追加・削除操作を行うロジックを実装する（providerのinvalidateを含む）
- [x] 2.6 Providerのユニットテストを作成する

## 3. UI: 左カラムのタブ切り替え

- [x] 3.1 `LeftColumnPanel`ウィジェットを作成する（TabBar + TabBarViewで「ファイル」「ブックマーク」タブを切り替え）
- [x] 3.2 `home_screen.dart`の左カラムを`FileBrowserPanel`から`LeftColumnPanel`に置き換える
- [x] 3.3 `LeftColumnPanel`のウィジェットテストを作成する

## 4. UI: ブックマーク一覧パネル

- [x] 4.1 `BookmarkListPanel`ウィジェットを作成する（作品のブックマーク一覧を表示）
- [x] 4.2 ブックマークタップ時にファイルを開く処理を実装する（currentDirectoryProviderとselectedFileProviderの更新）
- [x] 4.3 右クリックコンテキストメニューによるブックマーク削除を実装する
- [x] 4.4 作品未選択時・ブックマークなし時のプレースホルダー表示を実装する
- [x] 4.5 存在しないファイルのブックマークをタップした場合のエラー表示を実装する
- [x] 4.6 `BookmarkListPanel`のウィジェットテストを作成する

## 5. UI: ブックマーク登録（AppBarボタン + キーボードショートカット）

- [x] 5.1 `home_screen.dart`のAppBarにブックマーク登録/解除ボタンを追加する（Icons.bookmark / Icons.bookmark_border）
- [x] 5.2 ファイル未選択時・ライブラリルート時のボタン無効化を実装する
- [x] 5.3 `home_screen.dart`に`_BookmarkIntent`とCmd+B / Ctrl+Bショートカットを追加する
- [x] 5.4 ブックマーク登録UIのウィジェットテストを作成する

## 6. 最終確認

- [x] 6.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
