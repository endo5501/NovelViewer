## Context

監査テーマ#1「静かな失敗」の最後の燃え残りを塞ぐ低リスク変更。対象は2クラスタ:

- **F140 自動更新経路**: `lib/features/app_update/` 配下に握り潰しcatchが実6箇所。一部は`return portable`/`return false`/`return null`という**意図的フォールバック**、一部は`UpdateResult.message`まで捨てる**真の握り潰し**。フィールドでの更新失敗が現状ブラックボックス。
- **F139 起動時APIキー移行**: `startup_migrations.dart` と `settings_repository.dart` の失敗報告が`debugPrint`のみ。`debugPrint`はreleaseビルドでAppLoggerのファイルシンクに乗らないため、平文prefsにキーが残ったユーザを後から診断できない。

既存基盤として `logging-infrastructure`（`AppLogger` + `package:logging`、モジュール別named logger、release時はサイズローテーションするファイルシンク、`Level.INFO`未満はrelease時にドロップ）が揃っている。本変更はこの基盤に乗るだけで新規依存はない。

## Goals / Non-Goals

**Goals:**
- 更新経路・移行経路の失敗が release ビルドでも観測可能になる（AppLoggerファイルシンクに痕跡が残る）。
- 失敗の性質に応じてログレベルを切り分け、ログ汚染を避ける。
- 既存の制御フロー（フォールバック値・rethrow・ダイアログクローズ・移行の冪等性/非ブロッキング/失敗時ソース保持）を一切変えない。
- `lib/` 内の `debugPrint` 利用をAppLogger実装自身を除きゼロにする。

**Non-Goals:**
- F134（Authenticode署名検証）の実装。
- 更新経路・移行経路の制御フローやリトライ戦略の変更。
- ユーザ向けUI文言の新設・変更（診断可能性のみ。ユーザ体験は不変）。
- `lib/` 全域のcatch規約統一（F141）。本変更は更新/移行2クラスタに限定。

## Decisions

### D1: ログレベルを失敗の性質で切り分ける（一律WARNINGにしない）

`logging-infrastructure` は release で `Level.INFO` 未満をドロップする。これを利用し、3段で振り分ける:

| 経路 | 失敗の性質 | レベル | 根拠 |
|---|---|---|---|
| `update_dialog`（ブラウザ起動失敗 / 捨てられた`UpdateResult.message`） | 真の握り潰し | `WARNING` | ユーザ操作が無言で失敗していた |
| `installer_updater`（cleanup失敗） | 真の握り潰し | `WARNING` | 一時ファイル残留の診断に必要 |
| `installer_downloader`（パーシャル削除失敗、rethrowはする） | 真の握り潰し | `WARNING` | 大容量残骸の診断に必要 |
| `installer_verifier`（読取不能→`false`） | フォールバック（不信扱い） | `WARNING` | 検証失敗は更新中断に直結する異常 |
| `registry_reader`（読取失敗→`null`） | フォールバック | `FINE` | キー不在は正常系（多くのユーザでkeyなし） |
| `distribution_detector`（失敗→`portable`） | フォールバック | `FINE` | **ポータブル版では正常起動の度に通る経路**。WARNINGにするとログが汚れる |

**代替案**: 全箇所WARNING — 却下。`distribution_detector`/`registry_reader`はポータブル版で常時発火し、ログを実質的なノイズで埋め、本当の異常を埋没させる。

### D2: named loggerは経路ごとに `app_update.<sub>` と移行は既存命名に揃える

`logging-infrastructure` の命名規約（`<feature>` / `<feature>.<sub>`）に従い、`Logger('app_update.dialog')`, `Logger('app_update.installer')`, `Logger('app_update.downloader')`, `Logger('app_update.verifier')`, `Logger('app_update.registry')`, `Logger('app_update.distribution')` 等を各ファイル先頭に file-level で1つ宣言。移行系は `Logger('startup')`（startup_migrations）と settings_repository の既存ロガー慣習に合わせる。

### D3: 制御フローは不変、ログ行を「追加」するだけ

各catch本体は既存の早期return/rethrow/フォールバックを維持したまま、その直前に1行ログを差し込む。`catch (_)` は捕捉変数とstackを使うため `catch (e, stack)` へ広げるが、後続処理は変えない。

### D4: `update_dialog` は `UpdateResult.message` をログに含める

F140指摘の通り、ダイアログが捨てている実失敗文言（`UpdateResult.message`）をログメッセージに含めることで、汎用例外より具体的な診断情報を残す。

## Risks / Trade-offs

- [フォールバック経路の過剰ログ] → D1のレベル切り分けで回避。`FINE`はrelease(`Level.INFO`)でドロップされるため、ポータブル版の常時発火経路はファイルに書かれない。debug時のみ可視。
- [`catch (_)`→`catch (e, stack)`化で未使用変数lint] → ログで`e`/`stack`を必ず参照するため発生しない。`fvm flutter analyze`で確認。
- [移行のレベル選定ミスでキー残留が埋没] → 移行失敗は`WARNING`（平文キー残留＝セキュリティ診断対象のため、release保持必須）。
- [テストの脆さ] → 既存の更新系テストは挙動(実装でなく)をassertする方針（監査の「健全」節参照）。ログ検証は注入した debug sink / record listener で行い、内部実装に踏み込まない。

## Migration Plan

スキーマ・永続化・APIの変更なし。デプロイ＝通常ビルド。ロールバックは単純revert（挙動不変のため副作用なし）。
