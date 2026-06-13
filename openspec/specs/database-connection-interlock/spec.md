## Purpose

Guarantee that all SQLite database wrappers (the global `NovelDatabase` and the per-folder `EpisodeCacheDatabase` / `TtsAudioDatabase` / `TtsDictionaryDatabase`) share a single connection-gate interlock so that concurrent open requests reuse one handle, `close()` is mutually exclusive with in-flight opens, connection acquisition during close fails explicitly, and failed opens are never cached. This prevents close-after-open races that re-lock files being deleted on Windows and ensures the interlock contract cannot be re-introduced inconsistently across wrappers.

## Requirements
### Requirement: in-flight open の共有による二重 open 防止

DBラッパーの接続取得（`database` getter）は、open がまだ完了していない状態で並行に複数回呼ばれた場合、単一の open 処理（`opener`）の結果を共有しなければならない (MUST)。`opener` は in-flight の間に1回だけ実行されるものとし (SHALL)、全ての並行呼び出しは同一の `Database` ハンドルを受け取るものとする (SHALL)。

#### Scenario: 並行する接続取得が単一の open を共有する
- **WHEN** `database` getter が、open がまだ完了していない状態で並行に複数回呼ばれる
- **THEN** 内部の `opener` は1回だけ実行される
- **AND** 全ての呼び出しが同一の `Database` ハンドルを受け取る

#### Scenario: open 完了後の取得は既存ハンドルを返す
- **WHEN** open が完了した後に `database` getter が再度呼ばれる
- **THEN** 新たな open を開始せず、既存の同一ハンドルを返す

### Requirement: close と in-flight open のインターロック

DBラッパーの `close()` は、in-flight open が進行中の場合、その open の決着を待って（await して）から、open された**その同一ハンドル**を閉じなければならない (MUST)。`close()` 完了後に、open 済みのハンドルが内部に保持されたまま残ってはならない (MUST NOT)。これにより、close 直前に始まった open が close 完了**後**に新ハンドルを生み、削除中のファイルを再ロックすることを防ぐ。

#### Scenario: close が in-flight open を待ってそのハンドルを閉じる
- **WHEN** open が進行中（getter が `opener` を await 中）に `close()` が呼ばれる
- **THEN** `close()` は in-flight open の完了を待つ
- **AND** open されたその同一ハンドルを閉じる
- **AND** `close()` 完了後に open 済みハンドルが内部に残らない

#### Scenario: close 後に再ロックを生むハンドルが残らない
- **WHEN** close-after-open のレースとなる順序で `close()` が完了する
- **THEN** 内部状態は open 済みハンドルを保持しておらず、後続のファイル操作が再ロックされない

### Requirement: close 進行中の接続取得は明示エラー

DBラッパーの `close()` 実行中に `database` getter が呼ばれた場合、システムは新たな open を開始せず、`DatabaseClosingException` を投げなければならない (MUST)。透過的な再 open を行ってはならない (MUST NOT)。これにより、解放処理の最中にハンドルを掴む経路を沈黙させず失敗として可視化する。

#### Scenario: close 中の getter は DatabaseClosingException を投げる
- **WHEN** `close()` の実行中に `database` getter が呼ばれる
- **THEN** `DatabaseClosingException` が投げられる
- **AND** 新たな open は開始されない

### Requirement: open 失敗の非キャッシュと close 後の再 open

DBラッパーの open が例外で失敗した場合、その失敗結果をキャッシュしてはならず (MUST NOT)、次回の `database` getter 呼び出しで open を再試行できるものとする (SHALL)。`close()` が完了した後に `database` getter が呼ばれた場合は、新しい接続を open するものとする (SHALL)。

#### Scenario: open 失敗は次回取得で再試行される
- **WHEN** `database` getter の open が例外で失敗する
- **THEN** その失敗結果はキャッシュされない
- **AND** 次回の `database` getter 呼び出しで open が再試行される

#### Scenario: close 完了後の取得は新しい接続を open する
- **WHEN** `close()` が完了した後に `database` getter が呼ばれる
- **THEN** 新しい `Database` 接続が open される

### Requirement: 全DBラッパーへのインターロック適用

システムは、グローバル `NovelDatabase` および per-folder DBラッパー（`EpisodeCacheDatabase` / `TtsAudioDatabase` / `TtsDictionaryDatabase`）の全てに、同一のインターロック契約（in-flight open 共有・close との相互排他・close 中取得の明示エラー・失敗の非キャッシュ）を適用するものとする (SHALL)。インターロックは共有の接続ゲートに集約し、各ラッパーへ個別実装をコピーしてはならない (MUST NOT)。

#### Scenario: per-folder DB がインターロック契約に従う
- **WHEN** `EpisodeCacheDatabase` / `TtsAudioDatabase` / `TtsDictionaryDatabase` のいずれかがハンドルを open/close する
- **THEN** in-flight open 共有・close との相互排他・close 中取得の明示エラーの各契約が適用される

#### Scenario: グローバル DB がインターロック契約に従う
- **WHEN** `NovelDatabase` がハンドルを open/close する
- **THEN** 同一のインターロック契約が適用される
