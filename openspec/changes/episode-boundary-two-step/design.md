## Context

境界での話送りは 2 箇所に別々に実装されている。

| | 縦書き `VerticalTextViewer` | 横書き `TextContentRenderer` |
|---|---|---|
| 実装 | `_handleBoundaryNavigation(delta)` | `_navigateEpisodeAtEdge(direction)` |
| 確認 | 2 段階（ヒント → 確定） | 1 段階（即遷移） |
| 状態 | `_pendingNextFilePrompt` / `_pendingPrevFilePrompt` | なし |
| タイマー | `_promptTimeoutTimer`(4s) / `_confirmCooldownTimer`(300ms) | `_edgeNavCooldownTimer` |
| ヒント表示 | ページ番号領域を文言で上書き（`_buildIndicatorText`） | なし |
| 入力 | 左右矢印 / ホイール / スワイプ | 上下矢印 / ホイール |

縦書き側の状態はすべて `_VerticalTextViewerState` の私有フィールドで、外から使えない。横書きを 2 段階化するには、この状態機械を切り出す必要がある。

現行の縦書き実装には、仕様（`vertical-text-display`）が「実装はどちらかに統一すること」と留保していた点について、既に確定した挙動がある。

- ファイル内のページ移動が成立した場合は `_clearPendingPrompts()` を呼びヒントを解除する（`_changePage` 内）
- ヒント表示中に逆方向の境界入力が来た場合は、`_showFileNavigationPrompt` により**逆方向のヒントへ切り替わる**（待機状態へは戻らない）

本変更はこの確定済み挙動を共通仕様として明文化し、横書きにも適用する。

なお、実装後の実機確認とレビューで、当初の想定になかった 2 つの事実が判明した。どちらも D9 / D10 として決定に含めている。

- 確定クールダウンをヒント表示時点から測ると、macOS の慣性入力では 1 回のフリックで確定に達する。縦書きにも同じ穴があった
- 横書きはトラックパッド／タッチのスワイプで話送りできない。`PointerPanZoomUpdateEvent` は `PointerSignalEvent` ではないため `onPointerSignal` に到達しない

## Goals / Non-Goals

**Goals:**

- 2 段階確認の状態機械を、両ビューアが共有する単一の実装に統一する
- 状態機械を Flutter ウィジェットから切り離し、`fake_async` によるユニットテストでタイミング挙動（4 秒タイムアウト・300ms 確定クールダウン）を検証可能にする
- 横書きモードの境界ナビゲーションを 2 段階化し、対症療法である `_edgeNavCooldown` を撤去する
- 入力ソースを 1 つ追加するだけで済む形にし、横書きのドラッグ入力（トラックパッド／タッチ）を接続する
- 慣性の効いた 1 回のフリックで話送りが確定してしまう穴を、両モードまとめて塞ぐ

**Non-Goals:**

- iPad 対応そのもの。タッチのスワイプはトラックパッドと同じ経路で動くが、レイアウトやタッチ向けの UI 導線は後続変更で扱う
- 確定クールダウンの起点変更を除く、縦書きモードの挙動変更
- タイムアウト値・クールダウン値のユーザー設定化

## Decisions

### D1. 状態機械は Riverpod provider ではなく、ビューア State が所有する plain class にする

**決定**: `ChangeNotifier` を継承した plain Dart クラスとし、各ビューアの `State` が `initState` で生成し `dispose` で破棄する。

**理由**:

- 状態のライフサイクルはビューアの表示に一対一で紐づく。ファイル切替・表示モード切替のたびにビューアが再構築されるため、状態も一緒に破棄されるのが正しい。Riverpod provider にすると `autoDispose` のタイミングとビューアのライフサイクルを別々に管理することになり、ヒントが前のファイルに紐づいたまま残る事故が起きやすい
- 既存の縦書き実装も State 私有フィールドとタイマーで同じライフサイクルを実現しており、載せ替えが素直

**代替案**: `NotifierProvider` にして両ビューアが `ref.watch` する案。ビューアをまたいで状態を共有できる利点があるが、そもそも 2 つのビューアが同時に表示されることはないため利点がない。却下。

