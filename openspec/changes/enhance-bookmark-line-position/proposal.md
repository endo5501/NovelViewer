## Why

現在のブックマーク機能はファイル単位でしか位置を記録できない。長編小説のように1ファイルが数千行に及ぶ場合、ブックマークを開いてもファイルの先頭に戻されるため、読書位置の記録として実用的でない。ブックマークに行番号を含めることで、正確な読書位置への復帰を可能にする。

## What Changes

- ブックマークのデータモデルに `line_number` フィールド（整数、nullable）を追加
- データベーススキーマをバージョン4に更新し、`bookmarks`テーブルに`line_number`カラムを追加
- ブックマーク作成時に、テキストビューアの現在の表示位置（行番号）を記録
- ブックマークリストの表示に行番号情報を付加（例: "chapter01.txt : L42"）
- ブックマークタップ時にファイルを開き、記録された行番号位置へスクロール/ページ遷移
- テキストビューア上でブックマーク位置の行に栞マーク（アイコン）を表示

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `bookmark-storage`: ブックマークのデータモデルとDBスキーマに `line_number` フィールドを追加。一意制約を `(novel_id, file_path)` から `(novel_id, file_path, line_number)` に変更し、同一ファイル内の複数行ブックマークをサポート
- `bookmark-ui`: ブックマークリストに行番号を表示。ブックマークタップ時に該当行へジャンプ。テキストビューア上でブックマーク行に栞マークを表示。ブックマーク作成時に現在の表示行を記録

## Impact

- `lib/features/bookmark/domain/bookmark.dart` - ドメインモデルに `lineNumber` フィールド追加
- `lib/features/novel_metadata_db/data/novel_database.dart` - DBバージョン3→4、マイグレーション追加
- `lib/features/bookmark/data/bookmark_repository.dart` - add/findByNovel等のメソッド変更
- `lib/features/bookmark/providers/bookmark_providers.dart` - ブックマーク作成時の行番号取得ロジック
- `lib/features/bookmark/presentation/bookmark_list_panel.dart` - 行番号表示、ジャンプ機能
- `lib/features/text_viewer/presentation/text_viewer_panel.dart` - 栞マーク表示、行番号情報の受け渡し
- `lib/features/bookmark/presentation/bookmark_appbar.dart` - ブックマークトグル時の行番号取得
- テスト全般の更新
