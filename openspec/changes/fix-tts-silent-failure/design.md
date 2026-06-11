## Context

`TtsStreamingController.start()` は、セグメントを逐次合成しながら再生し、終了時に episode のステータスを更新する。現状の終了分岐は `_stopped` の真偽だけで `partial` / `completed` を決めており（`tts_streaming_controller.dart:127-133`）、ループ内の失敗は単に `break` するだけで `_stopped` は `false` のままになる（`:205-207` モデルロード失敗、`:225` 合成失敗）。結果、1セグメントも生成できなくても `completed` としてマークされ、`_stateFromEpisode`（`tts_audio_state_provider.dart:15-17`）が `completed`/`partial` を共に `ready` に写すため、音声ゼロのepisodeに再生/Exportボタンが出る。

その手前の `TtsSession`（`tts_session.dart`）では、`ModelLoadedResponse` / `SynthesisResultResponse` が運ぶ `error` 文字列を読まずに `success`(bool) / `null` だけを見て捨てている（`:52-56`, `:98-106`）。フィールドでの失敗が診断不能になっている。

制約:
- TDD厳守（プロジェクトMUSTルール）。`TtsStreamingController` は `session` 注入可、`TtsSession` は `isolate` 注入可で、Fakeが既存テストに揃っている。
- 既存の停止挙動（`_stopped → partial`、停止時はクリーンアップ非対称）は回帰させない。

## Goals / Non-Goals

**Goals:**
- 合成/モデルロードの失敗を、ユーザ停止と区別して検出する。
- 失敗時に音声ゼロのepisodeを `ready` に見せない（生成ボタンに戻す）。
- 失敗をUIに一過性スナックバーで通知する。
- nativeエラー文字列を診断ログ（WARNING）に残す。

**Non-Goals:**
- `TtsEpisodeStatus` enum への `error` 値追加、DBスキーマ/マイグレーション変更（行わない）。
- nativeエラー文字列のUI露出（汎用文言に留める）。
- `TtsSession` を結果型（`Result<T, E>`）へリファクタする伝搬対応（F112の「理想」案。今回は最小のログのみ）。
- `synthesize()` / `ensureModelLoaded()` のタイムアウト・isolate死活監視（F144。別change）。

## Decisions

### 決定1: `_stopped` と `failed` の二段判定で失敗を検出する

ループ内の失敗 `break` 2箇所を、停止と失敗で分岐する。

```
!await _session.ensureModelLoaded(config) → if (!_stopped) failed = true; break;
result == null                            → if (!_stopped) failed = true; break;
```

**根拠（重要）**: `stop()` は `_stopped = true` を立ててから `_session.abort()` を呼ぶ（`tts_streaming_controller.dart:302 → 305`）。`abort()` は in-flight な model-load completer を `false`、synthesis completer を `null` で完了させる（`tts_session.dart:118-130`）。したがって、abort由来で `false`/`null` が返ってきた時点では `_stopped` は**必ず既に true**。よって `!_stopped` を満たす `false`/`null` は本物のエンジン失敗だけであり、判別は確実。

**代替案**: 「ループが `segments.length` まで到達したか」で完了/中断を判定する案。だが startOffset やセグメント数0の境界で複雑化し、停止と失敗をさらに区別できないため却下。明示的な `failed` フラグが最も読みやすい。

### 決定2: 失敗時のステータスは「音声量」で決める（enumを増やさない）

終了分岐:

```
status =
  _stopped                      → partial   // 既存挙動
  failed && hasAnyStoredAudio   → partial   // 途中まで再生可
  failed && !hasAnyStoredAudio  → (episode削除)
  else                          → completed
```

`hasAnyStoredAudio` は `_repository.getSegments(episodeId)` の各行に `audioData != null` が1つでもあるかで判定する。音声ゼロの失敗は `_repository.deleteEpisode(episodeId)` し、`_stateFromEpisode` がレコード無し→`none` に写すことで生成ボタンに戻る。

**代替案A（`TtsEpisodeStatus.error` 新設）**: 永続的なエラー表示は再発系（モデルパス誤設定）に親切だが、enumとUIマッピング（`TtsAudioState`）に1ケース追加が必要で、単発失敗には「選ぶ度に⚠が残る」しつこさがある。explore合意でこちらは不採用。
**代替案B（採用）**: 「statusは常に音声量を反映する」不変条件を保ち、enum/DB/`_stateFromEpisode` を一切触らない。エラーは一過性スナックバーで通知。波及最小。

### 決定3: `start()` は `TtsStartOutcome` を返し、UIはそれを見てスナックバーを出す

```dart
enum TtsStartOutcome { completed, stopped, failed }
```

`_startStreaming`（`tts_controls_bar.dart`）は `start()` の戻り値が `failed` の時のみ `ScaffoldMessenger` で汎用ローカライズ文言を表示する。`stopped` ではスナックバーを出さない。失敗時に音声が途中まで残るケースもDBステータスは `partial` だが outcome は `failed` を返す（途中失敗もユーザに通知する）。そのため outcome に `partial` 値は持たせない。

**代替案**: (a) `start()` 完了後に episode ステータスを再読込してUI判定 → 余分なDB読み込み＋削除済みケースの判別が曖昧。(b) `start()` が例外を投げる → 失敗は「処理済みの結果」であり例外的でなく、既存 `finally` のクリーンアップ前提も崩す。よって戻り値で返す案を採用（テスト容易性も高い）。

### 決定4: F112はログのみ（最小）

`TtsSession.ensureModelLoaded` の listener で `ModelLoadedResponse.error != null` なら `_log.warning(error)`。`synthesize` の listener で、既存の `null` 完了の直前に `SynthesisResultResponse.error != null` なら `_log.warning(error)`。`TtsSession` は既に `Logger`（注入可）を保持しているため新規配線は不要。F101のUI文言とは疎結合（詳細はログ、UIは汎用）。

## Risks / Trade-offs

- [失敗が一過性通知のみで永続痕跡が残らない] → nativeエラー詳細はWARNINGログ（AppLoggerのファイルシンク）に残るため、フィールド診断は可能。永続UI表示は意図的に不採用（決定2）。
- [`synthesize`/`ensureModelLoaded` が応答せずハングするとステータス更新自体に到達しない（F144）] → 本changeのスコープ外。F101の修正は「応答が返る」前提で正しく、F144は独立に対処する旨をtasksの注記に残す。
- [`hasAnyStoredAudio` のための `getSegments` 追加読み込み] → 失敗時のみの1クエリで、ホットパスではないため無視できる。
- [`failed && hasAnyStoredAudio → partial` が停止由来の partial と同じ見た目になる] → どちらも「途中まで再生可」で挙動として妥当。失敗の事実はスナックバーで別途通知される。

## Migration Plan

スキーマ・データ移行なし。既存の `tts_episodes` 行には影響しない。ロールバックはコード差し戻しのみで完結（永続状態を変更しないため安全）。