### D2. 隣接ファイルの有無は引数で渡し、状態機械は provider を読まない

**決定**: API を `hitBoundary(direction, {required bool hasAdjacent})` とし、`adjacentFilesProvider` の参照は呼び出し側（ビューア）が行う。

**理由**: 状態機械が Riverpod に依存しなくなり、`ProviderContainer` なしのユニットテストで全シナリオを網羅できる。`fake_async` と組み合わせればタイマー挙動も含めて widget を起動せずに検証できる。

### D3. 「遷移すべきか」は戻り値で返し、遷移そのものは呼び出し側が行う

**決定**:

```dart
enum EpisodeBoundaryDirection { next, previous }

class EpisodeBoundaryPrompt extends ChangeNotifier {
  EpisodeBoundaryPrompt({
    Duration promptTimeout = const Duration(seconds: 4),
    Duration confirmCooldown = const Duration(milliseconds: 300),
  });

  /// ヒント状態。待機中は null。
  EpisodeBoundaryDirection? get pending;

  /// 境界入力を 1 回投入する。戻り値が true なら呼び出し側が遷移を実行する。
  /// true を返す時点で内部状態は待機状態へリセット済み。
  bool hitBoundary(
    EpisodeBoundaryDirection direction, {
    required bool hasAdjacent,
  });

  /// ファイル内移動が成立した等の理由でヒントを破棄する。
  void reset();
}
```

**理由**: 状態機械が `episodeNavigationControllerProvider` を呼ばないため、副作用を持たない。ビューアは戻り値を見て `navigateToNext()` / `navigateToPrevious()` を呼ぶだけになる。テストでは戻り値を assert すればよく、モックが不要。

**代替案**: コールバック（`onConfirm`）を注入する案。テストでコールバック呼び出しを記録する手間が増えるうえ、`hitBoundary` の中で遷移が起きるため状態リセットとの順序が読みにくい。却下。

### D4. ビューアの責務は「境界に達したか」の判定のみ

**決定**: ビューアは入力を 2 通りに振り分ける。

```
入力
 ├─ ファイル内の移動が成立した      → prompt.reset()
 └─ 境界に達していて移動できない    → prompt.hitBoundary(dir, hasAdjacent: …)
                                        └─ true なら遷移を実行
```

**理由**: 仕様の「境界に達しない入力はヒントを解除する」「逆方向の境界入力は向きを切り替える」が、この振り分けだけで自動的に成立する。1 ページ／1 画面に収まるファイルでは両方向とも境界になるため、逆方向入力が `hitBoundary` に到達して向きの切り替えが働く。

境界判定のロジックはモードごとに異なるため、ビューア側に残す。

- 縦書き: `_changePage` で `newPage == _currentPage`（ページ番号がクランプされた）
- 横書き: `_pageScroll` で `target == position.pixels`、ホイールは `pixels >= maxScrollExtent` / `<= minScrollExtent`、ドラッグ由来の入力はスクロール通知から（D10）

### D5. 配置は `lib/features/episode_navigation/domain/`

**決定**: `lib/features/episode_navigation/domain/episode_boundary_prompt.dart`

**理由**: 隣接ファイル導出と開始位置 intent が既に `episode_navigation` feature にあり、境界確認は同じ関心事の続き。`text_viewer` 配下に置くと縦書き・横書き双方から参照する非対称な依存になる。

**代替案**: 新 feature ディレクトリ `episode_boundary/` を作る案。ファイル 1 つのために feature を増やす利点がない。却下。

### D6. 横書きのヒントは `TextContentRenderer` 内の `Stack` に重ねる

**決定**: `TextContentRenderer` が返すスクロールビューを `Stack(fit: StackFit.expand)` で包み、`Positioned(left: 8, right: 8, bottom: 8)` + `Center` にヒントを配置する。ヒント状態でないときは描画しない。

**理由**:

