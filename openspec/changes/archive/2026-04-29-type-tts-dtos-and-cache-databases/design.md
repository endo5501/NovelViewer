## Context

Sprint 2 は3つの phase が並走するが、依存関係を整理すると以下の DAG になる:

```
                   ┌─ Phase A: TTS DTO 型化 (F007/F048/F053)
                   │     │
                   │     └─ Phase A 完了後、consumer の cast 削除が連鎖
                   │
   Sprint 1 logger ┼─ Phase B: DB ライフタイム (F019/F020/F003/F058)
                   │     │
                   │     └─ database_opener が tts/dictionary/episode-cache/novel-metadata の4 DB を順次置換
                   │
                   └─ Phase C: catch retrofit (F012-F052)
                         (Sprint 1 logger 必須、Phase A/B とは独立に進められる)
```

監査時点で実装が spec から乖離している箇所が `tts-audio-storage` にあり (spec は `TtsEpisodeStatus` を返すと書いているのに実装は `Map`)、Sprint 2 はこの乖離も解消する。

**前提**: Sprint 0 と Sprint 1 は本 change 着手時点で **未マージで構わない** (planning レベルでの依存はあるが、実装順序として直列にする必要はない)。ただし Phase C のロガー retrofit は Sprint 1 の実装を必要とするため、Phase C のテスト/実装は Sprint 1 完了後に着手する。

## Goals / Non-Goals

**Goals:**
- `TtsAudioRepository` 周辺で型安全な DTO 経由の読み書きを実現し、24+ の unsafe cast を消す
- 同フォルダの DB を Riverpod family 経由で最大1インスタンスにキャッシュ、UI の DB-open スパイクを排除
- 4つの SQLite DB が共通ヘルパ経由で開かれ、再現可否によるリトライ挙動の差が**コードに明示される**
- 沈黙していた 5 sites の catch を Sprint 1 のロガー経由で観測可能にする
- 後続 Sprint 3 の `TtsEngineConfig` リファクタリングが型化済みの DTO 上で進められる地ならし

**Non-Goals:**
- `TtsEngineConfig` sealed type の導入 (F002, F040 → Sprint 3)
- `TtsSession` / `SegmentPlayer` 抽出 (F006, F037 → Sprint 3)
- god file の解体 (F004, F005 → Sprint 4, 5)
- マイグレーション失敗時の UI 通知のリッチ化 (現状の SnackBar 拡張のみ。本格的な UI は将来 Sprint で別途検討)
- ログを使った構造化メトリクス収集

## Decisions

### Decision 1: DTO は `lib/features/tts/domain/` 配下に置く

`tts-audio-storage` capability は `data` 層 (Repository, DB) と `domain` 層 (DTO, 値オブジェクト) を持つ構造に揃える。DTO はデータベース行と1:1の単純なデータクラス。`fromRow` ファクトリで Map から構築。

```dart
class TtsEpisode {
  const TtsEpisode({...});
  final int id;
  final String fileName;
  final int sampleRate;
  final TtsEpisodeStatus status;
  final String? refWavPath;
  final String? textHash;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TtsEpisode.fromRow(Map<String, Object?> row) => TtsEpisode(
    id: row['id'] as int,
    fileName: row['file_name'] as String,
    sampleRate: row['sample_rate'] as int,
    status: TtsEpisodeStatus.fromDb(row['status'] as String),
    refWavPath: row['ref_wav_path'] as String?,
    textHash: row['text_hash'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}
```

`TtsEpisodeStatus` は `enum { generating, partial, completed }` (`tts-audio-storage` spec の3値と一致)。`fromDb(String)` で文字列から復元、未知値は throw する (沈黙でフォールバックすると不整合状態が伝播する)。

**Alternatives considered:**
- *`freezed` を使う*: 値オブジェクトの copy/equality を自動生成できるが、現状他の domain 層が手書きクラスのため統一感を取って手書きにする。後で `freezed` に揃えるのは別 change で。
- *Repository を `Stream<TtsEpisode>` に変える*: SQLite の watch 機能との接続が複雑化する。今回はスコープ外。

### Decision 2: `TtsEpisodeStatus` enum を1箇所に置く

監査時点で文字列 `"generating"`, `"partial"`, `"completed"` がコードに散在。enum 化に伴い、DB 列値との変換は enum 側 (`fromDb`/`toDb`) のみが知る。`TtsEpisodeStatus.none` は DB 行が無いケースを表現する **app-level の状態** であり、enum には含めない (`TtsEpisode?` の null で表現する)。

### Decision 3: `TtsRefWavResolver` を共有ヘルパに

F048 で指摘された "null vs '' vs path" のトリ状態は2箇所 (streaming/edit) で異なる形 (ternary / switch) で書かれている。共通ヘルパに集約:

```dart
class TtsRefWavResolver {
  static String? resolve({
    required String? storedPath,
    required String? fallbackPath,
  }) {
    if (storedPath == null) return fallbackPath;     // 未設定 → fallback
    if (storedPath.isEmpty) return null;             // 明示的に "なし"
    return storedPath;                                // 明示的なパス
  }
}
```

両 controller を `TtsRefWavResolver.resolve(...)` 呼び出しに統一する。

**Alternatives considered:**
- *`sealed class TtsRefWav { Inherit, None, Path }`*: より型安全だが、現行コードからの変換コストが高い。Sprint 3 で sealed に進化させる余地を残しつつ今回は static helper に留める。

### Decision 4: `database_opener` ヘルパは関数1個、`deleteOnFailure` で挙動切替

```dart
Future<Database> openOrResetDatabase({
  required String path,
  required int version,
  required Future<void> Function(Database, int) onCreate,
  Future<void> Function(Database, int, int)? onUpgrade,
  bool deleteOnFailure = false,
  Logger? logger,
}) async {
  try {
    return await openDatabase(path, version: version, onCreate: onCreate, onUpgrade: onUpgrade);
  } catch (e, st) {
    logger?.warning('Failed to open database at $path', e, st);
    if (!deleteOnFailure) rethrow;
    logger?.info('deleteOnFailure=true: removing corrupt database and retrying');
    await File(path).delete();
    return openDatabase(path, version: version, onCreate: onCreate, onUpgrade: onUpgrade);
  }
}
```

ロガーは optional。テストでは inject、本番では各 DB の feature ロガーを渡す。

### Decision 5: F058 — `NovelDatabase` は `deleteOnFailure: false`

ユーザー回答待ちだったが、auto mode で進めるため**現状維持の明文化**を採用:
- `NovelDatabase` (`novel_metadata.db`) はブックマーク・小説タイトル・ダウンロード履歴を保持し、再現不可能
- 自動削除は永久データ損失を意味するため、open 失敗時は throw する (起動失敗で気づける)
- spec に新規要件「自動削除しない」を ADDED として明示化
- 将来「破損時に user-driven リセット UI」が必要になれば別 change で扱う

**Open question for the user**: ブックマーク等を失わない範囲での自動回復策があるか? (バックアップ→破損検出→ロールバック等。Sprint 2 のスコープ外だが、F058 の長期方針として確認したい)

### Decision 6: Riverpod family の disposal 戦略

`Provider.family<TtsAudioDatabase, String>` は `ref.onDispose` で `db.close()` を呼ぶ。`autoDispose` は使わない:
- `directoryContentsProvider` と `text_viewer_panel.dart` の両方が同じインスタンスを参照する間は alive にしたい
- `autoDispose` を使うと参照がない瞬間に閉じ、再 open のコストが戻ってくる
- アプリ終了時は `ProviderContainer.dispose()` 経由で全 family が解放される

ただし「フォルダ移動時に旧フォルダの DB を解放する」要件は別途必要。`directoryContentsProvider` で現フォルダパスを `ref.watch` し、変更時に `ref.invalidate(ttsAudioDatabaseProvider(oldPath))` を呼ぶ形にする。

**Alternatives considered:**
- *`autoDispose` + `keepAlive`*: 期待挙動を `keepAlive` でなんとか作れるが、明示 `invalidate` のほうがコードが読みやすい。

### Decision 7: 音声状態の `FutureProvider.family<TtsAudioState, String>`

ファイルパス → 音声状態の lookup は現状 `_checkAudioState` 内で毎回 DB を開いていた。Riverpod 化:

```dart
final ttsAudioStateProvider = FutureProvider.family<TtsAudioState, String>((ref, filePath) async {
  final folder = path.dirname(filePath);
  final db = ref.watch(ttsAudioDatabaseProvider(folder));
  final episode = await db.repository.findEpisodeByFileName(path.basename(filePath));
  return TtsAudioState.fromEpisode(episode);
});
```

`text_viewer_panel.dart` の `_lastCheckedFileKey` ceremony は不要になる。

### Decision 8: Phase C のテストはロガーキャプチャ + 既存挙動の両方を assert

各 retrofit 対象 site で:
1. 既存の "fallback / skipped count / empty map" が変わらないこと
2. `Logger.root.onRecord` 経由で期待 logger 名・level の `LogRecord` が出ること

をテストする。テストフィクスチャは Sprint 1 で作る `AppLogger` の test helper を流用。

### Decision 9: `DownloadResult.failedCount` の追加は破壊的でないように

既存 consumer (`download_service` の呼び出し元) は `failedCount` を見ない可能性があるため、新フィールドはオプショナル/デフォルト値あり (`int failedCount = 0`)。UI 側 (`SnackBar` 表示) で「失敗N件」を末尾に付け足す。

### Decision 10: ロガー名の規約 (Sprint 1 設計の具体化)

