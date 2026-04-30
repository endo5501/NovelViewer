## Context

`text_viewer_panel.dart` の現状 (900 LOC) を機能別に俯瞰すると、`State` クラスに以下が混在している:

```
┌─ TextViewerPanelState (900 LOC, 7 concerns)
│
├── 1. Content rendering
│     - text 読み込み (file → string)
│     - horizontal mode → SelectableText.rich
│     - vertical mode → 自前 Wrap pagination
│     - ruby tag parser → TextSegment
│     - 検索ハイライト 適用
│     - TTS ハイライト 適用
│
├── 2. TTS streaming controller lifetime
│     - _streamingController = TtsStreamingController(container)  ← F046 anti-pattern
│     - dispose() で stop+release
│     - start/pause/resume/stop ボタンの onPressed
│
├── 3. Scroll / line tracking
│     - ScrollController, scroll offset → 行番号への変換
│     - search match 行へ scrollTo
│     - vertical では page 切替
│
├── 4. Audio state polling
│     - _checkAudioState() (Sprint 2 で FutureProvider 化された前提)
│     - _lastCheckedFileKey ceremony (Sprint 2 完了時には消滅予定)
│
├── 5. Dialog launching
│     - rename dialog
│     - edit dialog
│     - delete confirmation
│
├── 6. MP3 export
│     - ボタン onPressed → export 実行
│     - 進捗 SnackBar
│
└── 7. Clipboard
      - 選択テキストのコピー
```

加えて高次のクロスカット:
- **File change detection (F029)**: `build` 内で `_lastViewedFilePath = selectedFile?.path` を更新し `addPostFrameCallback` で `_loadContent` を呼ぶ。これは **build 中の state 変更**で副作用順序が脆い
- **Inline state-machine switches**: `TtsAudioState × TtsPlaybackState × isWaiting × engineType` の組み合わせを 3 ヶ所の switch で扱う。一貫性なく拡張されやすい

**前提**: 本 sprint 開始時点で Sprint 2 (`type-tts-dtos-and-cache-databases`) の `ttsAudioStateProvider`、`TtsEpisode`/`TtsSegment` DTO、Riverpod-managed DB family が land 済み。Sprint 3 (`refactor-tts-internals`) の `TtsEngineConfig`、`TtsSession`、`SegmentPlayer` も land 済み。これらに依存して内部構造を整える。

## Goals / Non-Goals

**Goals:**
- 900 LOC のパネルを 3 widget (controls bar / content renderer / shell) に分割
- 状態マシン (TtsAudioState × TtsPlaybackState) の inline switch を `TtsControlsBar` 内 1 箇所に集約
- Phase A の panel-level 統合テストでリグレッションネットを構築 (F011 解消)
- `ProviderScope.containerOf(context)` (F046) を `Reader` 関数で置き換え
- Per-widget の `_segmentsCache` (F051) を Riverpod provider 化、コンテンツハッシュキャッシュ
- `build` 内の state 変更 (F029) を `ref.listen` ベースに修正
- Sprint 5 完了時に F001-F058 の処理状況を確定

**Non-Goals:**
- 新規 TTS 機能 / テキストレンダリング機能
- horizontal/vertical mode の統合 (監査 Open Q10、別 sprint)
- TTS audio export pipeline 自体の変更 (ボタン位置のみ移動)
- `TtsEditController` / `TtsStoredPlayerController` 公開 API の変更 (F046 は streaming 側だけ)
- Riverpod 化された file-change 検出を使った深い navigation 改造

## Decisions

### Decision 1: 3 widget への分割境界

```
TextViewerPanel (≤ 200 LOC, ConsumerStatefulWidget)
├── レイアウト組み立て (Column / Stack)
├── file-change 検出 (initState で ref.listen)
└── ダイアログ起動 (rename / delete confirmation)
   ※ TTS edit dialog は TtsControlsBar 内から起動
   ※ MP3 export ボタンも TtsControlsBar 内
   ※ クリップボードは TextContentRenderer 内 (selection と同居)

   ├─ TtsControlsBar (ConsumerStatefulWidget)
   │  ├── streaming controller のライフタイム所有
   │  ├── stored playback controller のライフタイム所有
   │  ├── TtsAudioState × TtsPlaybackState の switch 1 箇所
   │  ├── play / pause / stop / edit / export ボタン
   │  └── waiting state のローディングインジケータ
   │
   └─ TextContentRenderer (ConsumerStatefulWidget)
      ├── horizontal/vertical mode dispatch
      ├── ScrollController / scroll → line 変換
      ├── ruby parser 呼び出し (キャッシュは provider 経由)
      ├── 検索ハイライト適用
      ├── TTS ハイライト購読 (Riverpod 経由)
      └── auto page turn
```

