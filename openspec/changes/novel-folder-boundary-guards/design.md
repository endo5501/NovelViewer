## Context

動機は proposal.md の「Why」を参照。ここでは実装上の判断だけを記す。

現状の構造で効いてくる事実は3つ。

- `novel_data.db` を開く経路は2つしかない。`bookmark_providers.dart` と `llm_summary_providers.dart` で、どちらも `novelDataDatabaseProvider(folderDbKey(folderPath))` を通る。前者は `resolveNovelFolderPath` で解決したパスを渡し、後者はブラウザの現在地をそのまま渡している。
- `NovelDataDatabase.openFile` は `onCreate` を持つ。開くことは作ることでもある。
- LLM 側が現在地を使っている箇所は、**DBの鍵**として使っている箇所と、**エピソードの並び**として使っている箇所が混ざっている。`llmSummaryRepositoryProvider(directory)` は前者、`resolveUpperBoundForAll(directory)` は後者。

## Goals / Non-Goals

**Goals:**

- `novel_data.db` が登録済み小説フォルダ以外に作られる経路を無くす。読み（履歴パネル）と書き（解析実行）の双方で。
- LLM の「DBの鍵」と「エピソードの並び」を、同じ1つのフォルダに畳む。食い違えないようにする。
- 小説フォルダの中に整理フォルダを作る唯一の経路を塞ぐ。

**Non-Goals:**

- `selectedFileProvider` の `clear()` には触れない。読書コンテキスト（`reading-context`）への消費者移行も行わない。本変更はすべて `currentDirectoryProvider` を起点としたままで完結する。
- 既に作られてしまった `novel_data.db` の削除・移行は行わない。
- TTS 音声DB・辞書DB・エピソードキャッシュDBの鍵は変更しない。これらは小説フォルダ以外に作られても無害な再生成可能データであり、`novel_data.db`（非再生成のブックマークを含む）とは扱いが異なる。

## Decisions

### D1: 対象フォルダは「ブラウザが小説フォルダに**いる**とき」だけ

`summaryNovelFolderProvider`（`llm_summary_providers.dart`、同期の `Provider<String?>`）を1本置き、LLM 側の全消費者がこれだけを見る。

```dart
resolveNovelFolderPath(libraryPath, currentDir, 登録名) == currentDir
  ? currentDir
  : null
```

祖先をたどって得たフォルダが現在地**そのもの**であることを要求する。深さには依存しない（整理フォルダの配下に置かれた小説フォルダも対象）。null になるのはライブラリルート・整理フォルダ・**小説フォルダ内のサブフォルダ**、および小説一覧が未取得のとき。

**当初はブックマークの `currentNovelFolderPathProvider`（最も近い登録済み祖先）をそのまま再利用する設計だった。** レビューで、その規則がサブフォルダ配置で破壊的になることが分かったため変更した。サブフォルダから解析すると、話数はサブフォルダ内で数えられる一方で行は親の `novel_data.db` に入る。`word_summaries` は `UNIQUE(word, covered_up_to_episode)` の upsert なので、親が同じ鍵で持つスナップショットが別内容で静かに上書きされる。変更前はサブフォルダが自分の DB を持っていたため衝突しなかった — つまりこれは本変更が作る退行だった。

「小説フォルダに**いる**」を要求すると、この食い違いが構造的に起こり得なくなる。ブックマークは祖先解決のままなので、同じ `novel_data.db` に対して規則が2つ存在することにはなるが、両者が異なる結果を返すのはサブフォルダ配置だけであり、そこでは LLM 側が「扱わない」を選んでいる。ブックマーク側の是正は本変更の範囲外とする（Q1' の判断を維持）。

### D2: 「DBの鍵」と「エピソードの並び」は同じフォルダ

D1 の帰結として、1つのフォルダが両方の役割を持つ。`novel_data.db` の所在も、上限話数の算出（`resolveUpperBoundForCurrent` / `resolveUpperBoundForAll`）も、`source_file` の記録と読み出しも、履歴からのジャンプ先の組み立ても、すべて `summaryNovelFolderProvider` の値。

一時は `novelFolder`（DB）と `episodeFolder`（並び）を別変数で持つ実装にしたが、両者が食い違う状態を許すことがそのまま上書き事故の条件だった。食い違いを扱うのではなく、食い違う場所では動かない、とした。

### D2b: 同期 `Provider` にする

`FutureProvider` にしてはならない。保留中に再計算されると、先に取得済みの `.future` は `Bad state: The provider ... was disposed during loading state` を投げる。`analysis_runner.run()` はこれを await していたため、ダウンロード直後のように `allNovelsProvider` が再取得中だと、解析が未処理例外で死んで画面には何も出なかった。

同期 `Provider` なら待つものが無く、要求時点の値をそのまま捕捉できる。`run()` は複数の await をまたぐので、フォルダは最初に一度だけ読んで持ち回る。読み直すと、途中で移動した読者の本文が別の作品の DB に入る。

`allNovelsProvider` 自体は `FutureProvider` なので、未取得の間は null を返す。その間は解析も履歴も出ない。起動直後の数フレームに限られ（AppBar のタイトル provider が常時 watch している）、失敗の仕方も「案内が出る」で安全側に倒れる。

### D3: 履歴の遮断は provider とパネルの両方に置く

パネル側では `summaryNovelFolderProvider` が null のときに `llmSummaryHistoryProvider` を watch せず、既存の `bookmark_selectNovelPrompt` を表示する。provider 側でも `build` で null なら空を返し、リポジトリを開かない。

