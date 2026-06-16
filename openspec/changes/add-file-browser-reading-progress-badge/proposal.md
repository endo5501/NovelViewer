## Why

各小説の読書進捗（何話まで読んだか）は `reading_progress` テーブルに記録されているが、現状その値はユーザーがその小説フォルダへ移動して初めてわかる。ファイルブラウザの小説フォルダ一覧の段階では「全何話あるのか」「何話まで読んだのか」が一切見えず、未読・読みかけ・読了の把握ができない。一覧上で進捗が一目でわかるようにしたい。

## What Changes

- ファイルブラウザの小説フォルダタイル（`📖` アイコンの登録済み小説）に、読書進捗を示す**進捗バー＋数値（例: `3 / 120`）**を表示する。
- 表示位置はフォルダ名の**下部（`ListTile` の `subtitle`）**とする。横幅が限られるため、タイトル後ろのバッジは採らない。
- **分母（全話数）** は `novels.episode_count`（既存カラム）を用いる。
- **分子（読んだ話数）** は `reading_progress.file_name` の先頭数字（ダウンロード時のファイル名 `{1始まりの話数}_{タイトル}.txt` に由来＝話数そのもの）から導出する。
- `reading_progress` 行が無い**未読**の登録済み小説は、分母 `episode_count` を用いて `0 / N` を表示する。
- 進捗の意味は**「現在地（最後に開いた話）」**とする（到達点の最大値ではない）。
- 対象は**登録済み小説のみ**。手動配置フォルダ（`novels` 未登録）は従来通りバッジを表示しない。
- `ReadingProgressRepository` に、表示中の複数小説ぶんの進捗を一括取得する読み取りメソッド（`findAll` 相当）を追加する。
- 2行レイアウトに伴い、固定タイル高 `_kFileTileExtent`（現在 56.0）を調整する。
- **スキーマ変更なし**（マイグレーション不要）。フォルダDB（`novel_data.db`）にはアクセスせず、グローバル `novel_metadata.db` のみを参照する。

## Capabilities

### New Capabilities
- `reading-progress-badge`: ファイルブラウザの小説フォルダ一覧における読書進捗バッジ（進捗バー＋話数表示）の表示ルール。対象範囲、分母・分子の算出元、未読時の表示、表示位置・状態を規定する。

### Modified Capabilities
- `reading-progress`: 複数小説ぶんの読書進捗を一括取得する読み取り操作を追加する（バッジ表示が依存する一覧取得 API）。

## Impact

- 影響コード:
  - `lib/features/file_browser/presentation/file_browser_panel.dart`（小説フォルダタイルへの進捗バー追加、`_kFileTileExtent` 調整）
  - `lib/features/file_browser/providers/file_browser_providers.dart`（バッジ表示用の進捗データ提供。`allNovelsProvider` と一括取得を結合）
  - `lib/features/reading_progress/data/reading_progress_repository.dart`（一括取得メソッド追加）
- 参照データ: グローバル `novel_metadata.db` の `novels`（`episode_count`）・`reading_progress`（`file_name`）。フォルダDB・ファイルシステム走査は不要。
- スキーマ／マイグレーション: 変更なし。
