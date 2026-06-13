## Context

NovelViewer は5種のSQLiteラッパーを持つ:

- グローバル `NovelDatabase`（長寿命シングルトン、起動時に1回 open、`deleteOnFailure:false`）
- per-folder の `EpisodeCacheDatabase` / `TtsAudioDatabase` / `TtsDictionaryDatabase`（フォルダ単位、Riverpod `family` provider がハンドルを保持、`deleteOnFailure:true`）

全ラッパーが同型の素朴なライフサイクルを持つ（`tts_audio_database.dart:137-139`、`novel_database.dart:71-75`）:

```dart
Database? _database;
Future<Database> get database async {
  final db = _database;
  if (db != null) return db;
  return _database = await _open();   // in-flight open ガードなし
}
Future<void> close() async {
  await _database?.close();           // in-flight open とのインターロックなし
  _database = null;
}
```

このパターンには2つの欠陥がある。**(1) 二重 open**: `_database == null` の状態で getter が並行に2回呼ばれると `_open()` が2回走る。**(2) close-after-open レース**: close が走った時点で getter が `await _open()` 中（`_database` はまだ null）だと、close の `_database?.close()` は no-op で素通りし、その後 open が完了して `_database = <新ハンドル>` を**close 完了後に**代入する。結果、閉じたはずのファイルが再ロックされ、直後の `Directory.rename`/`delete` が Windows のファイルロックで無言失敗する。これが F108/F126 で widget 層の振り付け（`file_browser_panel.dart:586-615`）と共有ヘルパー `releaseFolderDbHandles`（`lib/shared/database/folder_db_handles.dart`）が覆い隠している根本原因（F124）。

現状の解放ヘルパーは「awaited close → invalidate」の順序を守るが、これは**呼び出し側が正しい順序を書く規律**に依存しており、per-folder DB provider に新しい消費者を1つ足すたびに再発リスクがある（F125）。

## Goals / Non-Goals

**Goals:**
- 全DBラッパーの `database` getter / `close()` を、二重 open と close-after-open レースが構造的に起こり得ない**インターロック**にする（F124）。横断的な単一実装に集約し、4ラッパーへコピペしない。
- per-folder ハンドルの open/close を所有する**レジストリ**を導入し、awaitable な `closeAll(folder)` を per-folder DB 解放の単一 sanctioned API にする。Riverpod provider はレジストリ上の薄いビューにする（F125）。
- 既存の観測可能な契約「ファイル操作の前に3ハンドルの close 完了」（`novel-folder-management` spec、widget order-test）を後退させない。

**Non-Goals:**
- F111（abort の use-after-free、third_party 監査が必要）、F104（ゼロ埋め桁繰り上がり）。
- `openOrResetDatabase` の復旧ポリシー（`database-recovery` spec）の変更。インターロックはその外側に重ねる。
- グローバル `NovelDatabase` をレジストリへ載せること（シングルトンであり per-folder ではない。インターロックのみ適用）。
- SQLite のスキーマ・マイグレーション・DBパス解決（F173）への変更。
- `novel_database.dart` 内の NUL バイト dedup キー（F166）の修正。本changeの編集で当該箇所に触れないこと。

## Decisions

### D1. インターロックを共有ゲート `DbConnectionGate` に集約する（F124）

`lib/shared/database/` に再利用可能なゲートを新設し、各ラッパーは `Database? _database` の代わりにゲートを1つ保持して `database`/`close` を委譲する。ゲートは `opener`（`Future<Database> Function()`、各ラッパーの既存 `_open()` をそのまま渡す）でパラメタ化する。

状態:

```dart
class DbConnectionGate {
  DbConnectionGate(this._opener);
  final Future<Database> Function() _opener;
  Future<Database>? _open;   // open 開始後 non-null。解決後の値が生ハンドル
  bool _closing = false;

  Future<Database> get database {
    if (_closing) {
      throw DatabaseClosingException();      // (B) close 進行中の getter は明示エラー
    }
    return _open ??= _openOnce();            // in-flight open を共有（二重 open 防止）
  }

  Future<Database> _openOnce() async {
    try {
      return await _opener();
    } catch (_) {
      _open = null;                          // 失敗した Future はキャッシュしない（次回再試行可）
      rethrow;
    }
  }

  Future<void> close() async {
    _closing = true;
    try {
      final opening = _open;
      if (opening != null) {
        try {
          final db = await opening;          // in-flight open の決着を待ってから
          await db.close();                  // その同一ハンドルを閉じる
        } on DatabaseClosingException {
          rethrow;
        } catch (_) {
          // open 自体が失敗していた場合は閉じるハンドルなし（握って続行）
        }
      }
      _open = null;                          // close 後は再 open 可能な初期状態へ
    } finally {
      _closing = false;
    }
  }
}
```

**根拠**: `_open` を「in-flight open と open 済みハンドルの両方を表す単一の Future キャッシュ」にすることで、二重 open（並行 getter は同じ Future を共有）と close-after-open レース（close は必ず in-flight open を await してからそのハンドルを閉じる）の両方が単一の不変条件で消える。close 完了後に `_open=null` へ戻すことで、フォルダ切替後の同一インスタンス再利用やテストでの再 open も透過的に成立する。

**代替案**:
- *ラッパーごとに mixin* → ゲートの状態フィールド3つを mixin が要求し各ラッパーへ混ぜる形。委譲（composition）の方がテスト時にゲート単体を直接駆動でき、ラッパーの他フィールドと干渉しないため採用しない。
- *`synchronized` パッケージで mutex* → 新規依存。単一 Future キャッシュで十分に表現でき、依存追加は不要。

### D2. close 進行中の getter は `DatabaseClosingException` を投げる（B案・確定済み）

`close()` 中（`_closing == true`）に `database` が呼ばれた場合、再 open せず明示的に例外を投げる。透過的な再 open（A案）は「閉じたいのに開き直す」競合の温床になるため不採用。消費者は close 完了後にレジストリ（D3）経由で新インスタンスを取得する。

**根拠**: 削除/移動の最中に偶発的にハンドルを掴む経路を**失敗として可視化**する。沈黙して再ロックするより、テスト可能な明示エラーの方がレース検出に資する。例外型は `lib/shared/database/` に新設し、レジストリ（D3）が `closeAll` を原子的に振り付けるため、production 経路でこの例外が出るのは「close 中に正規外の経路がハンドルを掴んだ」異常時のみ。

### D3. per-folder ハンドルレジストリがハンドルを所有し、provider は薄いビューにする（F125）

`lib/shared/database/per_folder_db_registry.dart` を新設。レジストリは `Map<String /*folderDbKey*/, _FolderHandles>` を所有し、3つの per-folder DB を `folderDbKey` 正規化キーで保持する。

- `EpisodeCacheDatabase episodeCache(String folder)` / `ttsAudio(...)` / `ttsDictionary(...)`: 正規化キーで取得（なければ生成してキャッシュ）。
- `Future<void> closeAll(String folder)`: 当該キーの3ハンドルを await close し、マップから除去する。**per-folder DB 解放の唯一の sanctioned API**。
- Riverpod の `episodeCacheDatabaseProvider` ほかは `ref.watch(perFolderDbRegistryProvider).episodeCache(key)` を返す薄い `Provider` に縮退する。

`releaseFolderDbHandles`（fire-and-forget invalidate を含む現行ヘルパー）と widget 層の振り付けは `registry.closeAll(folder)` の呼び出しへ置換する。レジストリがハンドルを所有するため `ref.invalidate` による解放は不要になり、「invalidate の onDispose close が await されない」fire-and-forget 経路そのものが消える。

**根拠**: audit F125 の意図「open/close を所有するレジストリ＋provider は薄いビュー」に一致。所有を1箇所へ集約することで、新しい消費者は `closeAll` を経由せざるを得ず、locked-DB バグを構造的に再発不能にする。D1 のゲートにより各ハンドル close 自体も既にレース安全。

