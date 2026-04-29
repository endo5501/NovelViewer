## Context

TTS モジュールは NovelViewer リポジトリで最も churn の高い領域 (75/169 commits in 6 months)。3 つの controller が同等のパターン (engine 設定 / モデル ロード+合成 / 1 セグメント再生) を独自に持っており、新機能追加や微調整のたびに「3 箇所同時に修正する/しない」「片方だけ直してドリフト」が発生し続けている。

`TECH_DEBT_AUDIT.md` の "Things that look bad but are actually fine" セクションに、本 sprint で触る箇所が複数挙がっている:

- `setFilePath` を `playerStateStream.listen` より先に呼ぶ理由 (BehaviorSubject の replay 回避)
- `unawaited(_audioPlayer.play().catchError(...))` の意図 (完了は `playerStateStream` 経由)
- `pause` not `stop` の鉄則 (`stop` は platform player を破壊し WASAPI バッファの音声を切る)
- 500ms drain (最終セグメント後のバッファ流し)
- `TextSegmenter` 3 重インスタンス化 (現状 stateless で問題なし)
- `ProviderScope.containerOf(context)` の long-lived container 参照

これらは「正しい」ロジックなので、Phase C は**変更ではなく集約**。1 箇所の `SegmentPlayer` に全コメントを集める。

Sprint 2 の DTO 層 (`TtsEpisode`, `TtsSegment`, `TtsRefWavResolver`) はマージ済み前提。Sprint 0/1 のロガーは `TtsSession` の abort パスや `SegmentPlayer` の cleanup ログで利用する。

## Goals / Non-Goals

**Goals:**
- `TtsEngineConfig` で engine 種別を型で表現し、コピペ if/else を全廃
- `TtsSession` でモデル ロード+合成+abort を 1 箇所に
- `SegmentPlayer` で WASAPI 関連の load-bearing ロジックを集約 (コメント含む)
- `TextSegmenter` を Riverpod 経由で singleton 化
- `deleteEpisode` の vacuum を遅延実行に切り替え、UI スパイクを排除

**Non-Goals:**
- 新規 TTS engine の追加 (基盤だけ用意)
- Native FFI / Isolate 境界の変更
- TTS audio storage スキーマの変更
- god-file 解体 (Sprint 4/5)
- `TtsRefWavResolver` の sealed 化 (Sprint 2 で static helper として確定済み、本 Sprint で進化させない)
- WASAPI 周りの仕様変更 (現状動作を保持)

## Decisions

### Decision 1: `TtsEngineConfig` は `lib/features/tts/domain/` 配下の sealed class

```dart
// lib/features/tts/domain/tts_engine_config.dart
sealed class TtsEngineConfig {
  const TtsEngineConfig({required this.modelDir, required this.sampleRate});
  final String modelDir;
  final int sampleRate;

  static TtsEngineConfig resolveFromRef(WidgetRef ref, TtsEngineType type) {
    return switch (type) {
      TtsEngineType.qwen3 => Qwen3EngineConfig(
            modelDir: ref.read(qwen3ModelDirProvider),
            sampleRate: ref.read(qwen3SampleRateProvider),
            languageId: ref.read(ttsLanguageProvider).languageId,
            refWavPath: ref.read(refWavPathProvider),
          ),
      TtsEngineType.piper => PiperEngineConfig(
            modelDir: ref.read(piperModelDirProvider),
            sampleRate: ref.read(piperSampleRateProvider),
            dicDir: ref.read(piperDicDirProvider),
            lengthScale: ref.read(piperLengthScaleProvider),
            noiseScale: ref.read(piperNoiseScaleProvider),
            noiseW: ref.read(piperNoiseWProvider),
          ),
    };
  }
}

class Qwen3EngineConfig extends TtsEngineConfig {
  const Qwen3EngineConfig({
    required super.modelDir,
    required super.sampleRate,
    required this.languageId,
    this.refWavPath,
  });
  final int languageId;
  final String? refWavPath;
}

class PiperEngineConfig extends TtsEngineConfig {
  const PiperEngineConfig({
    required super.modelDir,
    required super.sampleRate,
    required this.dicDir,
    required this.lengthScale,
    required this.noiseScale,
    required this.noiseW,
  });
  final String dicDir;
  final double lengthScale, noiseScale, noiseW;
}
```