- 横書きの本文はスクロールビューが領域全体を占めるため、縦書きのように `Column` の兄弟として置くとスクロール可能量が変わってしまう。仕様の「本文のスクロール可能量に影響を与えてはならない」を満たすには重ねるしかない
- `TextViewerPanel` の `Stack` に置く案もあるが、ヒント状態は `TextContentRenderer` が持つため状態の持ち上げが必要になる。renderer 内に閉じるほうが素直
- `TtsControlsBar` は `TextViewerPanel` の外側の `Stack` にあり同じ下部帯を使う。両者は別の `Stack` で互いの幅を知らないため、視覚的な重なりは許容し、ヒントを `IgnorePointer` で包んでボタンの操作性だけは保証する。文言は `TextOverflow.ellipsis` で切る。TTS モデル未設定時はバーが描画されないため、実際に重なる場面は限定的

書体は縦書きと揃えて `Theme.of(context).textTheme.bodySmall`。本文の上に重なるため、可読性確保として `colorScheme.surfaceContainerHighest` 相当の背景と角丸、左右パディングを付す（仕様上許容されている）。

### D7. l10n キーはモード中立名へ改名し、文言も入力デバイス中立にする

**決定**:

| 現行キー | 新キー |
|---|---|
| `verticalText_nextEpisodePrompt` | `episodeBoundary_nextPrompt` |
| `verticalText_prevEpisodePrompt` | `episodeBoundary_prevPrompt` |

文言の見直し:

- ja: `▶ 次話「{name}」へ（もう一度）` — 既に中立。変更なし
- zh: `▶ 下一话「{name}」（再按一次）` — 「按」（押す）を中立表現へ改める
- en: `▶ Next: "{name}" (press again)` — `press` を中立表現へ改める

**理由**: 同じ文言をトラックパッドやタッチのスワイプ（D10）でも使う。「押す」を含む表現はスワイプに対して不自然。l10n キーはアプリ内部の識別子であり、改名にユーザー影響はない。

### D8. 実装順序は TDD で 5 段階

1. **状態機械のユニットテスト → 実装**: `fake_async` で全シナリオ（2 段階・タイムアウト・確定クールダウン・向き切替・隣接なし no-op・確定時リセット）を記述し、赤を確認してから実装する。ウィジェット不要でここが最も速く回る
2. **縦書きの載せ替え**: 既存の `vertical_text_viewer_episode_nav_test.dart` / `_swipe_test.dart` / `_wheel_test.dart` を**変更せずに**緑を維持することが載せ替えの受け入れ条件。挙動不変の保証になる
3. **横書きの 2 段階化**: `horizontal_edge_episode_nav_test.dart` を 2 段階前提に書き換えて赤を確認 → 実装。`runaway cooldown` グループは削除し、状態機械側のシナリオへ移す
4. **ヒントバナー**: widget test でヒント状態時の表示・待機状態時の非表示・スクロール量不変を検証してから実装
5. **ドラッグ入力の接続**（D10）: 判定を純粋関数として先にテストし、そのあと widget test で macOS の physics 下の実挙動を検証する

### D9. 確定クールダウンは「ヒント表示から」ではなく「直前の入力から」測る

**決定**: 無視した同方向入力ごとにクールダウンを再スタートし、確定には直前の境界入力から 300ms 以上の切れ目を要求する。タイムアウト（4 秒）はヒント表示時点から測ったまま変えない。

**理由**: 当初はヒント表示時点を起点にしていた。これはキーリピートのように「離せば止まる」バーストは覆えるが、慣性入力は覆えない。macOS のトラックパッドや自由回転ホイールは指を離した後も約 1 秒イベントを送り続けるため、最初のイベントでヒントが出て、300ms を過ぎたイベントが確定してしまう。末尾での 1 回のフリックで話が飛ぶことになり、2 段階確認を入れた目的そのものが崩れる。

この穴は共有ユニット化以前から縦書きにも存在していた。共有化したことで 1 箇所の修正で両モードが塞がる。

**代替案**: タッチ・トラックパッドだけ別のクールダウン値を持たせる案。入力ソースごとの分岐が状態機械に入り込み、D2 の「入力ソースに依存しない」方針と衝突する。却下。

**トレードオフ**: 縦書きの観測挙動が 1 点だけ変わる（慣性フリックで確定しなくなる）。安全側への変更であり、既存の縦書きテストは変更なしで通る。