**代替案**: *facade-only*（family provider を所有のまま残し、レジストリは `closeAll` コーディネータのみ＝現 `releaseFolderDbHandles` の改名）。実装は軽いが「provider が所有者のまま」で F125 の規律（薄いビュー化）を満たさず、新消費者が provider を直接掴んでバイパスし得る。根治を目的とする本changeでは所有移管（owns-map）を採用する。

### D4. 段階適用（インターロック先行 → レジストリ後続）

D1（ゲート）を先に全ラッパーへ入れると、現行の `releaseFolderDbHandles`（awaited close → invalidate）はゲートのインターロックにより既にレース安全になる。その上で D3（レジストリ）を載せる。各段でテストを緑に保ち、観測可能な「close→file-op 順序」を後退させない（Migration Plan 参照）。

## Risks / Trade-offs

- **[Riverpod 所有移管による退行]** provider を薄いビューへ縮退させる過程で dispose/invalidate セマンティクスが変わる → D4 の段階適用。D1 を先に確定し、D3 は既存の widget order-test（`file_browser_handle_release_order_test.dart`）と folder-switch test を緑に保ったまま差し替える。
- **[close が in-flight open の reject を await してハング/伝播]** → `_openOnce` は失敗時に `_open=null` にして reject を再スローし、close 側は open 例外を握って「閉じるハンドルなし」として続行する。ゲートは `_opener` 内へ再入しない不変条件を明文化（reentrancy 禁止）。
- **[B案で正規経路が close 中の getter 例外を踏む]** → レジストリ `closeAll` が close→eviction を原子的に振り付けるため、production では close 完了後に新インスタンスが渡る。例外が出るのは異常経路のみで、それを顕在化させるのが本案の狙い。テストで「closeAll 実行中の getter が例外」を固定する。
- **[グローバル `NovelDatabase` の扱い]** シングルトンゆえレジストリ非対象だが、ゲート（D1）は適用する。close() は主に起動シーケンス/テスト用。per-folder と同じゲート実装を共有してテストコストを抑える。
- **[F166 NUL バイトへの巻き込み]** `novel_database.dart` を編集する際、当該 dedup キー領域に触れないこと（本changeの Non-Goal）。

## Migration Plan

1. **(TDD) ゲートの失敗テスト先行**: 並行 getter が同一ハンドルを共有 / close が in-flight open を await してそのハンドルを閉じる / close 中の getter が `DatabaseClosingException` / close 後に再 open 可能 / open 失敗 Future を非キャッシュ。
2. `DbConnectionGate` + `DatabaseClosingException` を `lib/shared/database/` に実装し、まず `TtsAudioDatabase` を委譲へ移行。緑化。
3. 残り3ラッパー（`EpisodeCacheDatabase` / `TtsDictionaryDatabase` / `NovelDatabase`）をゲートへ移行。緑化。
4. **(TDD) レジストリの失敗テスト先行**: `closeAll(folder)` が3ハンドルを await close しマップから除去 / provider がレジストリ経由で同一ハンドルを返す / `folderDbKey` 正規化（`/` と `\` が同一キー）。
5. `PerFolderDbRegistry` + `perFolderDbRegistryProvider` を実装し、per-folder provider 群（約8呼び出し箇所）を薄いビューへ縮退。`releaseFolderDbHandles` 呼び出しを `registry.closeAll` へ置換。widget order-test / folder-switch test を緑に保つ。
6. 旧 `releaseFolderDbHandles` と fire-and-forget invalidate 経路を削除。
7. **最終確認**: code-review / codex / `fvm flutter analyze` / `fvm flutter test`。

**ロールバック**: 各ステップは独立に revert 可能。ステップ1–3（インターロック）はステップ4–6（レジストリ）を後続change送りにしても単独で価値があり、安全な中断点になる。

## Open Questions

1. グローバル `NovelDatabase` の `close()` は production で呼ばれるか、テスト専用か。前者ならゲートの「close 後再 open」挙動の対象シナリオを spec へ追加する（現時点ではテスト/起動ライフサイクル前提で設計）。
2. レジストリのキャッシュ生存期間: `closeAll` 後の eviction で十分か、フォルダ切替時に明示 eviction も要るか（既存の folder-switch 解放テストの挙動に合わせる）。
