---
name: codex
description: |
  Codex CLI（OpenAI）を使用してコードや文言について相談・レビューを行う。
  トリガー: "codex", "codexと相談", "codexに聞いて", "コードレビュー", "レビューして"
  使用場面: (1) 文言・メッセージの検討、(2) コードレビュー、(3) 設計の相談、(4) バグ調査、(5) 解消困難な問題の調査
---

# Codex

Codex CLI を使用してコードレビュー・分析を実行するスキル。

## 基本コマンド

```
codex exec --sandbox <MODE> -C <project_directory> "<request>"
```

`--full-auto` フラグは廃止されました（`codex-cli 0.133.0` 時点）。代わりに `--sandbox` を明示します。

## サンドボックスモード

| モード | 説明 | 用途 |
|---|---|---|
| `read-only` | 読み取り専用（書き込み・サブプロセス起動不可） | 分析・レビュー（Windows ではサブプロセスが起動できず失敗する場合あり） |
| `workspace-write` | workdir 内に書き込み可、git やビルドコマンド OK | コードレビュー全般の推奨 |
| `danger-full-access` | サンドボックスなし | Windows で `read-only` がサンドボックス起動エラーで使えない時のフォールバック |

**Windows ノート**: `--sandbox read-only` を指定すると `windows sandbox: spawn setup refresh` エラーで `git diff` などのサブプロセス起動がすべて失敗することがあります。その場合は `--sandbox workspace-write`、もしくは `--sandbox danger-full-access` を使ってください。

## プロンプトのルール

**重要**: codex に渡すリクエストには、以下の指示を必ず含めること：

> 「確認や質問は不要です。具体的な提案・修正案・コード例まで自主的に出力してください。」

確認を求められると会話が止まってしまうため。

## 用途別レシピ

### A. ブランチ全体のコードレビュー（推奨: 専用サブコマンド）

`codex exec review` は対象ブランチの diff を自動で拾ってレビューしてくれる専用モードです。

```
codex exec review --base <base-branch>
```

カスタム観点をプロンプトで渡したい場合：

```
echo "観点A、観点B、観点C で重点的にレビューしてほしい。確認や質問は不要です。具体的な提案・修正案・コード例まで自主的に出力してください。" | codex exec review --base main
```

(`--base <BRANCH>` と `[PROMPT]` 引数は同時指定できないため、プロンプトは stdin で渡す)

### B. 限定範囲の diff をパイプしてレビュー

特定ファイル群だけレビューしたい時：

```
git diff main...HEAD -- 'lib/features/foo/**' ':!lib/l10n' \
  | codex exec --skip-git-repo-check --sandbox danger-full-access \
      "stdin に流したのは feature/foo の本番コード diff です。○○観点でレビューしてほしい。指摘は file:line で具体的に。確認や質問は不要、具体的な提案・修正案・コード例まで自主的に出力してほしい。"
```

`--skip-git-repo-check` を付けると stdin が pipe の時の git チェックをスキップできます。

### C. 一般的なファイル指定なしの分析

```
codex exec --sandbox workspace-write -C /path/to/project "このプロジェクトのアーキテクチャを分析して説明してください。確認や質問は不要です。改善提案まで自主的に出力してください。"
```

### D. デザイン相談（UI/UX）

```
codex exec --sandbox workspace-write -C /path/to/project "あなたは世界トップクラスのUIデザイナーです。以下の観点からこのプロジェクトのUIを評価してください: (1) 視覚的階層構造とタイポグラフィ、(2) 余白・スペーシングのリズム、(3) カラーパレットのコントラストとアクセシビリティ、(4) インタラクションパターンの一貫性、(5) ユーザーの認知負荷の軽減。確認や質問は不要です。具体的な改善案をコード例付きで提示してください。"
```

## 主要オプション

| オプション | 説明 |
|---|---|
| `-s, --sandbox <MODE>` | サンドボックスモード（`read-only` / `workspace-write` / `danger-full-access`） |
| `-C, --cd <DIR>` | 作業ディレクトリ |
| `--skip-git-repo-check` | git リポジトリ外でも実行可（stdin pipe 時に必要なことが多い） |
| `-m, --model <MODEL>` | 使用モデル（指定なしで設定ファイル従属） |
| `--json` | 出力を JSONL で（自動処理用） |
| `-o, --output-last-message <FILE>` | 最終応答をファイルに保存 |

`codex exec review` 固有：

| オプション | 説明 |
|---|---|
| `--base <BRANCH>` | このブランチからの差分をレビュー |
| `--uncommitted` | staged + unstaged + untracked をレビュー |
| `--commit <SHA>` | 特定コミットの変更をレビュー |

## 実行手順

1. ユーザーから依頼内容を受け取る
2. 対象プロジェクトのディレクトリを特定する（現在のワーキングディレクトリまたはユーザー指定）
3. レビューの種類に応じてレシピ (A/B/C/D) を選ぶ
   - ブランチ全体 → A (`codex exec review --base`)
   - 特定ファイル/領域だけ → B (`git diff ... | codex exec`)
   - リポジトリ全体の分析 → C
   - UI/UX 専門観点 → D
4. **プロンプトを作成する際、末尾に「確認や質問は不要です。具体的な提案まで自主的に出力してください。」を必ず追加する**
5. Codex を実行（長時間かかることがあるため timeout に余裕を）
6. 結果をユーザーに報告