パネルだけに置くと、将来この provider を watch する別の consumer が現れた瞬間に同じ不具合が戻る。`markedWordsProvider` が既に `llmSummaryHistoryProvider` を無条件に watch しているため、これは仮定の話ではない。DBを開かない責任は、DBを開く側に置く。

`deleteEntry` と `openEntry` はフォルダを**引数で受け取る**。一覧を表示している widget が自分の `novelFolder` を渡す。ただし `deleteEntry` はフォルダ別リポジトリを開く（＝ファイルを作る）ので、渡されたフォルダが登録済み小説フォルダであることを自分でも確かめる。引数化によって、DBを開かない責任が呼び出し側だけに移ってしまうのを避ける。判定は `summaryNovelFolderProvider` と同じ述語（`isRegisteredNovelFolder`）を共有する。

当初は `build` で決まったフォルダを notifier のフィールドに持たせたが、これは誤りだった。Riverpod は依存が変わると notifier のインスタンスを保持したまま `build` を再実行するため、そのフィールドは「一覧の出自」ではなく常に最新の対象になる。フォルダを自分で解決できる場所に置く限り、同じ間違いが形を変えて戻る。widget は不変なので、メニューのコールバックが捕捉するのは一覧を描いたときのフォルダそのものになる。

### D4: 新規フォルダ作成ボタンは「小説フォルダでないと確証が持てるときだけ」有効

`allNovelsProvider` の初回ロードが終わるまではボタンを無効にする。登録済みフォルダ名の集合が空の状態で `resolveNovelFolderPath` を呼ぶと必ず `null`（＝小説フォルダではない）を返すため、「解決結果が null なら有効」にすると起動直後の数フレームだけ小説フォルダ内で押せてしまう。

一覧の**再取得中**は `AsyncValue.value` が直前の値を保持するため、ボタンは古い一覧で判定する。ここでは無害と判断した。一覧を invalidate する操作（ダウンロード・更新・削除）はいずれも別のフォルダを増減させるもので、いま表示しているフォルダ自身の登録状態を変えない。一覧がエラーになった場合はボタンが無効のままになるが、その状態ではファイル一覧自体がフォルダを分類できずエラー表示になる。

非表示ではなく無効化（`onPressed: null`）にする。親フォルダへ戻るボタンが `hasParent` で同じ形を取っており、ボタンが消えるとツールバーの並びが動く。

### D5: 既存の `novel_data.db` は残す

整理フォルダに作られてしまったファイルは、中身が空でもユーザーのファイルである。起動時に走査して消す処理は、消す対象の判定を誤ったときの被害が大きすぎる。放置しても新たな書き込みは起きない。

## Risks / Trade-offs

- **整理フォルダ直下のテキストで LLM 解析を使っていた場合、使えなくなる** → ブックマークが同じ場所で既に無効であり、そちらは現状維持と決めた（`Q1'`）。同じ境界に揃えるという判断であって、LLM だけを狭めるのではない。既存の解析結果のファイルは消えない。
- **小説フォルダ内のサブフォルダで LLM 機能が使えなくなる** → 履歴も解析も hover popup も出ない。そのサブフォルダに記録済みの `novel_data.db` があっても読まない。アプリ内にエピソードをサブフォルダへ置く経路は無く（ファイル単位の移動・改名が存在しない）、アプリ外で手動配置した場合にのみ起こる。ファイルは残る。親の小説フォルダへ戻れば、そちらの履歴は従来どおり使える。上書き事故を起こすより、扱わない方を選んだ。
- **hover popup は同期 provider を読む** → `ref.listen` のコールバック内で await すると popup の表示が1フレーム以上遅れる。`summaryNovelFolderProvider` は同期 `Provider` なので待つものが無く、null なら popup を出さない。
- **表示中の popup は対象フォルダの変化で閉じる** → 表示モードの変化で閉じるのと同じ形で `hide()` する。ブラウザの移動は通常ポインタ押下を伴い、既存の dismissal barrier が拾うが、ファイルブラウザはキーボードだけでも操作できる。残った popup からの再解析は、前の小説の話数とファイル名を新しい小説の DB に書き込む経路になる。
- **ブックマークと LLM で解決規則が揃うことで、両者の失敗条件も揃う** → 片方だけが動く状況が無くなるのは利点だが、小説フォルダの判定が壊れた場合の影響範囲は広がる。判定は既存の共有関数 `resolveNovelFolderPath` 一本であり、新しい分岐は増やさない。

## 後続 change への申し送り

`summaryNovelFolderProvider` は**ファイルブラウザの現在地**から解決する。一方、解析対象の単語と `selectedFileProvider` は本文ビューア側から来る。この2つが同じ小説を指すのは、ブラウザを動かすと選択が解除される（`file_browser_panel.dart` の3箇所の `clear()`）ためであって、この provider が保証しているからではない。

`clear()` を外す change では、この provider を `readingNovelFolderProvider` 起点へ移す必要がある。移さないと、A を読みながらブラウザが B にいる状態で解析でき、A の本文の要約が B の `novel_data.db` に同じ鍵で書き込まれる — D1 がサブフォルダについて潰したのと同型の事故が、フォルダの組を変えて復活する。

同時に、履歴パネル・ブックマーク一覧・検索が「ブラウザに従うか読者に従うか」も決める必要がある（この change の探索で洗い出した論点）。`summaryNovelFolderProvider` はその決定の単一の適用点になる。

## Migration Plan

データ移行なし。スキーマ変更なし。l10n の新規文言なし。ロールバックは revert のみで足りる。