`TtsIsolate.loadModel` には sealed の switch でメッセージへ詰め替え。

**Alternatives considered:**
- *enum + Map で柔らかく*: 型安全性が下がり、F040 の動機 (専用パラメータの取り違え防止) が損なわれる
- *`freezed` で生成*: 値オブジェクト統一感が増すが、現状他 domain 層が手書きのため Sprint 3 のスコープでは手書き継続

### Decision 2: `resolveFromRef` は WidgetRef 依存。テスタビリティのため平行 API も用意

`WidgetRef` 直結は widget 層に依存する。`TtsSession` のような data 層から使えるよう、`Reader = T Function<T>(ProviderListenable<T>)` を取る `TtsEngineConfig.resolveFromReader(Reader read, TtsEngineType type)` も提供する。`resolveFromRef` は内部で `resolveFromReader(ref.read, type)` に委譲する形。

### Decision 3: `TtsSession` は `lib/features/tts/data/` 配下、injection 可能

```dart
class TtsSession {
  TtsSession({required TtsIsolate isolate, Logger? logger})
      : _isolate = isolate, _log = logger ?? Logger('tts.session');

  final TtsIsolate _isolate;
  final Logger _log;
  StreamSubscription? _subscription;
  bool _modelLoaded = false;
  Completer<TtsSynthesisResult>? _activeSynthesisCompleter;

  Future<void> ensureModelLoaded(TtsEngineConfig config) async { ... }
  Future<TtsSynthesisResult> synthesize({required String text, ...}) async { ... }
  void abort() { ... }
  Future<void> dispose() async { ... }
}
```

- `ensureModelLoaded` は同一設定での再ロードは no-op (内部で config の identity か等価性で判定)
- `synthesize` は `_activeSynthesisCompleter` を立て、abort 時に完了させる
- `abort` は `_isolate.abort()` を呼び `_activeSynthesisCompleter?.completeError(AbortedException())` で controller 側を解放
- `dispose` で `_subscription` を解放、isolate を kill

両 controller (`TtsStreamingController`, `TtsEditController`) は constructor で `TtsSession` を受け取る (default では新規生成、テストでは inject)。

**Alternatives considered:**
- *`TtsSession` を Riverpod provider で配る*: scope 管理が複雑になる。1 controller = 1 session のオーナーシップが明確な方が読みやすい
- *abstract class + concrete*: 抽象化のメリットが薄い。具象 1 つで開始

### Decision 4: `SegmentPlayer` は `dispose` を持つが `play` 自体は冪等にしない

```dart
class SegmentPlayer {
  SegmentPlayer({required AudioPlayer player, this.bufferDrainDelay = const Duration(milliseconds: 500)});
  final AudioPlayer _player;
  final Duration bufferDrainDelay;

  /// 1 セグメント再生。完了で resolve、再生中エラーで reject。
  /// 完了後 [pause] を呼ぶ ([stop] は呼ばない)。
  Future<void> playSegment(String filePath, {required bool isLast}) async { ... }

  /// 中断 (ユーザー stop)。pending drain を skip。
  Future<void> stop() async { ... }

  Future<void> dispose() async { ... }
}
```

- `playSegment` は `setFilePath` → `playerStateStream.listen` → `unawaited(_player.play().catchError(...))` → `processingState == completed` 待機 → drain delay (`isLast` だけ) → `pause`
- WASAPI 関連の load-bearing コメントは `playSegment` 内に集約
- `stop` は user-initiated 中断: drain を skip して直接停止
- `bufferDrainDelay` はコンストラクタ引数で `Duration.zero` を許容 (既存テスト互換)

**Alternatives considered:**
- *`Stream<SegmentPlayerEvent>` を返す API*: より宣言的だが、3 controller の利用パターンが命令的なので命令的 API のまま統一
- *`drain` だけ別メソッドに分離*: `isLast` フラグの方が呼び出し側の意図が明確 ("最終セグメントなら drain")

### Decision 5: WASAPI 関連コメントは `SegmentPlayer.playSegment` の冒頭に集約

`TECH_DEBT_AUDIT.md` の "Things that look bad" 4 項目を 1 つの doc コメントに集約:

```dart
/// Plays a single segment via the underlying [AudioPlayer].
///
/// **Order is load-bearing:**
/// 1. `setFilePath()` is called BEFORE `playerStateStream.listen()`. The stream
///    is a `BehaviorSubject` that replays the last `completed` state — listening
///    first would immediately fire and skip the next segment.
/// 2. `play()` is fire-and-forget (`unawaited` + `catchError`). Completion is
///    signalled by `playerStateStream`, not by awaiting `play()`.
/// 3. After `completed`, we call `pause()` rather than `stop()`. `stop()`
///    destroys the platform player (MediaKitPlayer) and kills any audio still
///    in the WASAPI output buffer.
/// 4. On the LAST segment we wait [bufferDrainDelay] before pause to let the
///    OS drain its output buffer (otherwise the tail of the audio is lost).
```

これにより `text_viewer_panel.dart` などにあった同様コメントが消える。

### Decision 6: `TextSegmenter` provider は単純な `Provider`

```dart
final textSegmenterProvider = Provider<TextSegmenter>((ref) => const TextSegmenter());
```

stateless なので `keepAlive` 不要。3 controller が `ref.read(textSegmenterProvider)` で取得する。将来パラメータ化されたら provider 経由で注入が用意になる (これが F027 の主旨)。

### Decision 7: F021 vacuum は `AppLifecycleState.detached` フックで実行

```dart
// lib/features/tts/providers/vacuum_lifecycle_provider.dart
final vacuumLifecycleProvider = Provider<VacuumLifecycle>((ref) {
  final lifecycle = VacuumLifecycle(ref: ref);
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});

class VacuumLifecycle with WidgetsBindingObserver {
  /// Tracks novel folders touched in this session; vacuums each on `detached`.
  void markDirty(String folderPath) { ... }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) _vacuumAll();
  }
}
```

- `TtsAudioRepository.deleteEpisode` は終わりに `lifecycle.markDirty(folderPath)` を呼ぶ (実行はしない)
- アプリ終了時に dirty なフォルダの DB に対してまとめて `incremental_vacuum(0)` を実行
- `reclaimSpace()` は public API として残す。手動「容量を解放」ボタン (将来) で呼べる

**Alternatives considered:**
- *タイマーベースの debounce*: 「終了時 vacuum」と被るうえ、UX 観点で「アプリ動作中に唐突に I/O スパイク」を生む
- *background isolate で実行*: 過剰。終了フックで十分

### Decision 8: テストでは `WidgetsBinding.instance` の lifecycle イベントを fake する

`VacuumLifecycle` のテストは `vacuumLifecycle.didChangeAppLifecycleState(AppLifecycleState.detached)` を直接呼ぶ。実 `WidgetsBinding` 連携は `setUp` で `WidgetsFlutterBinding.ensureInitialized()` だけで OK。

### Decision 9: `TtsStoredPlayerController` の既存 `bufferDrainDelay` パラメータは `SegmentPlayer` 側へ移譲

```dart
class TtsStoredPlayerController {
  TtsStoredPlayerController({
    Duration bufferDrainDelay = const Duration(milliseconds: 500),
    SegmentPlayer? segmentPlayer,
  }) : _segmentPlayer = segmentPlayer ?? SegmentPlayer(
            player: AudioPlayer(), bufferDrainDelay: bufferDrainDelay);
}
```

既存テスト (`TtsStoredPlayerController(bufferDrainDelay: Duration.zero)`) は変更なしで動作する。新コードは `segmentPlayer:` で直接 inject も可能。

### Decision 10: Phase A/B/C の commit 順は A → B → C → D

依存関係:
- B (`TtsSession`) は A (`TtsEngineConfig`) を引数に取る → A 先行
- C (`SegmentPlayer`) は A/B と独立 → 後でも前でも可。並行実装してもよいが衝突を避けるため最後
- D (`TextSegmenter` provider, vacuum hook) は単独で進められる