### D10. ドラッグ由来の境界入力はスクロール通知から検出し、physics 差を純粋関数に閉じ込める

**決定**: `lib/features/text_viewer/data/scroll_boundary_detection.dart` に `resolveScrollBoundary` を置き、`ScrollUpdateNotification` と `OverscrollNotification` を「次話へ／前話へ／ヒント解除／無視」の 4 値に分類する。`text_content_renderer.dart` はその結果を共有ユニットへ渡すだけにする。

**理由**:

- トラックパッドのスワイプは `PointerPanZoomUpdateEvent`、タッチは `PointerMoveEvent` で届く。どちらも `PointerSignalEvent` ではないため `onPointerSignal`（マウスホイールの経路）には**構造上到達しない**。スクロール通知が全入力の合流点であり、ここで見るのが唯一の統一手段
- 境界の押し込みをどの通知が報告するかは physics によって違う。bouncing（macOS / iOS）は `applyBoundaryConditions` が 0 を返して超過位置を許容するため `ScrollUpdateNotification` の `pixels` が範囲外になり、`OverscrollNotification` は飛ばない。clamping（Windows / Linux）は逆に位置が境界へ固定され、超過量が `OverscrollNotification` で届く。両方を扱わないとプラットフォームのどちらかで動かない
- 指を離した後の慣性の戻りは境界の外側に留まったまま進むが、これは読者の要求ではないのでヒントを表示してはならない。`dragDetails != null` で区別する
- 境界にちょうど留まっている状態を「ファイル内移動」と扱うとヒントが消える。戻りの最終フレームが `pixels == maxScrollExtent` になるため、押し込みで出したヒントを自分で消してしまう。解除は範囲内に**厳密に**収まっているときだけに限る

これらは推測ではなく、macOS の physics 下でトラックパッド操作の通知列を実測して確かめた。

**代替案**: `Listener` に `onPointerPanZoomStart/Update/End` を足して pan 量を自前で積算する案。タッチ（`PointerMoveEvent`）は別途拾う必要があり、スクロール位置との突き合わせも自前になる。スクロール通知なら入力ソースを問わず 1 経路で済む。却下。

## Risks / Trade-offs

- **縦書きの載せ替えで微妙な挙動差が入る** → 既存の縦書きテスト 3 ファイルを一切変更せずに緑を維持することを受け入れ条件にする。変更が必要になった時点で、それは挙動が変わった証拠として扱う。D9 は縦書きの挙動を意図的に 1 点変えるが、これも既存テストを変更せずに通る（安全側への変更のため）

- **確定クールダウン中の入力がタイムアウトを延長してしまう実装ミス** → 仕様に「無視された入力によってタイムアウトタイマーがリセットされてはならない」を明記済み。`fake_async` で「クールダウン中に入力を連打し、初回ヒントから 4 秒でタイムアウトすること」を検証する

- **キーリピートや慣性を押し続けた場合の連続遷移** → D9 により、確定には入力の切れ目が要る。押しっぱなしでは確定に達しないため、当初懸念していた「300ms ごとに 1 話ずつ進む」性質は解消している

- **ヒントバナーが `TtsControlsBar` と重なる** → 両者は別の `Stack` にあり互いの幅を知らないため、余白での回避はできない。ヒントを `IgnorePointer` で包んでボタンの操作性を守り、文言は `TextOverflow.ellipsis` で切る。TTS バーはモデル未設定時は描画されないため、実際に衝突する場面は限定的。残る視覚的な重なりは許容する

- **横書きユーザーの操作が 1 回増える** → 意図的な挙動変更。リリースノートに記載する。境界に達していない通常のスクロールには一切影響しない

## Migration Plan

コードのみの変更で、永続データ・設定・DB スキーマへの影響はない。

- ロールアウト: 通常のリリースに含める。リリースノートに「横書きモードの話送りが縦書きと同じ 2 段階確認になった」旨を記載する
- ロールバック: 変更をリバートすれば旧挙動に戻る。永続化された状態がないためデータ移行は不要

## Open Questions

なし。D1〜D8 は実装前に、D9 / D10 はレビューと実機確認を経て確定している。
