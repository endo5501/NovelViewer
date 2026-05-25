## Context

NovelViewer は左カラムにファイル一覧、中央カラムにテキストビューア（縦書き / 横書き切替）、右カラムに検索結果を持つ 3 カラム構成のデスクトップアプリ。ファイル一覧は `FileBrowserPanel` (`ListView`) が描画し、選択中ファイルは `selectedFileProvider` で保持される。テキストビューアは `TextViewerPanel` → `TextContentRenderer` の経路で組み立てられ、表示モードに応じて `VerticalTextViewer`（ページネーション）または `SelectableText.rich`（連続スクロール）に分岐する。

現状の制約：
- AppBar タイトルは `selectedNovelTitleProvider`（小説タイトル or フォルダ名）のみを表示し、ファイル名・話数進捗は持っていない。
- ファイル選択ハイライトは Material 3 `ListTile.selected` のデフォルト挙動で、ダークモードでは背景差分が極めて弱い。
- `ListView` には `ScrollController` が設定されておらず、選択行が画面外にあっても自動的にスクロールしない。
- `VerticalTextViewer._changePage` は `clamp(0, _pageCount - 1)` で境界をハードに止めているため、最終ページでさらに次ページへ進む入力は完全に捨てられている。
- 横書きモードは `SingleChildScrollView` で連続スクロールするため、「末尾」の判定タイミングを直感的に拾うのが難しい。
- ファイル切替時の初期表示位置は常にコンテンツ先頭で、「前話の末尾から続きを読む」という連続読書のユースケースに対応する仕組みがない。

ステークホルダー：単一ユーザー（個人利用）。Web 小説（なろう、カクヨム）をローカルで読書する用途で、1 シリーズあたり 100〜200 話に達することがある。

## Goals / Non-Goals

**Goals:**
- 100〜200 話規模の小説でも「いま自分が何話目を読んでいるか」が画面の複数箇所（AppBar、ファイル一覧）から即座に分かる。
- ダークモード／ライトモードのどちらでも、ファイル一覧の選択行が一瞥で識別できる。
- 末尾まで読み切ったら、ファイル一覧を開かずにそのままページ送りで次話に進める（誤操作は 2 段階確認で防止）。
- 「前話に戻る」も対称に提供し、前話に戻った時は前話の最終ページから開始することで「行きつ戻りつ」の読書体験を自然に維持する。
- 既存の TTS / 検索 / ブックマーク / ページネーション計算ロジックには影響を与えない。

**Non-Goals:**
- TTS が章末まで読み上げたら自動で次話へ遷移する、といった「読み上げ」と「ファイル遷移」の連動。
- 「次話プリフェッチ」「事前ロード」のような読書体験の最適化（必要が出てから別変更で扱う）。
- ブックマークと次話遷移の連動（ブックマーク独立で動作させる）。
- スクロール慣性や「弾性バウンス」のような視覚演出を末尾遷移に追加する。
- 横書きモードでの「末尾検出によるヒント方式」（縦モードと挙動を揃えず、ボタン常設で割り切る）。

## Decisions

### 1. 「次／前ファイル導出」と「ファイル切替 intent」を新 capability に切り出す

**Decision**: `lib/features/episode_navigation/` を新設し、以下の 2 つの Riverpod provider を提供する。
- `adjacentFilesProvider`: `directoryContentsProvider` と `selectedFileProvider` を watch し、現在ファイルの前後の `FileEntry?`（端なら null）を返す `Provider<AdjacentFiles>`。
- `pendingFileEntryIntentProvider`: ファイル切替時の開始位置ヒント（`FileEntryStartIntent.fromStart` / `.fromEnd`）を一時的に保持する `NotifierProvider<..., FileEntryStartIntent?>`。

**Why**: 「前後ファイル導出」はファイル一覧と縦書きビューア両方から参照する横断的な関心事であり、`file_browser` モジュールに同居させると依存方向が UI に汚染される。intent provider もファイル切替トリガー側（ビューア）と消費側（ビューアの初期ページ計算）が分離されているので、専用のフィーチャーに置くのが自然。

**Alternatives considered**:
- `file_browser_providers.dart` に追加: 上記の通り依存方向に問題。テストも file_browser 全体を巻き込む。
- `VerticalTextViewer` のローカル state で持つ: 横書きモードのボタンと共有できず、対称性が失われる。

