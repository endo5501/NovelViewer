## Context

NovelViewerはダウンロードした小説をSQLiteデータベース（novels, word_summaries テーブル）とファイルシステム（小説フォルダ配下のテキストファイル群）の両方で管理している。現在、小説の追加・更新機能は存在するが、削除機能がない。ファイルブラウザのUIにはフォルダ一覧のListTileがあるが、コンテキストメニューは未実装。

## Goals / Non-Goals

**Goals:**

- 小説フォルダをDB（novels + word_summaries）とファイルシステムの両方から一括削除できる
- 誤操作を防止する確認ダイアログを表示する
- 削除後にUIが自動的に更新される
- ライブラリルート表示時のみ削除操作を許可する（小説フォルダ内のファイル個別削除は対象外）

**Non-Goals:**

- ゴミ箱・アンドゥ機能（完全削除のみ）
- 複数小説の一括選択・削除
- 個別エピソードファイルの削除

## Decisions

### 1. 削除操作のトリガー: 右クリックコンテキストメニュー

小説フォルダのListTileに`GestureDetector`でセカンダリタップ（右クリック）を検知し、`showMenu`でコンテキストメニューを表示する。

**代替案:** 各ListTileにゴミ箱アイコンボタンを常時表示 → 常時表示は誤操作リスクが高く、UIが煩雑になるため不採用。

### 2. 削除処理のオーケストレーション: 専用サービスクラス `NovelDeleteService`

削除はDB2テーブル + ファイルシステムの3箇所を整合性を保って処理する必要がある。この責務を`NovelDeleteService`に集約する。

- `NovelRepository.deleteByFolderName()` → novelsテーブルから削除
- `LlmSummaryRepository.deleteByFolderName()` → word_summariesテーブルから削除
- `FileSystemService.deleteDirectory()` → フォルダごと削除

**処理順序:** DB削除 → ファイルシステム削除。DB削除が成功してからファイルを消すことで、ファイル削除に失敗した場合のDB不整合を避ける。

**代替案:** Repositoryに直接ファイル削除ロジックを追加 → 関心の分離に反するため不採用。

### 3. LlmSummaryRepositoryへのアクセス方法

`LlmSummaryRepository`は`Database`インスタンスを直接受け取る設計。`NovelDeleteService`では`NovelDatabase`経由でDBインスタンスを取得し、word_summariesテーブルの削除を直接実行する（既存の`LlmSummaryRepository`にフォルダ単位の削除メソッドを追加する）。

### 4. Provider設計

`NovelDeleteService`用のProviderを作成し、削除後に`allNovelsProvider`と`directoryContentsProvider`を`ref.invalidate()`で無効化してUI更新する。invalidateは削除を呼び出すUI側で行う。

### 5. 確認ダイアログ

`showDialog`で`AlertDialog`を使用。小説タイトルを表示し、「削除」「キャンセル」ボタンを配置。削除ボタンは赤色で視覚的に警告する。

## Risks / Trade-offs

- **DB削除成功・ファイル削除失敗のケース** → DBレコードは消えるがフォルダが残る可能性がある。ユーザーは手動でフォルダを削除すればよく、DB不整合（逆のケース）よりも対処が容易なため許容する。
- **削除の不可逆性** → 確認ダイアログで軽減。ゴミ箱機能は将来の拡張として見送り。
- **削除中のUI操作** → 削除処理は高速（DB削除 + ディレクトリ削除）であるため、ローディングインジケータは不要とする。
