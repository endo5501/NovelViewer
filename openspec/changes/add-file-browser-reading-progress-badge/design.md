## Context

ファイルブラウザ（[file_browser_panel.dart](../../../lib/features/file_browser/presentation/file_browser_panel.dart)）は、ライブラリルートや整理フォルダを開いたとき、子フォルダを一覧表示する。登録済み小説フォルダは `📖` アイコン付きで表示されるが（[novel_folder_classifier.dart](../../../lib/features/file_browser/domain/novel_folder_classifier.dart)）、読書進捗の手がかりは無い。

読書進捗データの所在は以下の通りで、いずれもグローバルの `novel_metadata.db` に存在する:
- `novels.episode_count`: 小説ごとの全話数（ダウンロード／更新時に書かれる既存カラム）。
- `reading_progress.file_name`: 最後に開いたファイル名（例 `003_chapter3.txt`）。`reading_progress` は per-novel-folder DB 移行（v8→v9）でも**意図的にグローバルに残された**（`reading_progress は移行対象に含めてはならない`）。

ダウンロード時のファイル名は `formatEpisodeFileName`（[download_service.dart](../../../lib/features/text_download/data/download_service.dart)）により `{1始まりの話数}_{タイトル}.txt` 形式。先頭の数字はその話の話数そのものであり、`sortByNumericPrefix` の並び規則とも `episode_count` とも整合する。

## Goals / Non-Goals

**Goals:**
- 登録済み小説フォルダの一覧上で、読書進捗（現在地 / 全話数）を一目で把握できるようにする。
- フォルダDB（`novel_data.db`）へアクセスせず、ファイルシステム走査も行わず、グローバルDBの軽量な参照のみで実現する。
- スキーマ変更・マイグレーションを伴わない。

**Non-Goals:**
- 手動配置フォルダ（`novels` 未登録）へのバッジ表示。今回のスコープ外（従来通りバッジなし）。
- 「到達点（読んだ最大話数）」の追跡。今回は「現在地（最後に開いた話）」のみ。
- `episode_count` を実 `.txt` ファイル数へ随時追従させる仕組み。現状の DL／更新時更新に委ねる。

## Decisions

### 決定1: 分母は `novels.episode_count`、分子は `reading_progress.file_name` の先頭数字

- **理由**: 両値とも既存カラムから取得でき、スキーマ変更不要。ファイル名先頭数字＝話数（1始まり）であることがダウンローダの命名規則から保証され、`episode_count`（全話数）と同じ基準で `read / total` を構成できる。
- **代替案**: `reading_progress` に `read_episode` / `total_episode` カラムを追加し、ファイル選択時にスナップショット保存する案。→ マイグレーションが必要になり、「保存時点の値」というステイルさも生むため不採用。先頭数字パースで同じ結果が得られる。
- **代替案**: 分子をソート後リスト内の通し番号で算出する案。→ 各フォルダのファイル一覧走査が必要になり、一覧描画が重くなるため不採用。

### 決定2: 進捗データは表示中の小説ぶんをまとめて1回で取得する

- `allNovelsProvider`（キャッシュ済）から `folderName → episode_count` を得る。
- `ReadingProgressRepository` に一括取得メソッド（`findAll` 相当）を追加し、`novel_id → file_name` を1クエリで取得する。
- 表示中の小説フォルダごとに両者を結合し、`read`（先頭数字、行が無ければ 0）と `total`（episode_count）を確定する。
- **理由**: 一覧に N 個の小説があっても DB アクセスは O(1)（2クエリ）。`findByNovelId` を N 回呼ぶ N+1 を避ける。

### 決定3: 表示はフォルダ名の下部（`ListTile.subtitle`）に進捗バー＋数値

- 横幅が限られるため、タイトル後ろのバッジは小説名の視認性を損なう。`subtitle` に細い `LinearProgressIndicator` 系の進捗バーと小さな `3 / 120` を置く。
- 2行レイアウトに伴い固定タイル高 `_kFileTileExtent`（現在 56.0）を引き上げる。この定数は `ListView.itemExtent` とスクロール位置推定の両方に使われるため、一箇所の変更で両者が連動する。
- **理由**: 既存の TTS バッジ（trailing アイコン）の前例と矛盾せず共存できる。

### 決定4: 未読（`reading_progress` 行なし）の表示

- 分母 `episode_count` を用いて `0 / N` を表示する（進捗バーは 0%）。
- **理由**: 未読でも「全何話あるか」が一覧でわかるという当初要望に最も近い。

### 決定5: 保存後のバッジ更新を `reading_progress` リビジョンで駆動する（レビュー追加）

- バッジ用プロバイダは集約値をキャッシュするため、ユーザーが小説内で読み進めて `reading_progress` が upsert されても、親フォルダ一覧へ戻ったときバッジが古いままになる（codex レビューで検出）。`reading_progress` 層に単調増加カウンタ `readingProgressRevisionProvider` を設け、auto-save リスナーが upsert 成功後に `bump()`、バッジ用プロバイダが `watch` して再計算する。
- **理由**: バッジは `reading_progress` レイヤーに既に依存しているため、リビジョンをそこに置けば `file_browser` → `reading_progress` の逆 import（循環）を生まずに済む。書き込みを発生源で1回シグナルするだけなので、ファイル選択ごとの過剰な再計算も避けられる。
- **代替案**: auto-save リスナーから直接 `ref.invalidate(readingProgressBadgesProvider)` を呼ぶ案。→ `reading_progress_providers` が `file_browser_providers` を import する循環依存になるため不採用。

## Risks / Trade-offs

- **`episode_count` と実ファイル数の食い違い** → 手動で `.txt` を削除した等のケースで分母が実態とずれうる。登録小説の通常運用（DL／更新で `episode_count` が維持される）では一致するため、スコープ外として許容。
- **先頭数字＝話数の前提** → 対象を登録済み小説（ダウンローダ命名に従う）に限定しているため成立する。先頭数字をパースできないファイル名は分子 0（未読相当）にフォールバックし、クラッシュさせない。
- **タイル高変更の波及** → `_kFileTileExtent` はスクロール自動追従計算（`_scheduleScrollTo`）にも使われる。定数を更新すれば両者が同じ値を参照するため整合は保たれるが、変更後にスクロール追従が壊れていないことを確認する。
- **現在地＝最後に開いた話の意味** → 前の話に戻ると数値も戻る。仕様として明示し、ユーザーの期待（現在地表示）と一致させる。
