## Why

per-folder データベースハンドル（TTS音声DB・TTS辞書DB・エピソードキャッシュDB）のライフサイクル管理は、TECH_DEBT_AUDIT.md で**アプリ最大の構造的リスク**と名指しされている。直前の change `fix-folder-db-handle-race`（F108/F126/F131）は、move/rename/空フォルダ削除フローの fire-and-forget invalidate × Windows ファイルロックのレースという**症状**を共有ヘルパー `releaseFolderDbHandles` で塞いだが、根本原因である「DBラッパーに open/close のインターロックがない」点（F124）は明示的に後続change送りとされた。本changeがその後続であり、症状の再発を構造的に止める根治を行う。

根本の欠陥は2つ:

- **F124（インターロック欠如）**: `NovelDatabase.database` getter（`novel_database.dart:71-75`）に in-flight open ガードがなく、`close()` にインターロックがない。close 直前に始まった open が close 完了**後**に新ハンドルを `_database` へ代入し、削除中のファイルを再ロックし得る。並行呼び出しでの二重 open も起こり得る。同型コードが `episode_cache_database.dart`・`tts_audio_database.dart`・`tts_dictionary_database.dart` にも存在する。
- **F125（widget層の振り付け）**: DBハンドルのライフサイクルを `file_browser_panel.dart:586-615` の widget が手で振り付けている（currentDirectory退避→選択クリア→awaited close の順序が必須）。per-folder DB provider に新しい消費者を1つ足すたびに locked-DB バグが再発する構造で、F108 の修正も「振り付けを正しく書く」規律に依存したままになっている。

## What Changes

- **F124**: 全DBラッパークラス（`NovelDatabase` + per-folder 3種）の `database` getter に in-flight open キャッシュを導入する。open 中の `Future<Database>` を保持し、並行呼び出しは同一の Future を await して同一ハンドルを共有する。`close()` は in-flight open の完了を await してから実ファイルを閉じ、close 完了までの間に始まった open が close 後に新ハンドルを生むことをゲートする（close 中の getter 呼び出しは close 完了後に再 open される、または明示エラーになる — 挙動は spec で確定する）。
- **F125**: per-folder DBハンドルの open/close を所有する**ハンドルレジストリ**を導入する。レジストリは awaitable な `closeAll(folder)`（対象フォルダの3ハンドルを await close）を提供し、move/rename/空フォルダ削除・小説削除の各フローはこの単一APIを経由する。Riverpod の per-folder DB provider はレジストリ上の薄いビューとなり、widget 層がハンドルの close 順序を直接振り付けることをやめる。これにより新しい消費者を追加しても locked-DB バグが再発しない。
- 既存の共有ヘルパー `releaseFolderDbHandles`（`fix-folder-db-handle-race` で新設、`folderDbKey` 正規化済み）は、レジストリの `closeAll(folder)` へ吸収・置換する。観測可能な「ファイル操作前に3ハンドルの close 完了」契約は維持する（後退させない）。

## Capabilities

### New Capabilities
- `database-connection-interlock`: DBラッパークラスの接続ライフサイクル契約。`database` getter の in-flight open キャッシュ（並行呼び出しの同一ハンドル共有・二重 open 防止）と、`close()` による in-flight open の await・再 open のゲートを定義する。`NovelDatabase` および全 per-folder DB（エピソードキャッシュ・TTS音声・TTS辞書）に適用される横断契約。

### Modified Capabilities
- `novel-folder-management`: 既存の「移動・削除時のデータベースハンドル整合」要件を、所有者を持つ per-folder DBハンドルレジストリ（awaitable な `closeAll(folder)`）を単一の sanctioned API とする形へ進化させる。fire-and-forget 由来の共有ヘルパーへの依存記述をレジストリ経由へ改め、provider を薄いビューとする契約を加える。観測可能な close→file-op の順序契約は不変。

## Impact

- **コード**:
  - `lib/features/novel_metadata_db/data/novel_database.dart`（`database` getter / `close()` のインターロック化）
  - `lib/features/episode_cache/data/episode_cache_database.dart`、`lib/features/tts/data/tts_audio_database.dart`、`lib/features/tts/data/tts_dictionary_database.dart`（同型のインターロック化）
  - per-folder DBハンドルレジストリの新規追加（`lib/shared/database/` 配下を想定）と、`folder_db_key.dart` / `releaseFolderDbHandles` の置換
  - `lib/features/file_browser/presentation/file_browser_panel.dart`（振り付けの撤去、レジストリ経由化）
  - per-folder DB の Riverpod provider 群（`tts_audio_database_provider.dart` ほか約8呼び出し箇所）
- **テスト（TDD・テストファースト）**: インターロックの並行 open/close レーステスト、`closeAll(folder)` の await 完了順序テスト、widget order-test の継続（`file_browser_handle_release_order_test.dart` 等の後退防止）
- **依存**: 新規パッケージ追加なし。Riverpod 3・sqflite/sqflite_common_ffi の既存スタックのみ。
- **非対象**: F111（abort の use-after-free、third_party 監査が必要）、F104（ゼロ埋め桁繰り上がり）は本changeに含めない。
