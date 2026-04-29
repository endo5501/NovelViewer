## Context

NovelViewer は OpenAI 互換 API および Ollama を LLM サマリ機能に利用しており、OpenAI 互換 API 利用時は API キーを `SettingsRepository` 経由で `SharedPreferences` に保存している (`lib/features/settings/data/settings_repository.dart:20,128`)。

現状の保存先である `SharedPreferences` は、各プラットフォームのアプリデータディレクトリ内に平文ファイルとして書き出される (Windows: `%APPDATA%\NovelViewer\shared_preferences.json`、macOS: `~/Library/Containers/.../Library/Preferences/`、Linux: `~/.local/share/NovelViewer/shared_preferences.json`)。マルウェアやファイル共有事故、PCの譲渡時の取り残しなど、ファイルアクセス権限を得た任意の主体がキーを取得できる。

`flutter_secure_storage` は同じプラットフォーム上で OS 提供のシークレットストア (Windows: DPAPI、macOS: Keychain、Linux: libsecret/Secret Service) を使うため、OS ユーザーセッションに紐づく暗号化境界が得られる。プロジェクトには既に `flutter_secure_storage` 関連コードはなく、今回が初導入。

合わせて、README.md:33 が Ollama デフォルトエンドポイントを `http://localhost:11334` と誤記している (実装は `:11434`)。同 Sprint で修正することで「Sprint 0 = ユーザー実害バグ最優先」のスコープが完結する。

## Goals / Non-Goals

**Goals:**
- API キーの保存先を OS 提供のシークレットストアに移し、平文ファイル経由での流出を防ぐ
- 既存ユーザーが手動でキーを再入力する必要がない、自動かつ冪等な移行
- 移行失敗がアプリ起動を阻害しない (ユーザーは設定で再入力可能)
- README の誤記を修正し、ドキュメント通りに Ollama に接続できるようにする
- LLM クライアント生成時は API キーを on-demand で取得し、`LlmConfig` 値オブジェクトに長期保持しない (F018 部分対応)

**Non-Goals:**
- API キー以外の設定値 (URL、モデル名、TTS 関連設定等) を secure_storage へ移すこと — `SharedPreferences` のまま
- ロギングパッケージ (F015) の導入 — Sprint 1 で扱う
- F018 の完全対応 (`LlmConfig` 値オブジェクト改廃) — 今回はクライアント生成箇所での on-demand 取得まで
- Linux secret-service バックエンド非搭載環境への対応 — `flutter_secure_storage` のデフォルト挙動に従う

## Decisions

### Decision 1: 移行は起動時、`main.dart` の初期化シーケンスで一度だけ実行する

`main()` 内、`runApp` 直前に `SettingsRepository` のマイグレーション関数を呼ぶ。`SharedPreferences` に旧キーが存在する場合のみ secure_storage に書き込み、書き込み成功後に `SharedPreferences` から削除する。冪等性は「`SharedPreferences` に旧キーが残っているかどうか」のみで判定する。

**Alternatives considered:**
- *初回 `getApiKey` 呼び出し時に lazy migrate*: 呼び出し側全部に async 整合を強要するが、起動時にやれば現状の同期 API を一度の async 化で済ませられる。
- *別途マイグレーションフラグキーを導入*: 旧キー存在 = 未移行という単純な判定で十分なため不要。

### Decision 2: マイグレーション失敗は `debugPrint` でログし、起動を続行する

secure_storage 書き込みが失敗 (Linux で libsecret 未インストール等) した場合、`debugPrint` で痕跡を残し、`SharedPreferences` の旧キーは**削除しない**。次回起動で再試行される。アプリは普通に起動し、ユーザーは設定画面で再入力すれば即座に secure_storage 経由の動作になる。

**Alternatives considered:**
- *起動時に SnackBar で通知*: 起動時の UI 状態は複雑で、ユーザーが今すぐ何をすべきかも明確でない。Sprint 1 のロガー導入後にユーザー通知の仕組みを再考。
- *起動を中断*: ユーザーは LLM 機能を使わないかもしれないため過剰。

### Decision 3: `SettingsRepository.getApiKey` / `setApiKey` を非同期化する

