## Context

`novel-folder-management` の導入後、ライブラリは以下のようにネスト可能になった。

```
D:/library/
  └─ お気に入り/            ← 整理フォルダ（DB未登録）
       └─ narou_n1234ab/     ← 小説フォルダ（novels.folder_name に登録済み）
            ├─ 001_xxx.txt
            └─ 002_yyy.txt
```

このとき「この小説の novel_id は何か」を、現状3つの異なる規則が並存している。

| 機能 | 現在の規則 | 上例の結果 |
|------|-----------|-----------|
| ブックマーク保存 (`currentNovelIdProvider:20-21`) | `p.split(relative).first`（第1セグメント） | `お気に入り` ✗ |
| 読書進捗 保存/自動オープン (`reading_progress_providers.dart:61`) | 同上 | `お気に入り` ✗ |
| タイトル表示 (`selectedNovelTitleProvider:127-131`) | 最深部から遡り最も近い登録済み葉名 | `narou_n1234ab` ✓ |
| 小説フォルダ判定 (`isNovelFolder`) | 葉名が登録済みか | `narou_n1234ab` ✓ |
| 削除カスケード (`NovelDeleteService.delete(dir.name)`) | 葉名（`dir.name`） | `narou_n1234ab` ✓ |

save 側（第1セグメント派）と delete/classifier 側（葉名派）の食い違いが F106 / F107 / F127 の共通根である。

制約:
- `novel_metadata.db` の現行バージョンは 7。本changeはスキーマを変更しない（F128 のパス相対化は後続change）。
- `allNovelsProvider` は `FutureProvider`（非同期）。folder_name の集合はここからしか得られない。
- 小説フォルダのリネームは元々サポート外（`_showRenameFolderDialog` は `novels.folder_name` を更新しない）。よって `folder_name` はダウンロード時に固定される安定キーとして扱える。

## Goals / Non-Goals

**Goals:**
- novel_id 解決規則を「最も近い登録済み祖先フォルダの葉名（folder_name）」に一本化し、save↔delete↔classifier↔title を一致させる。
- ネスト小説の整理フォルダ間移動でブックマーク/進捗が孤児化しないようにする（F106）。
- 小説削除時に bookmarks もカスケード削除する（F107）。
- 削除のDB削除を単一トランザクションで原子化する（F127）。

**Non-Goals:**
- 絶対 `file_path` → 相対パスへのスキーマ移行（F128）。後続changeで対応。
- マイグレーション（DBバージョン昇格）。本changeはスキーマ非変更。
- 小説フォルダ自体のリネーム対応や、移動後の `reading_progress.file_path` 自動追従（これも file_path がらみで F128 の領域）。

## Decisions

### Decision 1: 共有リゾルバ `resolveNovelId` を新設し、葉名（folder_name）に統一

```dart
// lib/shared/utils/novel_id_resolver.dart
/// libraryRoot から path を下り、最も近い「登録済み小説フォルダ名」を返す。
/// 整理フォルダのネスト深度に依存しない。該当なし／ライブラリルート／
/// ライブラリ外は null。
String? resolveNovelId(
  String libraryRoot,
  String path,
  Set<String> registeredFolderNames,
);
```

走査は `selectedNovelTitleProvider:115-131` と同一（`p.relative` → `p.split` → reversed で最深部から登録済み葉名を探す）だが、**title ではなく folder_name を返す**点が異なる。`selectedNovelTitleProvider` 内の探索ロジックも将来的にこの関数へ寄せられる（本changeでは必須にしないが、重複を避けるため内部で利用してもよい）。

**フォールバックの扱い**: `selectedNovelTitleProvider` は「登録済み祖先が無ければ第1セグメントのフォルダ名を返す」フォールバックを持つ（整理フォルダのみのパス等でタイトル欄を埋めるため）。一方 `resolveNovelId` は **永続キー**なので、登録済み祖先が見つからない場合は **null を返す**（第1セグメントへフォールバックしない）。これにより「整理フォルダ名を novel_id として誤って永続化する」F106 の再発を構造的に防ぐ。

- 代替案: 各 provider 内に走査ロジックをコピー → 却下（規則が再び分岐する。F137 と同種の「3箇所に同一不変条件」アンチパターン）。

### Decision 2: `currentNovelIdProvider` を `FutureProvider<String?>` 化（A案）

`resolveNovelId` は `registeredFolderNames`（= `allNovelsProvider` の folder_name 集合）を要求するが、`allNovelsProvider` は非同期。現行の同期 `Provider<String?>` のままでは解決できない。

```dart
final currentNovelIdProvider = FutureProvider<String?>((ref) async {
  final currentDir = ref.watch(currentDirectoryProvider);
  final libraryPath = ref.watch(libraryPathProvider);
  if (currentDir == null || libraryPath == null) return null;
  final novels = await ref.watch(allNovelsProvider.future);
  final registered = {for (final n in novels) n.folderName};
  return resolveNovelId(libraryPath, currentDir, registered);
});
```