### 2. ファイル切替時の「開始位置ヒント」は intent provider 経由でワンショット渡し

**Decision**: 前話に戻る操作（縦書き先頭でのもう一度押下、横書きの「前話」ボタン）を検知した時、以下の順で実行する：
1. `pendingFileEntryIntentProvider` に `FileEntryStartIntent.fromEnd` をセット。
2. `selectedFileProvider` に前ファイルをセット（既存の `selectFile()`）。
3. ビューアの初期描画時に intent を読み取って `_currentPage = _pageCount - 1`（縦書き）または `maxScrollExtent` までスクロール（横書き）。
4. 消費直後に `pendingFileEntryIntentProvider` を `null` にクリア。

**Why**: ファイル切替は既存の `selectedFileProvider` という単一の真実源で行われており、それを通すと既存のキャッシュ／クリア処理（`text_viewer_providers.dart` の `selectedTextProvider` リセット、TTS 状態リセット等）が自然に走る。intent を別チャネルで先に渡しておくと、ファイル切替自体は既存経路のまま、ビューア側だけが「初期位置」だけ追加で参照できる。既存の `targetLineNumber`（ブックマークジャンプ）や `bookmarkJumpLineProvider` と同じパターン。

**Alternatives considered**:
- ファイル切替 API を `selectFileWithStartPosition()` に拡張: `SelectedFileNotifier` のシグネチャを変える侵襲性があり、selectedFile を読む全箇所への影響が大きい。
- `selectedFile` 自体に開始位置をペアで持たせる: `FileEntry` のセマンティクスを汚す。
- `routeArguments` 的なナビゲーション層を入れる: Flutter Navigator を使わない現アーキテクチャと整合しない。

### 3. 縦書きモード末尾の 2 段階確認は `VerticalTextViewer` のローカル state で実装

**Decision**: `_VerticalTextViewerState` 内に以下を追加する：
- `bool _pendingNextFilePrompt`（末尾でもう一度押すと次話へ進む状態か）
- `bool _pendingPrevFilePrompt`（先頭でもう一度押すと前話へ戻る状態か）
- `Timer? _promptTimeoutTimer`（タイムアウト）
- タイムアウト: `_kFileNavigationPromptTimeout = Duration(seconds: 4)` (4 秒)

挙動：
- `_changePage(+1)` 呼び出し時、すでに `_currentPage == _pageCount - 1` かつ `pending != true` の場合、次ファイルが存在すれば `_pendingNextFilePrompt = true` にしてタイマー起動、`setState`。
- 同状態でもう一度 `_changePage(+1)` が呼ばれたら `_navigateToAdjacent(next: true)` を実行。
- タイマー満了で `_pendingNextFilePrompt = false` にして `setState`。
- 反対方向の操作（先頭側ボタン押下、矢印キーの逆など）や他のページ遷移操作が来たら即座にタイマーをキャンセルして prompt をクリア。
- 「次ファイルが存在しない」状況では prompt 自体を出さず、現行の no-op を維持。

ヒント表示は既存のページ番号エリア（`vertical_text_viewer.dart` の `'${safePage + 1} / $totalPages'` Text ウィジェット部分）を差し替える形で実装する：
- 通常時: `${page} / ${total}`
- next prompt 時: `▶ 次話「<filename>」へ (もう一度)` （l10n キー化）
- prev prompt 時: `◀ 前話「<filename>」へ (もう一度)` （l10n キー化）

**Why**: prompt 状態は完全に UI のローカル状態でビジネスロジックを持たない。Riverpod に持ち上げる必然性がなく、ビュー寿命と一致しているのが自然。タイマーの確実な dispose も `State.dispose` で扱える。

**Alternatives considered**:
- `Riverpod` の `Notifier` に持ち上げる: ビュー再構築をまたぐ必要が無く、過度な抽象化。
- `OverlayEntry` でトースト表示: ページ番号エリアという既存の自然な「位置」を活かせない。

### 4. 横書きモードはヒント方式ではなく常設ボタン

**Decision**: `TextContentRenderer` の build 結果に重ねる形で、`Positioned(left: 8, bottom: 8)` 付近に Material 3 の `OutlinedButton.icon` を 2 つ並べた小バーを置く。`TtsControlsBar` は右下 (`right: 8, bottom: 8`) なので、左下に配置することで衝突しない。