各 catch retrofit 対象に対して:
- `text_download` (download_service): `Logger('text_download')`
- `text_download.migration` (novel_library_service): `Logger('text_download.migration')`
- `tts.streaming` (tts_streaming_controller): `Logger('tts.streaming')`
- `llm_summary` (llm_summary_pipeline): `Logger('llm_summary')`
- `file_browser` (file_browser_providers): `Logger('file_browser')`

将来のフィルタリングを意識した dotted form。Sprint 1 spec の "Per-module logger naming convention" と整合する。

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| F007 の影響範囲 (6+12 ファイル) でレビューが重い | 1 PR 想定だが commit 粒度を Phase A/B/C で分け、レビュー単位を明示。テストも段階的に追加 |
| Riverpod family が古いフォルダの DB を保持し続けてメモリ膨張 | Decision 6 の `invalidate(oldPath)` パターンで対応。テストで「フォルダ切替時に旧 DB が close される」を assert |
| 型移行中に `Map<String, Object?>` と DTO が一時的に混在し型エラーが噴出 | Phase A 内部の commit 順を「DTO 追加 → Repository 戻り値変更 → consumer 更新」と段階化。consumer 更新は1ファイルずつ |
| `TtsEpisodeStatus.fromDb` の未知値 throw が既存 DB の不整合データで発火 | spec 上は3値 (`generating`/`partial`/`completed`) のみが書ける契約だが、念のため migration 時に検査スクリプトを add (or 起動時の sanity check) — 別 change へ繰り出す候補。現時点は throw |
| F058 の "NovelDatabase 自動削除しない" 方針で、既に破損したユーザー DB を救済できない | spec で明文化、ユーザーには (将来の) リセット UI で回復路を提供する旨を Open Question 経由で残す |
| catch retrofit がうっかり挙動を変えると download/migration のリトライ動作が変わる | 各 site でリカバリパス自体は不変、ログ追加のみ。テストで挙動同値を assert |
| Riverpod family の dispose 中に in-flight の DB query が走っていた場合 | DB close 時に query は SQLite 側で abort されるか、未使用接続として安全に閉じられる。テストで race を狙うのは過剰 |

## Migration Plan

### Phase A (TTS DTO)
1. `TtsEpisodeStatus` enum + テスト
2. `TtsEpisode` / `TtsSegment` データクラス + `fromRow` テスト (TDD)
3. `TtsAudioRepository` 戻り値を順次 DTO 化 (TDD で1メソッドずつ)
4. consumer 6 ファイルを順次 DTO 経由読み出しに変更
5. `TtsRefWavResolver` 追加、2 controller の resolve ロジックを置換
6. `text_viewer_panel.dart` の cast 削除 (F053)

### Phase B (DB ライフタイム)
1. `database_opener.dart` ヘルパ + テスト (success / corrupt with delete / corrupt without delete)
2. `TtsAudioDatabase` を `database_opener` 経由に置換 (`deleteOnFailure: true`)
3. 残り3 DB も同様 (`TtsDictionaryDatabase`, `EpisodeCacheDatabase`, `NovelDatabase` ※後者は false)
4. `ttsAudioDatabaseProvider` (Riverpod family) 実装 + invalidate パターンテスト
5. 同パターンを dictionary/episode-cache にも展開
6. `directoryContentsProvider` を family-cached DB 経由に書き換え
7. `ttsAudioStateProvider` (FutureProvider.family) 実装、`text_viewer_panel.dart` の `_checkAudioState` 削除
8. 旧 `_lastCheckedFileKey` ceremony を削除

### Phase C (Logger retrofit)
※ Sprint 1 完了後着手
9. `download_service.dart` F012: `failedCount` 追加 + ログ
10. `novel_library_service.dart` F013: マイグレーション失敗ログ
11. `tts_streaming_controller.dart` F014: stop() cleanup ログ
12. `llm_summary_pipeline.dart` F016: jsonDecode ログ
13. `file_browser_providers.dart` F052: DB read 失敗ログ
14. UI 側 (SnackBar) で `failedCount` 表示

**Rollback**: Phase A だけ revert すると consumer 側が型エラーになるため不可分。Phase B は DB 単位で revert 可能。Phase C は site 単位で独立に revert 可能。

## Open Questions

1. **F058 長期方針**: `NovelDatabase` 破損時に「ブックマーク以外を保つ自動回復」は将来やるか? (現時点はスコープ外、保留)
2. **`failedCount` の UI 表現**: SnackBar に「失敗N件」を末尾に付け足す案が design.md の暫定。詳細文言・色 (warning vs error) は実装中に確定
3. **Phase C のテスト粒度**: `LogRecord` の message 文字列を厳密一致で assert すると変更に弱い。"contains substring" 単位での部分一致を採用する案で進める。design 確定でなく実装中に微調整
