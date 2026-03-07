## Context

just_audioの`completed`イベントはデコーダーがファイル末尾に到達した時点で発火する。しかしオーディオデバイス（Windows WASAPIなど）のバッファにはまだ未再生サンプルが残っている場合がある。

現在、中間セグメント間ではこの問題に対して`_bufferDrainDelay`（デフォルト500ms）の待機を行っているが、最終セグメントでは「次のセグメントがないから不要」としてスキップしている。その結果、最終セグメントの`completed`直後に`dispose()`が呼ばれ、バッファ内の音声が切り捨てられる。

影響を受けるコントローラは2つ：
- `TtsStreamingController` - completedイベント後に即dispose
- `TtsStoredPlayerController` - completedイベントのリスナーコールバック内で即stop→dispose

## Goals / Non-Goals

**Goals:**
- 最終セグメントの音声が最後まで再生されるようにする
- 両コントローラで一貫した修正を適用する
- ユーザーがstopした場合は即座に停止する（ドレイン待機をしない）

**Non-Goals:**
- バッファドレイン遅延時間の最適化（現在の500msで十分）
- エディタコントローラの修正（dispose()を呼ばないため問題なし）

## Decisions

### D1: 最終セグメントでもバッファドレイン遅延を適用する

**TtsStreamingController**: `hasNextSegment`条件を外し、すべてのセグメントでバッファドレイン遅延を待つ。ただし最終セグメントでは`pause()`は不要（次のplay()がないため）。

**TtsStoredPlayerController**: `_onSegmentCompleted()`で最終セグメント判定前にバッファドレイン遅延を挿入する。現在は同期的にstop()を呼んでいるが、非同期でドレインを待ってからstop()する。

### D2: TtsStoredPlayerControllerにbufferDrainDelayパラメータを追加

TtsStreamingControllerと同様に、コンストラクタで`bufferDrainDelay`を受け取る。テスト時はDuration.zeroを渡すことで即座に完了させる。

## Risks / Trade-offs

- [最終セグメント後に500msの無音時間が追加される] → ユーザー体験への影響は軽微。音声が途切れるよりはるかに良い
- [stopとドレイン待機の競合] → `_stopped`フラグチェックで対応。ユーザーがstopした場合はドレイン待機をスキップして即停止
