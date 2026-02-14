## 1. selectedNovelTitleProviderのテスト作成

- [x] 1.1 `selectedNovelTitleProvider` のユニットテストを作成する。以下のシナリオをカバーする：ライブラリルートにいるときnullを返す、小説フォルダ内にいるときメタデータのtitleを返す、サブディレクトリにいるとき親フォルダの小説タイトルを返す、メタデータが存在しないフォルダにいるときフォルダ名を返す、currentDirectoryがnullのときnullを返す
- [x] 1.2 テストを実行し、失敗することを確認する

## 2. selectedNovelTitleProviderの実装

- [x] 2.1 `lib/features/file_browser/providers/file_browser_providers.dart` に `selectedNovelTitleProvider` を追加する。`currentDirectoryProvider`、`libraryPathProvider`、`allNovelsProvider` を参照し、現在のディレクトリパスからフォルダ名を導出して小説タイトルを返す
- [x] 2.2 テストを実行し、すべてパスすることを確認する

## 3. AppBarタイトル表示のテスト作成

- [x] 3.1 `home_screen.dart` のAppBarタイトル表示に関するWidgetテストを作成する。小説選択時にタイトルが表示されること、未選択時に「NovelViewer」が表示されることをカバーする
- [x] 3.2 テストを実行し、失敗することを確認する

## 4. AppBarタイトル表示の実装

- [x] 4.1 `lib/home_screen.dart` のAppBarタイトルを `selectedNovelTitleProvider` の値に基づいて動的に表示するよう変更する。nullの場合は「NovelViewer」を表示する
- [x] 4.2 テストを実行し、すべてパスすることを確認する

## 5. 最終確認

- [x] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
