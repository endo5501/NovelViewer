## Why

小説フォルダの境界を守る判定が、アプリ内で2箇所だけ他とずれている。

移動先ダイアログもダウンロード先も「小説フォルダの内部を候補にしてはならない」を守り（`listDownloadDestinationFolders` が小説フォルダのサブツリーごと除外する）、ブックマークは `resolveNovelFolderPath` で登録済み小説フォルダを解決してから `novel_data.db` に触れる。しかし次の2箇所はその判定をしていない。

1. **LLM 解析が、小説フォルダでない場所に `novel_data.db` を作る。** 解析履歴パネルのガードは「ライブラリルートかどうか」であって「小説フォルダかどうか」ではない（`llm_summary_history_panel.dart:20-28`）。整理フォルダにいる間にタブを開くと、`llmSummaryHistoryProvider` がその整理フォルダを対象として扱い、`NovelDataDatabase.openFile` が `onCreate` 付きで開くため、小説ではない場所に小説用のDBファイルが残る。解析の実行側（`analysis_runner.dart` / `hover_popup_host.dart`）も同じで、現在地が非 null でありさえすれば走る。同じ `novel_data.db` を読み書きするブックマーク側は正しく判定しており、LLM 側だけが取りこぼしている。

2. **新規フォルダ作成ボタンが、小説フォルダの中でも押せる。** ツールバーのボタンは現在地を問わず表示される（`file_browser_panel.dart:230-236`）。小説フォルダに入って押せば、その中に整理フォルダができる。エピソードをそこへ入れる手段はアプリに無い（ファイル単位の移動・改名が存在しない）ので空のまま残るが、他の全経路が禁じている構造を唯一ここだけが作れてしまう。

どちらも現行の main で起きており、読書コンテキストの移行や `selectedFileProvider` の扱いとは独立している。

## What Changes

**`novel_data.db` を開く場所を、登録済み小説フォルダに限定する。**

- LLM 解析が対象とするフォルダを、ブラウザの現在地そのものではなく `resolveNovelFolderPath` で解決した登録済み小説フォルダにする。ブックマークの `currentNovelFolderPathProvider` と同じ解決規則になり、同一の `novel_data.db` を2つの機能が別の鍵で開くことがなくなる。入れ子の深さには依存しない。
- 解決できない場所（ライブラリルート、および登録済み小説フォルダを祖先に持たない整理フォルダ）では、解析履歴パネルはこれまでライブラリルートで出していたのと同じ「作品フォルダを選択してください」を表示し、provider を watch しない。解析の実行は既存の「小説フォルダを開いてください」で断る。どちらも `novel_data.db` を開かない。
- 話数の算出（`resolveUpperBoundForCurrent` / `resolveUpperBoundForAll` / `resolveSourceFileForAll`）と、履歴からの本文ジャンプのパス組み立ては、これまで通り**表示中のファイルが置かれているフォルダ**を使う。これらはDBの鍵ではなくエピソードの並びであり、小説フォルダへ寄せると `source_file` の記録と食い違う。

**小説フォルダの中に整理フォルダを作らせない。**

- ファイルブラウザのツールバーの新規フォルダ作成ボタンを、現在地が小説フォルダ自身またはその配下のときは無効にする。親フォルダへ戻るボタンが `hasParent` で無効化されるのと同じ形にし、新しい文言は増やさない。

### ユーザーに見える変化

- 整理フォルダで解析履歴タブを開くと、これまで空リスト（と副作用のDBファイル）だったものが「作品フォルダを選択してください」になる。
- 整理フォルダに直接置かれたテキストを読んでいるとき、LLM 解析が実行できなくなる。ブックマークが同じ場所で既に無効であるのと揃う。
- 小説フォルダにいる間、新規フォルダ作成ボタンが押せなくなる。
- 登録済み小説フォルダの中で読んでいる限り、何も変わらない。解析も履歴もこれまで通り動く。

既に整理フォルダ上に作られてしまった空の `novel_data.db` の削除は行わない。消す操作はユーザーのファイルを消す操作になるため、本変更の範囲外とする。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `llm-summary-history-ui`: 「History entries scoped to active novel」の対象判定を、「ライブラリルートでなければ現在地を小説とみなす」から「`resolveNovelFolderPath` で解決した登録済み小説フォルダ。解決できなければ対象なし」へ変更する。
- `llm-summary-context-menu-trigger`: 解析を開始できる場所の制約を追加する。登録済み小説フォルダが解決できない場所では解析を開始せず、`novel_data.db` を作らない。
- `novel-folder-management`: 「整理フォルダの作成」に、小説フォルダおよびその配下では作成できないという制約を追加する。移動先・ダウンロード先が既に持っている「小説フォルダの内部を候補として表示してはならない」と揃える。

## Impact

- `lib/features/llm_summary/presentation/llm_summary_history_panel.dart` — ガード条件の差し替え
- `lib/features/llm_summary/providers/llm_summary_history_provider.dart` — DBの対象フォルダとジャンプ先パスの分離（`build` / `deleteEntry` / `openEntry`）
- `lib/features/llm_summary/presentation/analysis_runner.dart` — DBの対象フォルダと話数算出フォルダの分離、解決できない場所での中断
- `lib/features/llm_summary/presentation/hover_popup_host.dart` — 同上
- `lib/features/file_browser/presentation/file_browser_panel.dart` — ツールバーの新規フォルダ作成ボタンの有効条件
- `lib/features/bookmark/providers/bookmark_providers.dart` — `currentNovelFolderPathProvider` を参照する。実装は変更しない
- データ移行なし。スキーマ変更なし。l10n の新規文言なし
