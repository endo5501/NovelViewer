## Why

小説をダウンロードして中身を見た直後に削除しようとすると、フォルダ内の `episode_cache.db` がアプリ自身のSQLite接続でロックされたままになり、ファイルシステムの再帰削除が `FileSystemException` で失敗する。さらに `NovelDeleteService` がメタデータを先に削除してからフォルダを消すため、ファイル削除に失敗すると小説はメタデータを失って「整理フォルダ」に降格し、`novel-folder-management` の「空のときのみ削除可」制約に阻まれて**二度と削除できない（詰む）**状態になる。

直接の原因は、ダウンロード処理が `episode_cache.db` を開く際にフォルダパスをフォワードスラッシュ手結合（`'$outputPath/$folderName'`）でfamilyプロバイダのキーにしており、ファイルブラウザ側のバックスラッシュ由来パスとキーが一致せず、開いた接続を解放する手段がアプリ内に存在しなくなることにある。

## What Changes

- **ダウンロードのパスキー統一**: `text_download_providers.dart` の `episode_cache.db` パス生成を `p.join` に変更し、`episodeCacheDatabaseProvider` 等のper-folderDB familyのキーを正規化（`p.normalize`）して、Windowsのセパレータ差でハンドルを取りこぼさないようにする。
- **ダウンロード後のハンドル解放**: ダウンロード完了・失敗いずれの場合も、開いた `episode_cache.db` 接続を `try/finally` で確実に解放する。
- **小説削除時のハンドル解放**: 小説削除フロー（`_showDeleteConfirmation`）でも、移動・リネーム・フォルダ削除と同様にper-folderDBハンドルを解放してから削除する。
- **削除順序の反転（BREAKING: spec変更）**: `NovelDeleteService` を「ファイルシステム削除が成功してからメタデータ等のDB行を削除する」順序に変更する。FS削除が失敗した場合はメタデータが残るため小説フォルダのまま再試行でき、「整理フォルダ降格による詰み」を防ぐ。
- **awaitできるclose**: ハンドル解放を `ref.invalidate` の撃ちっぱなし（close未await）ではなく、`close()` 完了を待てる方式にして、close完了前に削除へ突入するレースを排除する。
- **回帰テスト**: 実際に `episode_cache.db` を開いてロックさせた状態で小説削除が成功することを検証するテストを追加する。

## Capabilities

### New Capabilities

（なし。既存の振る舞いに対するバグ修正）

### Modified Capabilities

- `novel-delete`: 削除順序を「DB先行」から「ファイルシステム削除成功→DB行削除」に変更。削除前にper-folderDBハンドルを解放（awaitできるclose）する要件を追加。FS削除失敗時に小説フォルダ状態が保持され再試行可能であることを要件化。
- `episode-cache`: `episode_cache.db` ハンドルが正規化済みフォルダパスをキーに管理され、ダウンロード完了/失敗後に解放されること、フォルダ削除を阻むロックを残さないことを要件化。

## Impact

- コード:
  - `lib/features/text_download/providers/text_download_providers.dart`（パスキー統一・ダウンロード後解放）
  - `lib/features/tts/providers/tts_audio_database_provider.dart`（familyキー正規化）
  - `lib/features/file_browser/presentation/file_browser_panel.dart`（`_showDeleteConfirmation` でハンドル解放）
  - `lib/features/file_browser/providers/file_browser_providers.dart`（`setDirectory`/解放のキー整合）
  - `lib/features/novel_delete/data/novel_delete_service.dart`（削除順序の反転、awaitできるclose経路）
- テスト:
  - `test/features/novel_delete/data/novel_delete_service_test.dart`（ロック状態での削除回帰テスト）
  - パスキー正規化のユニットテスト
- 依存・システム: Windowsデスクトップでのファイルロック挙動が対象。sqflite_ffi / Riverpod family のライフサイクルに依存。
- 既存仕様への影響: `novel-delete` の「Deletion order」シナリオ（DB先行）を反転するため**振る舞いが変わる**。`novel-folder-management` の空フォルダ削除制約は維持（変更しない）。
