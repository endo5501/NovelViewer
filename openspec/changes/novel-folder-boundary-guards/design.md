## Context

動機は proposal.md の「Why」を参照。ここでは実装上の判断だけを記す。

現状の構造で効いてくる事実は3つ。

- `novel_data.db` を開く経路は2つしかない。`bookmark_providers.dart` と `llm_summary_providers.dart` で、どちらも `novelDataDatabaseProvider(folderDbKey(folderPath))` を通る。前者は `resolveNovelFolderPath` で解決したパスを渡し、後者はブラウザの現在地をそのまま渡している。
- `NovelDataDatabase.openFile` は `onCreate` を持つ。開くことは作ることでもある。
- LLM 側が現在地を使っている箇所は、**DBの鍵**として使っている箇所と、**エピソードの並び**として使っている箇所が混ざっている。`llmSummaryRepositoryProvider(directory)` は前者、`resolveUpperBoundForAll(directory)` は後者。

## Goals / Non-Goals

**Goals:**

- `novel_data.db` が登録済み小説フォルダ以外に作られる経路を無くす。読み（履歴パネル）と書き（解析実行）の双方で。
- LLM の「DBの鍵」と「エピソードの並び」を、コード上で別の名前にする。
- 小説フォルダの中に整理フォルダを作る唯一の経路を塞ぐ。

**Non-Goals:**

- `selectedFileProvider` の `clear()` には触れない。読書コンテキスト（`reading-context`）への消費者移行も行わない。本変更はすべて `currentDirectoryProvider` を起点としたままで完結する。
- 既に作られてしまった `novel_data.db` の削除・移行は行わない。
- TTS 音声DB・辞書DB・エピソードキャッシュDBの鍵は変更しない。これらは小説フォルダ以外に作られても無害な再生成可能データであり、`novel_data.db`（非再生成のブックマークを含む）とは扱いが異なる。

## Decisions

### D1: 対象フォルダの解決は `currentNovelFolderPathProvider` を再利用する

`bookmark_providers.dart` の `currentNovelFolderPathProvider`（`FutureProvider<String?>`）をそのまま使う。LLM 側に同義の provider を新設しない。

- 新設すると、同じ `novel_data.db` に対して解決規則が2つ存在する状態になる。それがいま直している不具合そのものであり、再生産になる。
- `llm_summary_history_provider.dart` は既に `bookmark_providers.dart` を import している（`bookmarkJumpLineProvider`）。feature 間の新しい依存は生じない。

**代替案**: `shared/` へ移す。より綺麗だが、移動そのものが広い diff になり、この変更の検証対象を曖昧にする。置き場所の是正は別の機会に切り出せる。

### D2: 「DBの鍵」と「エピソードの並び」を分けて持つ

解析実行・hover popup・履歴パネルのいずれでも、次の2つを別の変数として扱う。

```
  novelFolder   = resolveNovelFolderPath(現在地)   -- novel_data.db の所在
  episodeFolder = 現在地                            -- .txt の並び
```

`novel_data.db` を開くのは `novelFolder` のみ。上限話数の算出（`resolveUpperBoundForCurrent` / `resolveUpperBoundForAll`）、全話スコープの `source_file` 決定、履歴からのジャンプ先パスの組み立ては `episodeFolder`。

`source_file` は「エピソードの並びに属する名前」として記録されてきたので、記録側と読み出し側の両方を `episodeFolder` に揃えないと、過去の行が指すファイルを取り違える。サポートされる配置では両者は同じフォルダなので、この分離に観測可能な差は出ない。分けるのは、片方だけを動かしたときに静かに壊れる箇所を無くすため。

### D3: 履歴の遮断は provider とパネルの両方に置く

パネル側では `novelFolder` が解決できないときに `llmSummaryHistoryProvider` を watch せず、既存の `bookmark_selectNovelPrompt` を表示する。provider 側でも `build` で解決できなければ空を返し、リポジトリを開かない。

パネルだけに置くと、将来この provider を watch する別の consumer が現れた瞬間に同じ不具合が戻る。DBを開かない責任は、DBを開く側に置く。

### D4: 新規フォルダ作成ボタンは「小説フォルダでないと確証が持てるときだけ」有効

`allNovelsProvider` が未解決の間はボタンを無効にする。登録済みフォルダ名の集合が空の状態で `resolveNovelFolderPath` を呼ぶと必ず `null`（＝小説フォルダではない）を返すため、「解決結果が null なら有効」にすると起動直後の数フレームだけ小説フォルダ内で押せてしまう。

非表示ではなく無効化（`onPressed: null`）にする。親フォルダへ戻るボタンが `hasParent` で同じ形を取っており、ボタンが消えるとツールバーの並びが動く。

### D5: 既存の `novel_data.db` は残す

整理フォルダに作られてしまったファイルは、中身が空でもユーザーのファイルである。起動時に走査して消す処理は、消す対象の判定を誤ったときの被害が大きすぎる。放置しても新たな書き込みは起きない。

## Risks / Trade-offs

- **整理フォルダ直下のテキストで LLM 解析を使っていた場合、使えなくなる** → ブックマークが同じ場所で既に無効であり、そちらは現状維持と決めた（`Q1'`）。同じ境界に揃えるという判断であって、LLM だけを狭めるのではない。既存の解析結果のファイルは消えない。
- **小説フォルダ内のサブフォルダに記録済みの履歴が見えなくなる** → 変更後はそのサブフォルダではなく親の小説フォルダの `novel_data.db` を読むため。アプリ内にエピソードをサブフォルダへ置く経路は無く（ファイル単位の移動・改名が存在しない）、アプリ外で手動配置した場合にのみ起こる。ファイルは残る。
- **hover popup の対象フォルダ解決を同期で行う** → `ref.listen` のコールバック内で await すると popup の表示が1フレーム以上遅れる。`allNovelsProvider` の現在値から同期に解決し、未ロードなら popup を出さない。マークの描画自体がその小説の要約の存在を前提とするため、未ロード状態でマークに hover できる経路は実質無い。
- **ブックマークと LLM で解決規則が揃うことで、両者の失敗条件も揃う** → 片方だけが動く状況が無くなるのは利点だが、小説フォルダの判定が壊れた場合の影響範囲は広がる。判定は既存の共有関数 `resolveNovelFolderPath` 一本であり、新しい分岐は増やさない。

## Migration Plan

データ移行なし。スキーマ変更なし。l10n の新規文言なし。ロールバックは revert のみで足りる。