監査の "7 concerns" のうち:
- (1) Content rendering → `TextContentRenderer`
- (2) TTS streaming controller lifetime → `TtsControlsBar`
- (3) Scroll/line tracking → `TextContentRenderer`
- (4) Audio state polling → 既に Sprint 2 で `ttsAudioStateProvider` に移行済 (両 widget が `ref.watch`)
- (5) Dialog launching → 一部はシェルへ (rename/delete)、TTS edit は `TtsControlsBar`
- (6) MP3 export → `TtsControlsBar`
- (7) Clipboard → `TextContentRenderer` (selection 隣接)

**Alternatives considered:**
- *4 widget にして `DialogLauncher` を独立化*: dialog 起動はシェルからの 2-3 箇所だけで、別 widget にするほどの責務はない
- *`TtsControlsBar` を Riverpod state notifier 化して widget を持たない*: ボタン UI は依然必要。state notifier + widget の 2 ファイル化は得るものが少ない

### Decision 2: Phase A 統合テストは fake driver で状態を直接駆動

実 `AudioPlayer` / `TtsIsolate` は使わず、テスト用の fake で `TtsAudioState` / `TtsPlaybackState` の Riverpod 状態を直接書き換える形:

```dart
test('Qwen3 walk: none → generating → ready → playing → paused → stopped', (tester) async {
  await tester.pumpWidget(makeApp(
    overrides: [
      ttsEngineTypeProvider.overrideWith(() => Qwen3Notifier()),
      ttsAudioStateProvider.overrideWith((ref, _) async => TtsAudioState.none),
      ttsPlaybackStateProvider.overrideWith(...),
    ],
  ));
  expect(find.byKey(Keys.ttsPlayButton), findsOneWidget);

  // generating
  container.read(ttsAudioStateProvider).overrideWith(...);
  await tester.pump();
  expect(find.byKey(Keys.ttsLoadingIndicator), findsOneWidget);

  // ... 各 state へ遷移
});
```

Sprint 3 の `bufferDrainDelay: Duration.zero` 経路をテストヘルパで利用。

**Alternatives considered:**
- *e2e で実 isolate を起動*: 起動コストが大きく、テスト時間が膨らむ。状態マシンのカバレッジには fake で十分

### Decision 3: F046 — `Reader` 関数型による DI

```dart
typedef Reader = T Function<T>(ProviderListenable<T>);

class TtsStreamingController {
  TtsStreamingController({required Reader read, ...}) : _read = read;
  final Reader _read;

  Future<void> start({...}) async {
    final session = _read(ttsSessionProvider);  // 旧: container.read(...)
    ...
  }
}
```

call site (`TtsControlsBar`):
```dart
class _TtsControlsBarState extends ConsumerState<TtsControlsBar> {
  late final TtsStreamingController _controller = TtsStreamingController(
    read: ref.read,  // ref.read を関数として渡す。WidgetRef のライフタイムを越えても OK
  );
}
```

`ref.read` は内部的に `ProviderContainer.read` を呼ぶため、ウィジェットが dispose されても controller 内の参照経由で動作する。`ProviderScope.containerOf(context)` の解放/再構築リスクが消える。

**Alternatives considered:**
- *`WidgetRef` をそのまま渡す*: `WidgetRef` のライフタイムが widget と紐づくため、controller のほうが長寿命の場合に dangling 参照が発生する
- *`ProviderContainer` をそのまま渡す (現状)*: F046 の原因そのもの

### Decision 4: F051 — ParsedSegmentsCache を Provider 化

```dart
// lib/features/text_viewer/data/parsed_segments_cache.dart
class ParsedSegmentsCache {
  final Map<String, List<TextSegment>> _byHash = {};
  List<TextSegment> getOrParse(String content, String hash, RubyTextParser parser) =>
      _byHash.putIfAbsent(hash, () => parser.parse(content));
}

// lib/features/text_viewer/data/parsed_segments_cache_provider.dart
final parsedSegmentsCacheProvider = Provider<ParsedSegmentsCache>((ref) => ParsedSegmentsCache());
```