ボタンは `adjacentFilesProvider` を watch し、次／前ファイルが無ければ `onPressed: null`（disabled 表示）にする。タップで `pendingFileEntryIntentProvider` を `fromEnd`（前話遷移時）または `fromStart`（次話遷移時）にセット → `selectedFileProvider.selectFile(target)`。

**Why**: 横書きモードは連続スクロールで「末尾」の判定が直感的にしにくい上、マウスホイールの慣性スクロールで誤判定リスクが高い。常設ボタンは画面の一部を占有するが、横モードの利用頻度（ユーザー回答：縦書きが頻繁）を踏まえれば許容できるトレードオフ。

**Alternatives considered**:
- 横モードでも末尾検出 + 2 段階確認: スクロール末尾判定の実装複雑度に対して見返りが乏しい。
- ボタンを AppBar に置く: 表示位置が遠く、ファイル切替トリガーとしての視認性が落ちる。

### 5. AppBar タイトル拡張は新 provider `selectedFileProgressTitleProvider` に分離

**Decision**: 既存の `selectedNovelTitleProvider` はそのまま残し、AppBar 表示用に以下の新 provider を追加する：

```
final selectedFileProgressTitleProvider = Provider<String>((ref) {
  final novelTitle = ref.watch(selectedNovelTitleProvider).value;
  final base = novelTitle ?? 'NovelViewer';
  final files = ref.watch(directoryContentsProvider).value?.files ?? const [];
  final selected = ref.watch(selectedFileProvider);
  if (selected == null || files.isEmpty) return base;
  final idx = files.indexWhere((f) => f.path == selected.path);
  if (idx < 0) return base;
  return '$base — ${selected.name} (${idx + 1}/${files.length})';
});
```

`HomeScreen` の `AppBar(title: Text(...))` 部分はこの新 provider を watch する形に差し替える。

**Why**: `selectedNovelTitleProvider` は他の場所（既存 spec の意図）で再利用される可能性があり、AppBar 表示専用ロジックを混ぜると単体テストが煩雑になる。組み立て専用の薄い派生 provider に切り出すことで、テストもタイトル組み立てロジック単体で行える。

**Alternatives considered**:
- `selectedNovelTitleProvider` を「ファイル名込み」に変える: spec が変わってしまうし、他箇所での意味も変化する。
- `HomeScreen` 内のローカル変数で組み立てる: 単体テストできない。

### 6. ファイル一覧自動スクロールは `Scrollable.ensureVisible` を `selectedFileProvider` listen で実行

**Decision**: `FileBrowserPanel` を `StatefulWidget` に変更し（または `HookConsumerWidget` 化）、各 `ListTile` に `GlobalKey` を割り当てる。`ref.listenManual(selectedFileProvider)` で選択ファイル変化を検知し、対応する key の `BuildContext` に `Scrollable.ensureVisible(..., alignment: 0.5, duration: ...)` を post-frame で呼ぶ。

**Why**: `ListView`（非 builder）はすでに全 ListTile を構築済みで、各行に `GlobalKey` を持たせれば座標計算なしで確実にスクロールできる。`ListView.builder` 化や `ScrollablePositionedList` のような追加依存導入は規模に対して過剰。

**Important**: ファイル数が極端に多い場合のパフォーマンス／キー量の懸念があるが、200 話程度なら GlobalKey 200 個は無視できるコスト（Flutter 自身がアイテム数千程度なら `ListView` を許容している）。将来 1000 話を超えるユーザーが現れた場合に builder 化を検討する。

**Alternatives considered**:
- 各 `ListTile` の高さ（あるいは固定行高）からオフセット計算: ListTile の trailing アイコンや displayName の長さで動的に高さが変わるため、計算が不安定。
- `ScrollablePositionedList` パッケージ導入: 依存追加のコストに対して恩恵が小さい。

### 7. 選択ハイライトのスタイル

**Decision**: 選択中の `ListTile` を `Container` でラップし、以下の `BoxDecoration` を適用する：
- `color: Theme.of(context).colorScheme.secondaryContainer`（M3 既定の selection color より明確）
- 左端に幅 4px の `Border(left: BorderSide(color: colorScheme.primary, width: 4))`
- `ListTile` の `title` の `TextStyle` に `fontWeight: FontWeight.w600` を追加

