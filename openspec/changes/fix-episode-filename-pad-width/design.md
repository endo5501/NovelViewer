## Context

エピソードのファイル名は `formatEpisodeFileName(index, title, totalEpisodes)`（`download_service.dart:22-27`）で生成され、ゼロ埋め幅は `totalEpisodes.toString().length` に依存する。

```dart
String formatEpisodeFileName(int index, String title, int totalEpisodes) {
  final padWidth = totalEpisodes.toString().length;   // ← 総話数の桁数
  final paddedIndex = index.toString().padLeft(padWidth, '0');
  final safeTitle = safeName(title);
  return '${paddedIndex}_$safeTitle.txt';
}
```

スキップ判定 `_canSkipEpisode`（`download_service.dart:440-455`）も同じ関数で **現在の** `total` を使ってファイル名を再計算し、`localFile.existsSync()` で存在確認する。

```
総話数 99 → 100 に増えた場合:
  既存ファイル: 01_x.txt 02_x.txt … 99_x.txt   (旧 padWidth=2)
  新 padWidth=3 → _canSkipEpisode は 001_x.txt を探す → 存在しない
  → 全話を「未取得」と誤判定し再DL、旧 01_…99_ がゴミ残留
```

DL本体のループは `_downloadEpisodes`（`download_service.dart:341-438`）にあり、その先頭で `total = novelIndex.episodes.length`（=確定した新しい総話数＝新しい桁幅）が分かる。エピソードキャッシュ（`episode_cache.db`）はURLキーで `lastModified` 等を保持するのみで、ファイル名は保存しておらず毎回再計算される。

## Goals / Non-Goals

**Goals:**
- 総話数が桁を跨いでも（増加・減少どちらも）、既存の正しいエピソードファイルが不要に再DLされないようにする。
- 旧桁幅のゴミファイルを残さない（既に被害を受けたライブラリも次回更新時に自己修復する）。
- DBスキーマ・キャッシュを一切変更せず、物理ファイルのリネームのみで移行する。冪等であること。

**Non-Goals:**
- エピソードタイトル変更による孤児化の解消（桁問題と独立した既存挙動）。
- 上流で削除され現index に存在しなくなった高index ファイル（小説の話数が減って末尾が消えた等）の掃除。
- 短編（単一ファイル・総話数1固定）への特別対応（桁を跨がないため自然に no-op）。

## Decisions

### 決定1: DLループ直前に「桁幅移行パス」を1回だけ実行する

`_downloadEpisodes` で `total` 確定後・エピソードループ開始前に、対象フォルダを1回だけ走査して旧桁幅ファイルを新桁幅へリネームするパスを挟む。スキップ判定の前に移行を完了させることで、移行後は `_canSkipEpisode` が新桁幅で正しくヒットする。

- **代替案: `formatEpisodeFileName` を固定幅にする** → 既存ファイルは全てミスマッチのままなので結局一度は再DL（か別リネーム）が必要。さらに固定幅 N を超える超長編で再発する。採用しない。
- **代替案: 起動時/別タスクの一括マイグレーション** → 全フォルダ走査が必要でコストとタイミングが不透明。DL/更新時に当該フォルダだけ遅延移行する方が局所的で安全。採用しない。

### 決定2: 旧ファイルの特定はフォルダ走査＋(index, safeTitle) 照合で行う

旧 `total`（旧桁幅）は保存していないため推測しない。フォルダ内の `.txt` を1回 list し、各ファイル名を `^(\d+)_(.+)\.txt$` でパースして `(parsedIndex, restName)` を得る。現index の各エピソード `(i, title)` について `newName = formatEpisodeFileName(i, title, total)` を求め、

- `parsedIndex == i` かつ `restName == safeName(title)` を満たす既存ファイルを「同一エピソードの別桁幅版」とみなす。
- `index` はエピソード一意なので衝突しない。`restName` 一致条件によりタイトル変更ファイルは（意図的に）対象外。

走査は1回（per-episode の glob ではない）。`listSync` は DL サービス内（既にファイルIOを行う文脈）であり、UIスレッドのホットパス（F162とは別文脈）ではないため許容。

### 決定3: リネームと残留ゴミ削除の条件

- `newName` が存在しない、かつ別桁幅の一致ファイルが1つある → そのファイルを `newName` へ `rename`（＝移動なので旧ファイルは消える）。
- `newName` が既に存在する、かつ別桁幅の一致ファイルも残っている（過去のバグ済み再DLで両方できてしまった被害ケース）→ **正規ファイル `newName` は触らず、別桁幅の一致ファイル（ゴミ）のみ削除** して残留を解消する。
- どちらも該当しなければ no-op（冪等）。
- 削除/リネーム対象は「現index に存在するエピポード」かつ「parsedIndex 一致 + safeTitle 一致 + ファイル名が `newName` と異なる」もののみ。正規ファイルは決して削除しない。

### 決定4: 桁の増加・減少を対称に扱う

`padWidth` は増加（99→100）でも減少（100→99で 3→2）でも変わり得る。決定2の照合は桁の大小に依存しないため、両方向を同じロジックで移行できる。

## Risks / Trade-offs

- [ファイル削除/リネームの誤爆] → 対象を `(parsedIndex == i かつ restName == safeName(title) かつ != newName)` に厳密化し、現index のエピソードに限定。正規 `newName` は決して削除しない。境界（増加・減少・両方存在・タイトル変更非対象）を網羅するテストで固定する。
- [リネーム中の例外（Windowsファイルロック等）] → 個々のリネーム/削除を try で囲み、失敗は WARNING ログにとどめて当該エピソードの移行をスキップ（最悪その話だけ再DLに退行＝従来挙動）。DL全体は止めない。
- [タイトル変更ファイルは移行されない] → スコープ外（Non-Goals）。桁問題とは独立の既存挙動であり本変更で悪化させない。
- [大量ファイルでの list コスト] → 1ダウンロードにつき1回の list で、エピソードDLのネットワークコストに対して無視できる。

## Migration Plan

- マイグレーション手段は不要。コード変更のみで、対象フォルダの次回ダウンロード/更新時に遅延的に自己移行する。DBバージョン更新なし。
- ロールバック: コードを戻すだけでよい。移行済みファイルは「現在の桁幅に正しく一致した名前」なので、旧コードに戻しても（旧コードも同じ `formatEpisodeFileName` を使うため）整合する。

## Open Questions

- なし（Open question #5 はメンテナ確認済みで「バグ・修正対象」と決着）。
