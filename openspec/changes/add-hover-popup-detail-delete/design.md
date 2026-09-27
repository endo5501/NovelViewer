## Context

動機は proposal.md の Why を、要件は `specs/` を参照。ここでは実装の制約だけを記す。

- ポップアップ（`HoverPopupWidget`）は `HoverPopupHost` が root Overlay に差し込む `OverlayEntry` である。`hoverPopupProvider` が hidden になるとエントリは即座に取り除かれ、ポップアップ配下の `State`／`context`／`ref` は使えなくなる。
- ダイアログを開くとポインタはポップアップの `MouseRegion` の外に出る。そのため `onPopupExit` が走り、ポップアップは閉じる（タッチでもダイアログの操作は同じ結果になる）。つまり詳細・削除のどちらのボタンでも、ボタンの `onPressed` 内で `await` をまたいだ時点で、ポップアップはもう存在しない前提で書く必要がある。
- 既存の再解析ボタン（`_ReanalyzeMenuButton`）は同じ問題を、**ウィジェットが生きているうちに**次のものを確保して回避している: root navigator の `context`、`ref.read` で得たオブジェクト、`widget` のフィールド。今回もこのパターンを踏襲する。
- 部品は揃っている: 詳細ダイアログ `LlmSummaryDetailDialog(folderPath, word)`、削除 `LlmSummaryHistoryNotifier.deleteEntry(word, novelFolder:)`。後者は `word_summaries` と `fact_cache` の両方を消し、登録済み小説フォルダかどうかのガードも持つ。ポップアップは `folderPath`（開いた時点の小説フォルダ）を持っており、フォルダが変わると Host がポップアップを閉じる。

## Goals / Non-Goals

**Goals:**
- ポップアップから、解析履歴メニューと**同一の**詳細表示・削除を呼び出す（処理の二重実装をしない）。
- ポップアップが閉じた後でも、ダイアログと削除が確実に完了する。

**Non-Goals:**
- 解析履歴メニューの削除に確認ダイアログを付けること。
- スナップショット単位の削除。
- ダイアログを閉じた後にポップアップを復元すること。
- 詳細ダイアログの内容の変更。

## Decisions

### D1. 削除は `deleteEntry` をそのまま呼ぶ
削除単位・フォルダガード・`fact_cache` の連鎖削除・履歴の再読み込み（→ マークの消去）を、Drawer と完全に共有するため。ポップアップ専用の削除メソッドは作らない。
- 代替案: ポップアップ用にリポジトリを直接叩く → ガードや連鎖削除の抜けが起きうるので却下。

### D2. ポップアップが消える前に必要なものを確保する
ボタンの `onPressed` の先頭、`await` より前で次のものをローカル変数に取る。
- `Navigator.of(context, rootNavigator: true).context`
- `ref.read(llmSummaryHistoryProvider.notifier)`
- `folderPath`、`word`

ダイアログは root navigator の context で `showDialog` する。確認ダイアログの結果を `await` した後は、確保したものだけで削除を実行する。
- 代替案: ダイアログ表示中はポップアップを閉じないよう `onChildMenuOpen` のラッチを使う → ダイアログのバリアとポップアップのバリアが重なり、タッチでの閉じ方やフォーカスの扱いが複雑になる。spec でもポップアップの維持を求めていないので却下。

### D3. ボタンは `SummarySnapshotView.trailing` の中に並べる
`_Card` が渡す `trailing` を「詳細・削除のアイコン + （対応環境なら）再解析」の `Row` に置き換える。`SummarySnapshotView` の構造は変えない。
- 詳細・削除は `llmSummarySupportedProvider` に関係なく常に表示する。再解析だけ今の条件を維持する。
- アイコンは `IconButton` を使う。ナビゲータ（◀▶）と同じ密度にするため、`visualDensity: compact` と 24px の最小サイズにする。`tooltip` にはローカライズしたラベルを渡す。
- 詳細ダイアログ（`keyPrefix: history_detail`）は `trailing` を渡さないので、閲覧専用のまま影響を受けない。
- ナビゲータの「Xファイル時点の要約」ラベルは、今は素の `Text` で縮まないため、幅が足りないと行全体があふれる（en ロケールではアイコンを足す前から、テスト用フォントで 124px あふれていた）。このラベルを `Flexible` と `overflow: ellipsis` で包み、言語や話数によらず、ナビゲータとボタンが押し出されないようにする。詳細ダイアログも同じ部品を使うので、同じ保護が効く。

### D4. 確認ダイアログは l10n 付きの `AlertDialog`
タイトルまたは本文に単語名を含め、要約と事実の両方が消えることを明記する。ボタンは「キャンセル」と「削除」の2つで、「削除」は既存の削除メニュー項目に合わせて赤系の文字色にする。`showDialog<bool>` の結果が `true` のときだけ削除する。バリアのタップや Esc で閉じた場合（`null`）はキャンセル扱い。

### D5. `deleteEntry` でポップアップ用キャッシュも破棄する
`deleteEntry` の最後で `hoverPopupCacheProvider((folderPath: novelFolder, word: word))` を invalidate する。
- 理由: この provider は autoDispose ではない。破棄しないと、削除済みの語のスナップショットがアプリ終了までメモリに残る。消した語のマークは消えるので、利用者から見える不具合ではないが、削除後に削除前のデータを持ち続ける状態は避けたい。
- Drawer 経由の削除も同じ経路を通るので、両方の入口で一貫する。

## Risks / Trade-offs

- [ポップアップが閉じた後に `ref`／`context` を触って例外になる（再解析で実際に起きた不具合と同種）] → D2 のとおり、`await` より前にすべて確保する。「ダイアログ表示でポップアップが消えた後も削除が完了する」ことをウィジェットテストで検証する。
- [キャンセル後にポップアップが閉じたままになる] → 許容する（Non-Goals）。もう一度ホバーかタップをすれば開く。
- [アイコンが3つ並んでナビゲータの幅が足りなくなる] → アイコンはコンパクトな 24px。360px の幅に収まることを、en／zh のラベルでもウィジェットテストで確認する（オーバーフローしないこと）。
- [タッチの閉じ判定がボタンのタップを「外側」と誤判定する] → ボタンはポップアップの範囲内にあるので、既存の範囲判定で除外される。念のためタッチでの操作をテストする。