secure_storage は async API のみ提供する。既存の同期版を維持するための内部キャッシュは導入せず、シンプルに `Future<String>` を返す形に変更する。`getLlmConfig` も API key を含めるなら async 化が必要 — 別案として `getLlmConfig` から API key を切り出す (Decision 4)。

**Alternatives considered:**
- *ローカルキャッシュ + 同期 API*: race conditions と secure_storage の意義 (アクセス時に毎回 OS チェック) を弱める。

### Decision 4: `LlmConfig` 値オブジェクトから `apiKey` を切り離し、`LlmClient` 生成時に on-demand で取得する

`LlmConfig` は URL/モデル名等の非秘匿項目のみ保持。`OpenAiCompatibleClient` 生成時に `SettingsRepository.getApiKey()` を await で読み出して渡す。これにより `LlmConfig` インスタンスがメモリやログに長く残っても秘匿情報が漏れない。F018 の意図する「transient」性を達成する。

**Alternatives considered:**
- *`LlmConfig.apiKey` を残す*: 値オブジェクトに API キーを持たせ続けると、デバッグログに `LlmConfig` を流す箇所が出てきた瞬間に流出する。secure_storage 化と同時にやる価値がある。

### Decision 5: README はコード側に合わせる (`11434` に統一)

実装側 (`settings_dialog.dart:63,319`) の `11434` は Ollama 公式のデフォルトポートで、修正コストが大きく波及範囲が広い。README が誤っているだけなので README を直す。

### Decision 6: `flutter_secure_storage` のバージョンは `^9.0.0`

執筆時点の最新メジャー。Flutter 3.x に対応し、Windows/macOS/Linux 全プラットフォームをカバーする。

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| Linux 環境で libsecret が無く secure_storage が初期化失敗する | マイグレーションは `try/catch` でガード、`debugPrint` でログ、旧キーは温存。ユーザーは旧 SharedPreferences のまま動作するわけではないので、設定画面側でも例外時に再入力プロンプトを案内する (Sprint 1 で改善) |
| マイグレーション後に secure_storage からの読み出しが恒久失敗 → 次回起動でも `SharedPreferences` に旧キーがないため LLM 機能が無効に見える | 設定画面で API キーを再入力できる動線は変わらず存在する。debugPrint ログがあれば問題切り分け可能 |
| 既存テストが API key を `SharedPreferences` 前提でモックしている | テストファイルを洗い出し、`flutter_secure_storage` のモックに置き換え。`SharedPreferences` ベースのテストは migration テストへ転用 |
| `getApiKey` 非同期化で UI がブロックされたように見える | secure_storage の単発読み出しは数 ms レベル。設定画面の `TextField.controller` を初期化時に1度だけ await すれば済む。LLM 呼び出し前の取得は元々 async コンテキスト |
| Linux secret-service バックエンドのテスト網羅性 | macOS / Windows のみ CI で検証する想定。Linux は手動確認とドキュメント記述で代替 (CLAUDE.md 上 Linux 未確認) |

## Migration Plan

1. `pubspec.yaml` に `flutter_secure_storage: ^9.0.0` 追加 → `fvm flutter pub get`
2. `SettingsRepository` 内に `_secureStorage` を追加し、`getApiKey` / `setApiKey` を secure_storage 経由に書き換え
3. `migrateApiKeyToSecureStorage()` メソッドを追加。`SharedPreferences` に旧キーがあれば secure_storage に転送して削除
4. `main.dart` で `runApp` 前に呼び出し (失敗しても続行)
5. `LlmConfig` から `apiKey` フィールドを削除、または "transient かつ常に空" にする (Decision 4 に従う)
6. `LlmClient` 生成箇所 (`llm_summary_pipeline.dart` 等) で API キーを on-demand 取得
7. README.md:33 を `http://localhost:11434` に修正
8. テストと `fvm flutter analyze` をパスさせる

**Rollback strategy:** マイグレーションは「旧キー削除」が完了するまでロールバック可能 (旧キーが残っている)。完了後は secure_storage から読み戻すスクリプトをアドホックで書く必要がある。実用的には旧バージョンへ戻すユーザーは少ないため、ロールバックは「ユーザーがキーを再入力する」をデフォルトとする。

## Open Questions

(なし。Sprint 0 開始前にユーザー確認済み)