消費側の追従:
- `bookmarkLineNumbersForFileProvider`（既に `FutureProvider`）→ `await ref.watch(currentNovelIdProvider.future)`。
- 読書進捗リスナーは `ref.listen` の async コールバック内で novel_id を再導出している（`reading_progress_providers.dart:57-61`）。ここは `currentNovelIdProvider` を watch せず、リスナー内で **直接 `resolveNovelId` を呼ぶ**（Riverpod の派生 invalidation 順序に依存しない既存方針を維持）。folder_name 集合は `ref.read(allNovelsProvider.future)` で取得。
- ブックマークボタン等の同期消費箇所があれば `AsyncValue` を `.maybeWhen` で受ける形に追従。

**代替案 B（却下）**: `registeredFolderNamesProvider` を同期派生（`allNovels.valueOrNull`）で用意し `currentNovelIdProvider` を同期のまま保つ。→ 起動直後のロード中に null を返す窓が生まれ、監査 F138 が問題視する「ロード中 no-op の sync provider」を再生産するため却下。FutureProvider 化のほうが「ロード中＝未確定」を型で表現でき一貫する。

### Decision 3: 削除カスケードに bookmarks を追加し、DB削除を `db.transaction` で包む（F107 + F127）

`BookmarkRepository.deleteByNovelId(novelId)` を新設（既存の `deleteByNovelId` パターンを踏襲）。`NovelDeleteService.delete` のステップ3（ファイル削除成功後のDB削除）を以下に変更:

```dart
// 3. ファイル削除成功後、DB行を1トランザクションで原子的に削除
final db = await novelDatabase.database;
await db.transaction((txn) async {
  await novelRepository.deleteByFolderName(folderName, txn: txn);
  await summaryRepository.deleteByFolderName(folderName, txn: txn);
  await factCacheRepository.deleteByFolderName(folderName, txn: txn);
  await readingProgressRepository.deleteByNovelId(folderName, txn: txn);
  await bookmarkRepository.deleteByNovelId(folderName, txn: txn);  // F107
});
```

5テーブルとも同一の `novel_metadata.db` 上にあるため単一トランザクションで包める。各リポジトリの delete 系メソッドに任意の `Transaction? txn` を受ける口を足し、未指定時は従来どおり `database` を使う（後方互換）。

- 順序の不変条件（ファイル削除 → DB削除）は維持。トランザクションはステップ3の内部に閉じる。
- 代替案: トランザクション無しのまま bookmarks だけ追加 → 却下（F127 を残すと部分削除の孤児化リスクが残る。同じ関数を触るので一括が効率的）。

### Decision 4: novel_id が「葉名」であることを前提に既存挙動を保つ

非ネスト小説（`library/narou_n1234ab/`）では第1セグメント == 葉名であり、既存データの novel_id は不変。よって既存の非ネストユーザのブックマーク/進捗はそのまま機能する（マイグレーション不要）。**挙動が変わるのはネスト配置済みの小説のみ**で、これらは現状すでに孤児化しており壊れているため、修正により「正しい葉名キーで保存・解決される」状態へ移行する（過去に第1セグメントで保存された孤児行は残るが、F128 後続changeのクリーンアップ対象とする）。

## Risks / Trade-offs

- **[既存の孤児行が残る]** 本changeより前にネスト状態で第1セグメントキーで保存されたブックマーク/進捗行は、規則変更後に参照されなくなる（孤児化したまま）。→ 影響は限定的（ネスト＋移動を行った少数ユーザのみ）。クリーンアップは F128 後続changeのワンショット移行に含める。本changeでは新規保存・解決が正しくなることを優先。
- **[FutureProvider 化による消費側の波及]** `currentNovelIdProvider` を watch する全箇所が `AsyncValue` 対応に変わる。→ 影響箇所をコンパイルエラー駆動で洗い出し、各所で `.maybeWhen`/`await .future` に追従。テストで回帰を固定。
- **[同名葉フォルダの衝突]** 異なる整理フォルダ配下に同じ folder_name が2つ存在すると novel_id が衝突する。→ `novels.folder_name` は `UNIQUE` 制約があり（`novel_database.dart:106`）、DB登録上は同名葉が同時に存在し得ないため実害なし。物理FS上に未登録の同名フォルダがある場合も `registeredFolderNames` 集合での照合なので誤検出しない。
- **[リスナー内の二重導出]** 読書進捗リスナーが `currentNovelIdProvider` を使わず `resolveNovelId` を直接呼ぶため、規則の実装が「provider 経由」と「直接呼び出し」の2経路になる。→ どちらも同一の純関数 `resolveNovelId` を呼ぶことで規則自体は一本化されるので許容（F106 の根である「規則の分岐」は解消される）。

## Migration Plan

- スキーマ変更なし。DBバージョンは 7 のまま。
- デプロイは通常リリースに含めるだけ。ロールバックは差し戻しで可（DB非互換変更がないため安全）。
- F128 後続change側で、孤児行クリーンアップ + `file_path` 相対化マイグレーション（v8）をまとめて実施する。

## Open Questions

- `selectedNovelTitleProvider` の内部走査を `resolveNovelId` 利用へ寄せるか（重複削減）。本changeでは任意。やる場合はタイトル欄のフォールバック（登録済み祖先なし → 第1セグメント名表示）の挙動を変えないよう、resolver の null をフォールバックで包む形にする。
