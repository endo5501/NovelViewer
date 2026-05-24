## Context

LLM単語要約機能は `llm-summary`, `llm-summary-pipeline`, `llm-summary-cache`, `llm-summary-history-ui` の4つのspecで構成されている。本changeは表示UIと起動UIだけを差し替え、パイプライン/キャッシュ/markレンダリングの中核ロジックには手を入れない。

主要な既存資産：
- `text_content_renderer.dart` が横書き(`SelectableText.rich`) / 縦書き(`VerticalTextViewer`) の分岐を持ち、ruby + 検索ハイライト + TTSハイライト + mark下線を同居させている
- `ruby_text_builder.dart` の `_applyLocalMarksToSpans` がmark対象範囲を `TextSpan(decoration: underline, decorationStyle: dotted|solid)` に分解している
- `markedWordsProvider` がキャッシュ済み語と `MarkStyle` のmapを提供（履歴provider監視で再描画）
- 横書きの右クリメニューは `buildDictionaryContextMenu` で組み立てており、Flutter標準の `AdaptiveTextSelectionToolbar` ベース
- 縦書きの右クリメニューは `_showVerticalContextMenu` の自前 `showMenu` 実装

ユーザ操作モデルの変化：
- 旧：単語選択（mouse/touch）→ 右パネルが反応 → 右パネルのボタンを押す（2点間遷移）
- 新：マーク済み語にホバー（参照） / 任意の語を選択して右クリック → サブメニュー選択（起動）。参照と起動が分離

## Goals / Non-Goals

**Goals:**
- 既キャッシュ語の要約を、視線/手をほぼ動かさずに参照できる
- 解析の起動を、選択地点から1～2クリック以内で完結させる
- markレンダリング・キャッシュ・パイプライン部分には改修を加えない
- 右カラムの幅消費を減らし、本文表示領域を相対的に広げる

**Non-Goals:**
- 縦書きモードでのホバーポップアップ対応（mark表示は維持、ポップアップは出さない）
- ポップアップ内テキストのコピー対応（コピーは履歴タブ側で提供）
- 解析処理のキャンセル機能（現状もない）
- 解析中のプログレス表示（進捗％取得手段がない）
- LLMパイプライン/キャッシュ/markスキャンの仕様変更

## Decisions

### D1. ホバー検出機構：mark付きTextSpanの `onEnter`/`onExit` を使う

Flutter標準 `TextSpan` には `mouseCursor`, `onEnter`, `onExit` プロパティが存在し、`MouseTrackerAnnotation` 経由で hover を検出できる。`_applyLocalMarksToSpans` がmark範囲を独立した `TextSpan` に切り出しているので、それらの span 生成時に `onEnter/onExit` を取り付けるのが最小侵襲。

**代替案：**
- (a) mark範囲を `WidgetSpan` でラップして `MouseRegion` を被せる → WidgetSpanは選択範囲計算では1文字扱いになり、SelectableTextの選択挙動・コピー結果に副作用が出る恐れ。回避不能ではないが回帰リスクが高く却下
- (b) 本文全体を `MouseRegion` で覆い `RenderParagraph.getPositionForOffset` で文字位置を逆引きしてmark判定 → 座標境界の誤差が出やすく、実装複雑度の割にメリットが薄い。却下

**確認すべき動作：**
- `onEnter`/`onExit` がmarkされた span 範囲で正しく発火するか
- `decoration: underline` を持つ span と onEnter の併存可否
- 隣接する mark/非mark span 間の境界で flicker が出ないか

これは proposal 完了後、tasks の最初のステップで小規模に検証する（design上のリスク、後述 R1）。

### D2. ポップアップ：`OverlayEntry` + 自前 widget で実装する

`Tooltip` ウィジェットは挙動が固定されており、内部に切替ピル・参照ズレ警告などの構造を持たせにくい。`OverlayEntry` ベースで自前のポップアップ widget を用意し、ホバー時に `Overlay.of(context).insert`、`onExit` 時に `remove` する。

