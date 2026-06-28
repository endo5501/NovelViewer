# NovelViewer 保守仕様

このディレクトリは、NovelViewerのコードベースから逆生成した監査可能な保守仕様である。

## 読み方

1. `00-metadata.md`で対象、スコープ、証拠表記、制限事項を確認する。
2. `01-overview.md`で主要ユースケースを把握する。
3. 保守対象に応じて`02`〜`09`の各章を参照する。
4. 実装根拠を追跡するときは`traceability.md`と各章の`[REF:]`を使用する。
5. 未解決・放棄事項は`99-unresolved.md`を確認する。

## 文書一覧

| ファイル | 内容 |
|---|---|
| `00-metadata.md` | 対象、目的、スコープ、深度、制限事項 |
| `01-overview.md` | 概要・主要ユースケース |
| `02-architecture.md` | アーキテクチャ |
| `03-screens.md` | 画面・画面遷移 |
| `04-features.md` | 機能・ユースケース |
| `05-data-model.md` | データモデル |
| `06-settings-security.md` | 設定・ローカルデータ・セキュリティ境界 |
| `07-external-integrations.md` | 外部システム連携 |
| `08-operations.md` | ビルド・配布・運用 |
| `09-constraints.md` | 制約・確定判断 |
| `99-unresolved.md` | 未解決・放棄事項 |
| `traceability.md` | Inventory・章・ソースの対応 |

## 証拠と確度

ソース由来の主張には`REF path:line`形式の参照を付与する。`VERIFIED`は直接確認、`INFERRED`は複数の根拠による推定、`ASSUMED`は明示的な仮定を表す。

本成果物は`outline`深度である。各章のDeep-dive candidatesは、追加要求があった場合に個別調査する。

## Sources Read

- `../goal.json`
- `../wbs.json`
- `../verification-report.md`
