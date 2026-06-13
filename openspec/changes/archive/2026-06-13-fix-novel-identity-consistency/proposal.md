## Why

フォルダ管理機能（`novel-folder-management`）で小説フォルダを整理フォルダの下にネスト配置できるようになった後も、「小説を一意に識別する方法（novel_id）」が機能ごとに食い違ったまま残っている。ブックマーク保存と読書進捗保存は **ライブラリ直下の第1セグメント** を novel_id にしているが（`bookmark_providers.dart:20-21` / `reading_progress_providers.dart:61`）、タイトル表示・小説フォルダ判定・削除カスケードは **最も近い登録済み祖先フォルダの葉名（folder_name）** を使う（`selectedNovelTitleProvider` / `isNovelFolder` / `NovelDeleteService.delete(dir.name)`）。この不整合により、ネストされた小説を別フォルダへ移動するとブックマーク/進捗が孤児化し（F106）、小説削除はブックマークをカスケードせず孤児行が永久蓄積する（F107）。さらに削除の4連DELETEはトランザクション外で、途中クラッシュ時に一部テーブルが孤児化する（F127）。

## What Changes

- **新規 `resolveNovelId` 共有関数を追加**: ライブラリルートからパスを下り、最も近い「登録済み小説フォルダ名（folder_name）」を返す。整理フォルダのネスト深度に依存しない（`selectedNovelTitleProvider` と同じ走査ロジックを folder_name 返しに統一）。未登録パス／ライブラリルート／ライブラリ外は null。
- **novel_id 導出を葉名（folder_name）に統一**: `currentNovelIdProvider`（ブックマーク）と読書進捗リスナーの第1セグメント導出を `resolveNovelId` に差し替える。これによりネスト小説でも save 側と delete/classifier 側のキーが一致する。
- **BREAKING（プロバイダ契約）**: `currentNovelIdProvider` を同期 `Provider<String?>` から **`FutureProvider<String?>` 化**（A案）。`resolveNovelId` が `allNovelsProvider`（非同期）の folder_name 集合を必要とするため。消費側（`bookmarkLineNumbersForFileProvider` 等）は await へ追従。
- **削除カスケードに bookmarks を追加（F107）**: `NovelDeleteService` のDBクリーンアップに `BookmarkRepository.deleteByNovelId` を加える。
- **削除のDB削除を原子化（F127）**: novels / word_summaries / fact_cache / reading_progress / bookmarks の各DELETEを `db.transaction` で1トランザクションに包む。
- **F128（絶対 file_path → 相対パス移行）は本changeに含めない**。後続changeで対応する。

## Capabilities

### New Capabilities
- `novel-id-resolution`: ライブラリ配下の任意パスから、ネスト深度に依存せず小説の一意識別子（登録済みフォルダの葉名 = folder_name）を解決する共有ルール。ブックマーク・読書進捗・削除など全機能が同一規則を消費する契約を定める。

### Modified Capabilities
- `reading-progress`: 自動保存・自動オープンの novel_id 解決を、第1セグメントからネスト対応の `resolveNovelId` に変更する。
- `novel-delete`: 削除カスケードに bookmarks の削除を追加し、DBレコードの削除を単一トランザクションで原子的に実行する（部分削除による孤児化を防止）。

## Impact

- **新規**: `lib/shared/utils/novel_id_resolver.dart`、対応する単体テスト。
- **変更コード**:
  - `lib/features/bookmark/providers/bookmark_providers.dart`（`currentNovelIdProvider` の FutureProvider 化、消費側の await 追従）
  - `lib/features/reading_progress/providers/reading_progress_providers.dart`（リスナー内の novel_id 導出を共有関数へ）
  - `lib/features/novel_delete/data/novel_delete_service.dart`（bookmarks カスケード追加 + transaction 化）
  - `lib/features/bookmark/data/bookmark_repository.dart`（`deleteByNovelId` を追加）
- **DBスキーマ**: 変更なし（マイグレーション不要）。F128 の相対パス移行は後続change。
- **テスト**: `resolveNovelId` 単体、ネスト移動の孤児化回帰、削除の bookmarks カスケード + transaction 原子性、save↔delete のキー一致。