- 位置：`PointerEnterEvent.position`（グローバル座標）の右下少しオフセット。画面端の場合はフリップ
- 内容：要約テキスト（最大幅 ~320px、超過時は折返し）、両種別キャッシュ済みの時は上部に [なし|あり] 切替セグメント、ノースポイラー要約で `sourceFile != currentFile` の時は下部に小さく警告テキスト
- スタイル：Material の Card / surfaceContainer 系、shadow elevation 4 程度
- ポップアップ自体には MouseRegion を付けない（純ホバー、マウスが mark 範囲から出たら即消える仕様のため）

### D3. ホバー対象データ：mark span に「単語」をひも付けて渡す

`_applyLocalMarksToSpans` は現在 `MarkSpan` を受け取って TextSpan に分解しているが、span 側から「自分が何の単語のmarkか」を引けるようにする必要がある。`MarkSpan` には既に `word` フィールドがあるので、span生成時にそれをクロージャに閉じ込めて `onEnter` ハンドラに渡す。

```dart
output.add(TextSpan(
  text: subText,
  style: markStyle,
  onEnter: (event) => _onHoverEnter(word: runWord, at: event.position),
  onExit: (_) => _onHoverExit(),
));
```

### D4. ポップアップ表示状態の管理：Riverpod Notifier

ポップアップの「表示中かどうか / どの単語 / 表示位置 / 現在表示中の種別」を `HoverPopupNotifier` で持つ。`onEnter` から `.show(word, position)`、`onExit` から `.hide()` を呼ぶ。OverlayEntry の挿入/破棄は notifier ではなく、`text_content_renderer` 配下のラッパWidget が `ref.listen` で行う（OverlayEntryはBuildContextを要するため）。

ポップアップ内の表示種別切替（A. 既定なし / 切替あり）は、notifier の `setSummaryType(type)` で更新する。

### D5. ポップアップに渡すデータ：キャッシュリポジトリから即座に取得

ホバー対象の単語は markedWords に乗っているのでキャッシュ存在は確定しており、リポジトリから `findSummary` する遅延は最小。ただし非同期 IO なので、ポップアップ表示の瞬間は「読み込み中…」を出し、解決後に置き換える。FutureProvider をフラッシュキー（folder+word）で family 化すれば自然に書ける。

ホバーが連続して別単語へ移った時のキャンセル制御：FutureProvider は cancellable ではないが、表示側で `currentWord` と返却データの word が一致しない場合は破棄、で実害なし。

### D6. 右クリメニュー：横書きはFlutter標準、縦書きは自前 showMenu に項目追加

横書き `buildDictionaryContextMenu` は `AdaptiveTextSelectionToolbar` ベースで、項目はフラットなボタンリスト。Flutter標準では真の「サブメニュー」をtoolbar内に作るのが難しい（PlatformMenuBarでもなく `AdaptiveTextSelectionToolbar` は階層を持たない）。

→ **横書きでは項目を並列で2つ追加する**：「解析開始(ネタバレなし)」「解析開始(ネタバレあり)」。仕様要件 (C) を「サブメニュー」と書いていたが、Flutter制約で並列項目に妥協する。UX上はラベルが明示的になるのでむしろ分かりやすい。

縦書き `_showVerticalContextMenu` は `showMenu` で `PopupMenuItem` を返す自前実装。`PopupMenuItem` には `PopupMenuButton` 的なサブメニュー機能がない（FlutterのMenu API は `MenuAnchor` 系を使えばサブメニューが組めるが、現在の `showMenu` 実装からの乗り換えは別件）。縦書きも横書きと同じく **2項目並列** で揃える。

両モードとも、選択テキストが空 / mark対象未満（2文字未満）の場合でも、現在の選択テキストがある限り解析開始項目は表示する（mark対象の制約はあくまで表示側の話で、解析自体は1文字でも可能）。

**代替案：**
- 「解析開始…」1項目 → ダイアログで種別選択 → 1クリック多くなり、メリット薄。却下

### D7. 解析中モーダル：`showDialog(barrierDismissible: false)`

右クリ → 起動した瞬間にルートNavigator上で showDialog。中身は CircularProgressIndicator + 「解析中…」テキスト。解析完了/失敗時にdialogをpopして結果はSnackBarでフィードバック（成功: 「『アリス』の要約を保存しました」、失敗: エラーメッセージ）。

