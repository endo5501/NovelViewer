## Why

`commit 81ca506` で小説削除フローだけは「per-folder DB ハンドルを `await close()` してから `invalidate` する」ことでファイルロックとのレースを解消したが、ファイルブラウザの**移動 / リネーム / 空フォルダ削除**の3フローは依然として fire-and-forget の `ref.invalidate(...)` だけでハンドルを「解放」しており、`onDispose` の `close()` が await されない。このため Windows では SQLite ファイルの排他ロックが残ったまま `Directory.rename` / `delete` が走り、操作が無言で失敗し得る（TECH_DEBT_AUDIT F108）。さらにこのレースを固定するテストが削除フローにしか無く（F131）、TTS系の per-folder DB ハンドルは正規化キーを使っていないため `folderDbKey` の規律漏れで同じバグが再発し得る（F126）。

## What Changes

- **移動 / リネーム / 空フォルダ削除の3フロー**で、ファイル操作の前に per-folder DB ハンドル（`episode_cache.db` / `tts_audio.db` / `tts_dictionary.db`）を `await close()` してから `invalidate` する。削除フローの `releaseFolderHandles` ヘルパーと同じ「close を待ってから invalidate」順序を共有化して3フローへ展開する（F108）。
- **move / rename フローのハンドル解放順序を固定するテスト**を追加する。削除フローの `novel_delete_order_test.dart` の order-test パターンを移植し、「ファイル操作の前に全ハンドルの close が完了している」ことを検証する（F131）。
- **`tts_audio.db` / `tts_dictionary.db` の family provider 本体で `folderDbKey` による正規化を適用**し、呼び出し側がパス綴りを正規化する規律に依存しないようにする。`episode_cache` は既に正規化済みであり、それと同一のキー空間に揃える（F126）。

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `novel-folder-management`: 移動・リネーム・空フォルダ削除の各操作で、ファイル操作の前に per-folder DB ハンドルを閉じ切る（await close → invalidate）ことを要件として追加する。
- `tts-audio-storage`: `tts_audio.db` のハンドルが正規化済みフォルダパスキー（`folderDbKey`）で管理され、パス区切り文字の差異に依らず同一フォルダが同一ハンドルへ解決される要件を追加する。
- `tts-dictionary`: `tts_dictionary.db` のハンドルが正規化済みフォルダパスキーで管理される要件を追加する。

## Impact

- **コード**
  - `lib/features/file_browser/presentation/file_browser_panel.dart`: `_releaseFolderHandles`（現在は invalidate のみ）を await close 付きの共有ヘルパー呼び出しへ置換。move(:422) / 空削除(:476) / rename(:505) の3箇所。
  - `lib/features/novel_delete/providers/novel_delete_providers.dart`: 既存の `releaseFolderHandles` クロージャを共有ヘルパーへ抽出して再利用（重複解消）。
  - 共有ヘルパーの新設先（例: `lib/shared/database/` 配下）。`ref`（または各 family provider）を受けて3ハンドルを close→invalidate する純粋な振り付け関数。
  - `lib/features/tts/providers/tts_audio_database_provider.dart` ほか TTS family provider: provider 本体で `folderDbKey` を適用。
- **テスト**
  - `test/features/novel_delete/data/novel_delete_order_test.dart` 相当の move/rename 版を追加。
  - TTS family provider の正規化キー解決テスト（episode-cache の同名テストが手本）。
- **依存・契約**: 公開 API 変更なし。`folderDbKey` 適用箇所が provider 本体へ移るため、呼び出し側の正規化責務は不要になる（後方互換）。
- **プラットフォーム**: 主に Windows のファイルロック挙動に効く修正。