ライト／ダーク両モードで Material 3 が提供する `colorScheme.secondaryContainer` と `primary` のコントラスト保証を活用する。

**Why**: M3 既定の `selectedTileColor` だけだとダークモードで視認性が極端に低い。アクセントバーと太字を組み合わせることで、色覚特性に依存しない複数の知覚チャネルで「選択中」を伝達できる。

### 8. ローカライズ

**Decision**: `lib/l10n/` の ARB ファイルに以下のキーを追加する：
- `verticalText_nextEpisodePrompt(name)` → 「▶ 次話「{name}」へ (もう一度)」 / `▶ Next: "{name}" (press again)` / `▶ 下一话「{name}」（再按一次）`
- `verticalText_prevEpisodePrompt(name)` → 「◀ 前話「{name}」へ (もう一度)」 / 同様 / 同様
- `textViewer_nextEpisodeButton` → 「次話 →」
- `textViewer_prevEpisodeButton` → 「← 前話」

既存の `vertical_text_viewer.dart` は l10n をまだ参照していないので、`AppLocalizations.of(context)` のインポートも合わせて追加する。

## Risks / Trade-offs

- **[Risk] 自動スクロールがユーザーの手動スクロール中に発火し、操作感を損なう** → 自動スクロールは `selectedFileProvider` 変化時のみ発火する（ユーザーがファイルを切り替えた時）。手動スクロールは選択行を変えないので、衝突しない。同一ファイル再選択時（path 一致）は no-op にして二重トリガを避ける。

- **[Risk] 2 段階確認のタイムアウト中に他のキー入力が来ると prompt が残留する** → ページ送り以外の任意の入力（矢印逆方向、マウスホイール逆方向、ボタンフォーカス変更、ファイル切替等）でタイマーをキャンセルし prompt をクリアする。`didUpdateWidget` で `widget.segments` が変わった場合も明示的にクリア。

- **[Risk] 「次話の冒頭ページ」「前話の最終ページ」が、ページネーション計算の確定前に求められる** → ページ数は `_paginateLines` で `LayoutBuilder` の constraints が決まってから初めて確定する。初回 build で `_pageCount` が未確定の場合、`pendingFileEntryIntentProvider` を `build()` 内で消費せず、`addPostFrameCallback` で `_pageCount` が確定した後にジャンプする。既存の `_pendingTtsOffset` と同じ遅延パターン。

- **[Risk] 横書きモードの次話／前話ボタンと既存 `TtsControlsBar` がレイアウト的に衝突** → ボタン位置は左下 (`left: 8, bottom: 8`)、TTS は右下 (`right: 8, bottom: 8`) と明確に左右に分離する。ウィンドウ幅が極端に狭い場合の重なりは現実的でない（最低ウィンドウ幅 vs ボタン幅）が、`MediaQuery` で監視するほどではない。

- **[Risk] 選択ハイライト強化により、テーマ切替時の視覚的不連続が生じる** → `colorScheme.secondaryContainer` / `colorScheme.primary` は Material 3 が両モードで一貫性を提供しているので、ハードコードカラーを避ければ概ね追従する。

- **[Trade-off] 横書きモードは縦書きモードと挙動が非対称（ヒント vs 常設ボタン）** → 一貫性は失われるが、それぞれのモードの自然なインタラクションを優先する。ユーザー自身が縦書きを主に使うため許容できる。

- **[Trade-off] 200 話で GlobalKey × 200** → 観測コストは無視できる範囲だが、将来 builder 化が必要になった時の移行コストは残る。閾値（例: 500 行超）を超えたら別変更で再設計する。

- **[Risk] AppBar タイトルが長くなりすぎてオーバーフローする** → `Text` ウィジェットの `overflow: TextOverflow.ellipsis` で省略する。`maxLines: 1`。タイトルの本質情報は冒頭の小説名と末尾の `(N/M)` 進捗で、中央のファイル名は省略されても支障が小さい順序にする。

## Migration Plan

新規機能の追加のみで既存挙動の破壊は無いため、フィーチャーフラグや段階展開は不要。`pendingFileEntryIntentProvider` の初期値は `null` なので、未消費でも既存挙動（先頭から開始）になる。

## Open Questions

- なし（仕様は explore 段階で合意済み）。
