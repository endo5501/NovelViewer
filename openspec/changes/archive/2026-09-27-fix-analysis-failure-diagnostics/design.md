## Context

動機は proposal.md の Why を参照。要件は `specs/` の2本を参照。

現状:

- `appVersionLabelProvider`（`lib/features/app_update/providers/update_providers.dart:23`）が `PackageInfo` から `version+buildNumber` を組み立てる。LLM と TTS の両方の障害レポートがこれを共有している
- ビルド経路に `--dart-define` の使用例はまだ無い
- リリースは `scripts/release.sh` / `release.ps1` がタグを打ち、`.github/workflows/release.yml` が `flutter build windows --release` を実行する。macOS / iOS は手元ビルド
- `analysis_runner.dart:415` の `_diagnostics` は `llmConfigProvider` を読んでいる。実際に解析を行うクライアントは `llmClientProvider` が作る

## Goals / Non-Goals

**Goals:**

- 障害レポートの `model` が、その解析に実際に使われたモデルを指す
- `app version` からビルドを特定できる。識別子が無いビルドはそうと分かる

**Non-Goals:**

- 診断項目の追加・削除・並び順の変更。エンドポイントを出さない方針も変更しない
- TTS の `model` 診断（モデルディレクトリ名）の変更。別物である
- バージョン番号の運用変更（リリースごとの採番規則には手を入れない）

## Decisions

### D1: `model` は `LlmClient.modelId` を読む

`LlmClient` には既に `modelId` があり、「provider と model 名を一緒に持つのはクライアントだけ」という理由でクライアントの性質として定義されている（`llm_client.dart` のコメント参照）。診断もそこから読む。

`FoundationModelsClient.modelId` は `apple:on-device` を返すので、診断は `provider: appleOnDevice` と整合する。

クライアントが作れなかった場合（設定不備など）は `modelId` を読む相手がいない。このとき設定値へフォールバックすると元の誤りが戻るので、**クライアントが無いことを明示する値**（`(no client)`）を入れる。

どのクライアントから読むかは、失敗した経路で分ける。`_diagnostics` 自体はモデル識別子を引数で受け取るだけにし、読み取り元は呼び出し側が決める。

- **解析本体の失敗**：サービスが保持している `llmClient` から読む。`llmClientProvider` はアプリ復帰時にオンデバイスの可用性が再確認されると作り直されうるため、失敗後にプロバイダを読み直すと、実行に使っていないクライアント（あるいはクライアント無し）を報告してしまう
- **クライアント構築前の失敗**（簡易解析の検索失敗）：まだクライアントが無いので `llmClientProvider` を読む（`_modelOfCurrentClient`）。構築が例外を投げた場合も `(no client)` とする
- **クライアント構築自体の失敗**：`llmClientProvider` の await が例外を投げた場合は、未処理例外として消えさせず、`(no client)` を載せた障害レポートを出す

### D2: ビルド識別子は `--dart-define` で注入し、既定は「無し」

`String.fromEnvironment` はコンパイル時定数なので、注入されなければ空文字になる。空文字を「識別子無し」として扱い、ラベルには `+unknown` に相当する明示的な印を付ける。省略もせず、それらしい値で埋めもしない（spec の要件）。

値は短い commit ハッシュとする。tag 名を使う案は、タグ間のビルドを区別するという目的そのものを果たさないので採らない。

dirty フラグ（未コミット変更の有無）を含めるかは、含める方向で検討に値する。今回踏んだ問題は「どのコミットか」であり、まずはハッシュで足りるので、本変更ではハッシュのみとする。

### D3: 注入はビルド経路に置き、アプリ側は受け取るだけ

識別子は `--dart-define=BUILD_COMMIT=<hash>` で渡し、`buildCommitProvider` が `String.fromEnvironment('BUILD_COMMIT')` として読む。`appVersionLabelProvider` はそれを使ってラベルを組み立てる。コンパイル時定数を直接読まずプロバイダを挟むのは、テストで「識別子あり」「識別子なし」の両方のビルドを再現するため。ビルドスクリプトとリリースワークフローの `flutter build` 呼び出しに `--dart-define` を足す。

アプリ実行時に `git` を呼ぶ案は、配布物に git 環境が無いので成立しない。

macOS / iOS は手元ビルドであり、`fvm flutter build` を直接叩くと識別子が入らない。CLAUDE.md に載っているビルドコマンドは `fvm flutter build macos` のような素の呼び出しなので、**識別子を注入するビルドスクリプトを用意し、そちらを正とする**（tasks 参照）。素のコマンドで作ったビルドは「識別子無し」と報告され、それは spec が意図した通りの振る舞いになる。

スクリプトは `scripts/build_app.sh`（macOS / iOS）と `scripts/build_app.bat`（Windows の手元ビルド）の2本。Windows のリリースビルドはワークフローが注入し、ハッシュを解決できなければ失敗させる。コマンド置換の失敗はビルドコマンドを失敗させないため、解決は独立したステップで行う。

## Risks / Trade-offs

- **手元ビルドで識別子を入れ忘れる** → 入れ忘れたビルドは `unknown` と自己申告するので、レポートを受け取った側が誤解しない。これは欠陥ではなく設計した縮退
- **commit ハッシュがレポートに載る** → このリポジトリは公開物であり、ハッシュから漏れる情報は無い。エンドポイントや認証情報を出さない既存方針には触れない
- **`llmClientProvider` の読み取り位置** → 失敗経路でクライアントを読むのは、構築前の失敗で使う `_modelOfCurrentClient` だけ。構築が例外を投げうるため、例外を捕まえて `(no client)` にフォールバックする。OpenAI 互換ではこの読み取りがセキュアストレージの読み出しを伴うが、成功経路でも同じ読み出しが起きるため、新しい種類のプロンプトは生じない

## Migration Plan

保存データなし。ロールバックは revert のみ。
