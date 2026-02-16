## Context

NovelViewerは3カラムレイアウトのFlutterデスクトップアプリで、左カラムにファイルブラウザ、中央にテキストビューア、右カラムに検索・要約パネルを配置している。データ永続化にはSQLite（`sqflite` + `sqflite_common_ffi`）を使用し、状態管理にはRiverpod（`NotifierProvider`パターン）を採用している。キーボードショートカットは`home_screen.dart`で`Shortcuts` + `Actions` + `Intent`パターンで実装されている。

現在、左カラムは`FileBrowserPanel`が直接配置されており、タブ切り替えの仕組みはない。ブックマークデータの保存先となるDBテーブルも存在しない。

## Goals / Non-Goals

**Goals:**
- 作品ごとにブックマーク（エピソード単位）を管理できる
- 左カラムでファイルブラウザとブックマーク一覧をタブで切り替えられる
- キーボードショートカット（Cmd+B / Ctrl+B）でブックマークを追加できる
- ブックマーク一覧から右クリックで削除できる
- ブックマーク選択時に対象ファイルを開ける

**Non-Goals:**
- ブックマークへのメモ・コメント機能
- ブックマーク内の特定位置（行番号・ページ番号）の保存
- ブックマークのエクスポート・インポート
- ブックマークの並び替え・検索

## Decisions

### 1. ブックマークの保存先: 既存の`novel_metadata.db`に新テーブル追加

**選択**: `novel_metadata.db`にDBバージョンを3に上げて`bookmarks`テーブルを追加する。

**理由**: アプリは既にSQLiteを使用しており、`NovelDatabase`クラスにマイグレーション機構（`onUpgrade`）が実装済み。新たな依存追加が不要で、既存パターンに沿った実装ができる。

**代替案**:
- per-novel SQLite DB（`episode_cache.db`方式）→ 全作品横断のブックマーク一覧取得が困難
- SharedPreferences → 構造化データの管理に不向き、データ量増加時のパフォーマンス懸念
- JSONファイル → 排他制御やマイグレーションの仕組みを自作する必要がある

**テーブル設計**:
```sql
CREATE TABLE bookmarks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  novel_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(novel_id, file_path)
);
```

### 2. 左カラムのタブ切り替え: `TabBar` + `TabBarView`を使用

**選択**: 左カラムの`FileBrowserPanel`を新しい`LeftColumnPanel`ウィジェットでラップし、`TabBar` + `TabBarView`でファイルブラウザとブックマーク一覧を切り替える。

**理由**: FlutterのMaterial Designコンポーネントとして標準提供されており、アニメーションやジェスチャー対応が組み込まれている。

**代替案**:
- `BottomNavigationBar`風のカスタムUI → デスクトップアプリの慣習に合わない
- `SegmentedButton` → タブに比べて拡張性が低い

### 3. キーボードショートカット: 既存の`Shortcuts`/`Actions`パターンに追加

**選択**: `home_screen.dart`の既存`Shortcuts`ウィジェットに`_BookmarkIntent`を追加する。`SingleActivator(LogicalKeyboardKey.keyB, meta: true)`（macOS）と`SingleActivator(LogicalKeyboardKey.keyB, control: true)`（Windows/Linux）を登録する。

**理由**: Cmd+F（検索）と同じパターンで実装でき、コードの一貫性が保てる。

### 4. ブックマーク登録ボタンの配置: AppBarに追加

**選択**: AppBarのアクションにブックマーク登録/解除ボタンを追加する。現在のファイルがブックマーク済みかどうかでアイコンを切り替える（`Icons.bookmark` / `Icons.bookmark_border`）。

**理由**: AppBarには既にアクションボタンが配置されており、統一的なUIを維持できる。ファイル選択時のみ有効になる。

### 5. 作品（novel_id）の特定方法

**選択**: 現在のディレクトリパスからライブラリルートとの相対パスで作品フォルダ名（novel_id）を導出する。ライブラリルート直下のサブディレクトリ名が作品IDに対応する。

**理由**: ファイルブラウザが既に`libraryPathProvider`と`currentDirectoryProvider`を持っており、これらから作品の特定が可能。作品フォルダ内にいない場合（ライブラリルート）はブックマーク操作を無効にする。

### 6. 状態管理: 既存のRiverpodパターンに準拠

**選択**:
- `BookmarkRepository` → `Provider`で注入
- `bookmarksForNovelProvider(novelId)` → `FutureProvider.family`で作品別ブックマーク一覧
- `isBookmarkedProvider(filePath)` → 現在のファイルがブックマーク済みか判定
- `BookmarkNotifier` → `NotifierProvider`でadd/remove操作

**理由**: アプリ全体で使われている`NotifierProvider` + `FutureProvider` + DIパターンに準拠。

## Risks / Trade-offs

- **DBマイグレーション**: バージョン2→3へのアップグレードでデータロスのリスク → `onUpgrade`で`bookmarks`テーブルのCREATEのみ実行し、既存テーブルに影響しない
- **作品ID特定の堅牢性**: ディレクトリ構造に依存するためパスが変わるとブックマークが孤立する → novel_idとfile_pathの組み合わせで管理し、パス変更時はブックマークが見つからない旨を表示
- **左カラムの幅制約**: 250pxの固定幅にタブUIを追加するため、タブラベルが長いと表示が崩れる → 短いラベル（「ファイル」「ブックマーク」）とアイコンを使用
- **ブックマーク一覧からのファイルオープン**: ブックマークされたファイルが削除されている可能性がある → ファイル存在チェックを行い、存在しない場合はエラー表示
