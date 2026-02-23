## Context

`TtsPlaybackController`はテキストを文単位に分割し、Isolate上のqwen3-tts.cppネイティブエンジンで合成→WAV書き出し→`just_audio`で再生、というパイプラインを実行する。再生中に次の文をprefetchする設計だが、2つのバグが存在する。

**現在の動作フロー（バグあり）:**

1. `_writeAndPlay()`が`await _audioPlayer.play()`で再生完了までブロック
2. `play()`完了時、`playerStateStream`が`completed`をemit → `_onPlaybackCompleted()`が発火
3. `_onPlaybackCompleted()`が`_synthesizeCurrentSegment()`で次セグメントの合成を要求
4. `play()`のawaitが解決 → `_startPrefetch()`が実行、`_isPrefetching = true`を設定
5. Isolateが次セグメントの合成を返却 → `_isPrefetching`がtrueのため、再生されずprefetchとして格納
6. 再生中の音声がないため`completed`イベントが二度と発火せず、パイプラインが停止

**クラッシュの原因:**

`TtsIsolate.dispose()`が`Isolate.kill(priority: Isolate.immediate)`で即座にIsolateを強制終了する。ネイティブFFI呼び出し中（合成処理中）にIsolateが破壊されると、ネイティブメモリが不正な状態で残り、プロセス終了時にクラッシュする。

## Goals / Non-Goals

**Goals:**

- 2文目以降が正常に連続再生されるようにする
- prefetch機構が設計通りに動作するようにする（現在の文再生中に次の文を合成）
- TTS Isolateがgracefulにシャットダウンし、ネイティブリソースを安全に解放する
- アプリ終了時のクラッシュを解消する

**Non-Goals:**

- TTSエンジン自体（qwen3-tts.cpp）の修正
- 新機能の追加（一時停止/再開、速度調整など）
- パフォーマンス最適化（合成速度の向上など）

## Decisions

### Decision 1: `play()`のawaitを廃止し、fire-and-forgetで再生を開始する

**選択肢A（採用）:** `_audioPlayer.play()`をawaitせず、`unawaited()`で呼び出す。再生完了は既存の`_playerSubscription`（`playerStateStream`のリスナー）で検知しており、awaitは不要。`_startPrefetch()`を`play()`の直後（awaitなし）で即座に呼び出す。

**選択肢B（不採用）:** `play()`のawait後に`_startPrefetch`を呼ばず、`_onPlaybackCompleted`内でprefetchロジックも統合する。→ prefetchの効果がなくなり、文間の空白時間が増える。

**理由:** `_onPlaybackCompleted`は既に`playerStateStream`経由で動作しているため、`play()`をawaitする理由がない。fire-and-forgetにすることでprefetchが再生開始直後に始まり、設計通りのパイプラインになる。

### Decision 2: Isolateのgraceful shutdownを実装する

**選択肢A（採用）:** `dispose()`で`DisposeMessage`を送信後、Isolateがメッセージを処理して自発的に終了するのを待つ。タイムアウト（2秒）を設け、タイムアウト後にのみ`Isolate.kill()`で強制終了する。Isolate側では`DisposeMessage`処理時にネイティブエンジンの`dispose()`を呼んだ後、`receivePort.close()`でIsolateを自然終了させる。

**選択肢B（不採用）:** `Isolate.kill()`を維持し、Dart側でFFI呼び出しの完了を待つ仕組みを追加。→ IsolateのFFI呼び出し状態をDart側から正確に把握するのは困難。

**理由:** Isolate内部でネイティブリソースの解放順序を制御できるため、安全で確実。タイムアウトがあるため、万が一Isolateがハングしても永久待ちにならない。

### Decision 3: Isolate終了の確認にExitイベントを使用

`Isolate.addOnExitListener()`を使い、Isolateが実際に終了したことを確認する。`dispose()`は`DisposeMessage`送信→Exit待ち→タイムアウトという流れの`Future<void>`を返すように変更する。

## Risks / Trade-offs

- **[Risk] `play()`のfire-and-forgetでエラーが捕捉されない** → `play()`のFutureにcatchErrorを付けてエラー時は`_handleError()`を呼ぶ
- **[Risk] Isolate graceful shutdownのタイムアウトが短すぎる/長すぎる** → 2秒を初期値とし、実測で調整。合成処理は通常数秒かかるが、`DisposeMessage`はキューに入るため既存の合成完了後に処理される
- **[Risk] `_responseController.close()`後にストリームイベントが到着** → `dispose()`内で`_isolateSubscription?.cancel()`を先に呼び、その後controllerを閉じる順序を維持