`TextContentRenderer` の build:
```dart
final cache = ref.watch(parsedSegmentsCacheProvider);
final segments = cache.getOrParse(content, contentHash, parser);
```

ハッシュ計算は `TtsEpisode.textHash` と同じユーティリティ (`computeContentHash(String)` などの shared helper) を使い回す。

**Alternatives considered:**
- *`AutoDispose.family<List<TextSegment>, String>` でハッシュキー*: build 内でハッシュ計算 → family lookup のセットを毎回行うコスト。手動 Map のほうが軽い
- *`InheritedWidget` で per-route キャッシュ*: Riverpod がもう存在するため、追加機構を増やさない

### Decision 5: F029 — ref.listen による file change 検出

```dart
class _TextViewerPanelState extends ConsumerState<TextViewerPanel> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(selectedFileProvider, (prev, next) {
      if (prev?.path != next?.path) _loadContent(next?.path);
    }, fireImmediately: true);
  }
}
```

`build` 内のステート変更を排除。`fireImmediately: true` で初期表示にも対応。

### Decision 6: TtsControlsBar の状態マシン集約

```dart
class TtsControlsBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(ttsAudioStateProvider(currentFilePath));
    final playback = ref.watch(ttsPlaybackStateProvider);
    final engine = ref.watch(ttsEngineTypeProvider);

    return audio.when(
      data: (audioState) => _buildButtons(audioState, playback, engine),
      loading: () => const _LoadingIndicator(),
      error: (e, _) => _ErrorWidget(e),
    );
  }

  Widget _buildButtons(TtsAudioState audio, TtsPlaybackState playback, TtsEngineType engine) {
    return switch ((audio, playback)) {
      (TtsAudioState.none, _) => _PlayButton(...),
      (TtsAudioState.completed, TtsPlaybackState.stopped) => _Row(playButton, deleteButton, editButton, exportButton),
      (_, TtsPlaybackState.playing) => _Row(pauseButton, stopButton),
      (_, TtsPlaybackState.paused) => _Row(playButton, stopButton),
      (_, TtsPlaybackState.waiting) => _Row(loadingIndicator, pauseButton, stopButton),
      ...
    };
  }
}
```

state machine が 1 箇所の sealed switch で表現される (Dart 3 の records + sealed switch)。テストで網羅 assert が容易。

### Decision 7: shell の責務最小化

`TextViewerPanel` シェルは:
- レイアウト (`Column(children: [TextContentRenderer(...), TtsControlsBar(...)])`)
- file-change 検出 (`ref.listen` 起動)
- パネル全体に関わる KeyEventHandler (Cmd+F 等は `TextContentRenderer` 内)
- rename / delete dialog 起動 (file_browser 由来のコンテキストメニューから本来呼ばれるが、panel 内の何らかのトリガから来る可能性は維持)

200 LOC 以内を目標。

### Decision 8: テストの分散方針

Phase A で `text_viewer_panel_test.dart` に統合テストを集中させる (現行 900 LOC 実装に対する green ベースライン)。Phase B で widget が分かれた後:
- 統合テストはそのまま `text_viewer_panel_test.dart` に残す (シェル + 子 widget の整合性を保つ)
- 各 widget の unit テストを `widgets/tts_controls_bar_test.dart`、`widgets/text_content_renderer_test.dart` に追加
- 統合テストは状態遷移と panel-shell-level 動作 (file change → 子 rebuild) をカバー

### Decision 9: F046 の実装変更は Sprint 3 にも触れる

Sprint 3 で `TtsStreamingController` を `TtsSession` を持つ形に変えたが、F046 の対応 (Reader 化) は Sprint 5 でやる。Sprint 3 完了時点では `ProviderContainer` 受け取りのままでも構わず、Sprint 5 での修正で `Reader` 化する。**両 sprint の commit 順を A→B→C→Sprint 4→Sprint 5 と直列に進める前提**でこの分割は安全。

### Decision 10: Sprint 5 完了 = F001-F058 final pass

tasks.md の最終セクションに「F001-F058 各項目の処理状況」を表で記載する:

- ✅ Resolved (本計画で実装/修正)
- ⏭️ Deferred (将来 sprint へ持ち越し、理由付き)
- 🚫 Won't fix (現状維持の判断、理由付き)

各項目を Sprint 5 完了時に再確認し、漏れが無いことを確認。

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| 7 concerns を 3 widget に再分配する際の状態購読漏れ | Phase A の統合テストで状態遷移網羅。Phase B 中も Phase A テストを green に維持することを各 commit で確認 |
| `Reader` 関数の inject で controller のテストが書きにくくなる | テスト用 `Reader` を提供する fixture を `test_utils/` に追加。実プロダクションは `ref.read` を渡すだけ |
| `ParsedSegmentsCache` がメモリリーク (ハッシュ → segments を永久保持) | `Provider` の lifetime はアプリ全体だが、segments 自体は episode 単位で頻度が低い。LRU エビクション (例: 最大 50 entries) を `ParsedSegmentsCache` 内に組む |
| 統合テストが長い実行時間 | `bufferDrainDelay: Duration.zero` で drain 待機を消す。fake driver で isolate 起動コストを回避 |
| F029 の `ref.listenManual` の lifetime 管理ミス | Riverpod 公式の `ref.listenManual` は ConsumerStatefulWidget の dispose 時に自動解放 (Riverpod 3.x)。手動 `cancel` 不要 |
| Phase A テストが `WidgetsBinding.instance` の `addObserver` (Sprint 3 vacuum) と干渉 | テスト helper で `VacuumLifecycle` を no-op に override |
| 状態マシン switch の網羅性が Dart の sealed exhaustiveness では効かない (TtsAudioState/TtsPlaybackState は enum) | `default:` ケースで explicit assert を入れる、または records pattern にする |
| F046 の Reader 化で既存テストが大量に書き換わる | テストヘルパ `makeStreamingController({Reader? read})` を提供し、既存テストは1行修正で済むようにする |

## Migration Plan

### Phase A (テストベースライン)
1. `text_viewer_panel_test.dart` を作成、現行 900 LOC 実装に対して状態遷移を assert
2. テストが green であることを確認、commit

### Phase B (widget 分割)
3. `TtsControlsBar` を抽出、ボタン配置を inline switch ベースで実装。state machine 集約
4. 既存 panel から関連コードを削除し `TtsControlsBar()` 呼び出しに置換、Phase A テスト green を維持
5. `TextContentRenderer` を抽出、horizontal/vertical/ruby/ハイライト/scroll を移動
6. シェル化 (`TextViewerPanel` を ≤ 200 LOC に縮小)
7. F029: `ref.listenManual` で file change 検出を `initState` に移動

### Phase C (細かい改善)
8. F046: `TtsStreamingController` のコンストラクタを `Reader` 受け取りに変更。call site (`TtsControlsBar`) と既存テスト fixture を更新
9. F051: `ParsedSegmentsCache` を Riverpod provider 化 + LRU エビクション
10. ハッシュ計算ユーティリティを `lib/shared/util/content_hash.dart` 等に切り出し、`TtsEpisode.textHash` 計算と共有

### 最終 (F001-F058 closure)
11. tasks.md 最終セクションで F001-F058 を Resolved / Deferred / Won't fix に分類
12. ローカル統合動作確認 (panel 全機能を一巡)

**Rollback**: Phase B は widget 単位で revert 可能。Phase A は単独 commit で残せる。Phase C の F046 のみ revert すると `TtsStreamingController` の API 互換が崩れるが、修正は1ファイル

## Open Questions

1. **`ParsedSegmentsCache` の LRU 上限値**: 50 が妥当か。メモリ使用量と再パース頻度のトレードオフは実装中に観測して調整
2. **`TtsControlsBar` の sealed exhaustiveness**: `TtsAudioState` と `TtsPlaybackState` を sealed class にするとコンパイラチェックが効くが、本 sprint では enum のまま `default:` で fallback する案を採用。将来 sealed 化は別 sprint
3. **F046 の Reader 型**: `T Function<T>(ProviderListenable<T>)` を `typedef Reader` で公開するか、Riverpod 公式の `Ref.read` 形を直接使うか。実装中に Riverpod 3.x のベストプラクティスを確認