PR は 1 つにまとめる (Sprint 3 = 1 change = 1 PR)。commit 粒度で Phase 別に分けてレビュアビリティを確保。

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| Phase C で WASAPI 関連の load-bearing 動作を壊す | 全 4 ポイント (setFilePath 順、unawaited play、pause not stop、drain) を `SegmentPlayer` テストで明示的に固定。既存 `tts_streaming_controller_test.dart` 等のシナリオを `SegmentPlayer` テストに移植 |
| `TtsEngineConfig` 統合で provider 数読み取りが増えてビルド回数が増える | `resolveFromRef` 内では `ref.read` (watch ではない) のみ使用。rebuild トリガーには影響しない |
| `TtsSession` の abort 中に新規 `synthesize` が来た場合の race | `TtsSession` 内部で abort 進行中フラグを持ち、abort 完了まで新規 synthesize を queue or reject。テストで race 条件を網羅 |
| 既存 `TtsStreamingController` / `TtsEditController` のテスト fixture が大量に書き換わる | controller のコンストラクタが `TtsSession` を取れるよう変更。既存テストは「テスト用の TtsSession を inject」する形に書き換え。fixture ヘルパで定型化 |
| F021 で vacuum が終了時に走らないケース (クラッシュ等) | クラッシュ時はそもそも整合性が取れていないので vacuum スキップで問題なし。次回起動時に integrity check が走る (sqflite デフォルト) |
| `TextSegmenter` を singleton にすることで将来の状態を持つ実装へのマイグレーションが必要 | 現状 stateless なので即時影響なし。将来 stateful 化したら family + folderPath 等で再設計 |
| Phase A の `TtsStreamingController.start()` シグネチャ変更が監査の F046 (`ProviderScope.containerOf`) と関連する | 本 Sprint では F046 (long-lived container 参照) は触らない。シグネチャ変更は config の集約のみで、container 渡しは現状維持 |

## Migration Plan

### Phase A — TtsEngineConfig
1. `TtsEngineConfig` sealed + 2 サブクラス + テスト
2. `resolveFromRef` / `resolveFromReader` 実装 + テスト
3. `TtsStreamingController.start()` シグネチャを `TtsEngineConfig` 引数に変更 (compile error が一時的に出る)
4. 3 call site (`text_viewer_panel`, `tts_edit_dialog` x 2) を `TtsEngineConfig.resolveFromRef` 利用に書き換え
5. `TtsEditController` 合成 API も `TtsEngineConfig` 引数に変更

### Phase B — TtsSession
6. `TtsSession` クラス + テスト (ensureModelLoaded / synthesize / abort / dispose)
7. `TtsStreamingController` を `TtsSession` 注入に書き換え。既存テストの fixture 更新
8. `TtsEditController` を `TtsSession` 注入に書き換え

### Phase C — SegmentPlayer
9. `SegmentPlayer` クラス + テスト (setFilePath 順、unawaited play、pause-not-stop、drain delay、stop で skip)
10. `TtsStreamingController` の `:355-388` を `SegmentPlayer` 利用に置換
11. `TtsStoredPlayerController` の `:60-121` を `SegmentPlayer` 利用に置換 (`bufferDrainDelay` パススルー)
12. `TtsEditController.playSegment:381-411` を `SegmentPlayer` 利用に置換

### Phase D — Cleanup
13. `textSegmenterProvider` 追加、3 controller を `ref.read` に置換
14. `VacuumLifecycle` + provider + テスト
15. `TtsAudioRepository.deleteEpisode` から `reclaimSpace()` 呼び出しを削除、`markDirty` を呼ぶように
16. `main.dart` で `WidgetsBinding.instance.addObserver(vacuumLifecycle)` を初期化シーケンスに追加

**Rollback**: Phase C のみ revert は controller 側のテスト失敗を引き起こしうるが、Phase A/B はそれぞれ独立に revert 可能。

## Open Questions

1. **`AbortedException` の型**: 既存コードに `TtsAbortException` 等があれば再利用、無ければ新規作成 (`lib/features/tts/domain/tts_abort_exception.dart`)。実装時に確認
2. **手動 `reclaimSpace` UI**: F021 の長期方針として、設定画面に "Reclaim disk space" ボタンを追加するかは将来 Sprint で別途検討 (本 Sprint スコープ外)
3. **`TtsSession` の abort 中の `ensureModelLoaded`**: abort 完了前に新規 ensureModelLoaded が来た場合のセマンティクス。現状は「abort 完了を待って続行」を採用予定 — 実装中に既存挙動と擦り合わせる
