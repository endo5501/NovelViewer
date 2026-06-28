# メタデータ

| 項目 | 値 |
|---|---|
| 対象 | NovelViewer |
| 対象リビジョン | `bc003450c070c4536138a9b026186a392952d512` |
| 生成日時 | `2026-06-28T09:05:59+09:00` |
| 仕様目的 | 保守 |
| 主な読者 | 保守開発者 |
| 出力言語 | 日本語 |
| 詳細度 | detailed |
| 深度モード | outline |
| 基本テンプレート | web-app 0.1.0 |
| カスタマイズ | desktop-app |
| 実行方式 | parallel |

目的、読者、言語、詳細度、主観点は確認済みの目標設定に基づく。🟢 VERIFIED [REF: .cc-rsg/goal.json:2-13]

章構成はデスクトップアプリ向けに調整した9章である。🟢 VERIFIED [REF: .cc-rsg/goal.json:14-30]

`third_party/` は本体との連携境界とビルド統合を対象とし、サブモジュール内部の網羅的仕様化は除外する。🟢 VERIFIED [REF: .cc-rsg/goal.json:31-33]

Phase 2では488ユニットを棚卸しし、未割当0件のWBSが承認された。🟢 VERIFIED [REF: .cc-rsg/state.json:16-24]

対象リビジョンはGit HEADである。分析時のworktreeには既存の変更・未追跡ファイルがあり、本仕様はコミット済みHEADだけでなく、調査時に読み取ったworktree内容を証拠としている。

## 制限事項

- `third_party/`の内部実装はスコープ外である。
- 深度は`outline`であり、各章のDeep-dive candidatesは要求時に追加調査する。
- Android、iOS、Linuxは現状の正式サポート対象外である。
- macOSリリースは現状手動運用である。

## 証拠表記

- `REF path:line`: 実際に検査したソース位置を表す。
- `🟢 VERIFIED`: 検査したソースで直接確認。
- `🟡 INFERRED`: 複数のソース信号から推定。
- `🔴 ASSUMED`: ソースでは確定できない仮定。
- `BLOCKED see Q-NNN`: 重大な未確定事項を表す。

## Detail questions raised in this chapter

- None

## Sources Read

- `.cc-rsg/goal.json`
- `.cc-rsg/state.json`