成功後はキャッシュが入り、`llmSummaryHistoryProvider` が invalidate されて `markedWordsProvider` 経由で本文側のmarkが自動更新される（既存の流れと同一）。

### D8. 右カラム構成：`SearchSummaryPanel` を廃止し `SearchResultsPanel` を直接配置

`SearchSummaryPanel` は `LlmSummaryPanel` + `SearchResultsPanel` を縦Splitしていた wrapper。LlmSummaryPanelが消えるならwrapperの存在意義もないので削除する。`home_screen.dart` で `SizedBox(width: 300, child: SearchResultsPanel(...))` に置き換え。

### D9. 履歴タブのコピー機能：エントリ右クリメニューに「要約をコピー」追加

既存の履歴エントリ右クリメニューには「削除」だけがある。「要約をコピー(ネタバレなし) / 要約をコピー(ネタバレあり)」を追加。両種別キャッシュ済みの「両」エントリでは2項目とも表示、片方のみの場合はそちらだけを表示する。Clipboard.setData で OS クリップボードへ。成功時SnackBar 1秒。

## Risks / Trade-offs

- **R1**: TextSpan の `onEnter`/`onExit` の実挙動が期待と異なる可能性（decorationを持つspan、隣接span境界でのflicker、Flutter version依存） → tasks の冒頭で最小プロトを書き、横書き SelectableText.rich + decoration付き span + onEnter を結合して動作確認するspike を入れる
- **R2**: 縦書きモードでは hover が使えないため、機能の利用可能性がユーザの表示モード設定に依存する → ヘルプ/設定説明には明示しない（隠し制約）。将来の縦書き対応は別change `llm-summary-hover-popup-vertical` で扱う想定
- **R3**: 純ホバー仕様により、ユーザがゆっくり読みたい時にマウスがズレるとポップアップが消える → ポップアップ位置を「カーソル右下のオフセット位置」に置き、マウス軌跡から外す。微調整は実装段階で
- **R4**: ホバー検出を全mark span に付けるとリスナ数が増える。長文ファイルで多数の語がキャッシュされた場合のパフォーマンス影響 → mark span 自体は既に画面分の範囲だけ生成されている。リスナはクロージャでoverheadも小さく、現実的なケース（100語/画面以下）では問題ない見込み。回帰が出たら lazy 化を検討
- **R5**: 既存の `selectedTextProvider` 駆動の cache loading は `LlmSummaryPanel` 撤去で不要になるが、`selectedTextProvider` 自体は辞書追加機能で使われているので残す。「選択した瞬間に右パネルが反応する」体験はなくなるが、これは change の意図通り
- **R6**: 横書きと縦書きで「右クリ後の動作」が同じである必要がある（横書きで解析→縦書きに切替→mark表示は出る）。解析開始トリガーは両モードに揃える必要があり、tasks に縦書き側の右クリメニュー拡張も明示

## Migration Plan

機能の利用者は本人のみであり、データ移行はキャッシュテーブル不変なので不要。

ロールアウト：
1. R1のspikeでTextSpan.onEnterの動作確認
2. 既存テスト（llm_summary_panel関連widget test、search_summary_panel関連）の削除/置換
3. ホバーポップアップ実装＋テスト
4. 右クリメニュー拡張＋テスト
5. 解析中モーダル＋テスト
6. 右カラム構成変更＋テスト
7. 履歴コピー機能＋テスト
8. 手動検証（横書きで一連の操作、縦書きでmark表示維持確認、履歴コピー）

ロールバック：本changeはUI差し替えが大半なのでgit revertで戻る。データ非破壊。

## Open Questions

- ホバーポップアップの「マウス軌跡から外したオフセット位置」の具体的な座標方針（右下16px? 上に置く?） → 実装段階で見ながら決める
- 解析失敗時のSnackBar表示時間 → 通常のエラーSnackBar慣習に従う（4秒程度）想定
- 両種別キャッシュ済みの語をホバーした時、切替ピル位置は上 or 右上 or 下 → 実装段階のデザイン判断
