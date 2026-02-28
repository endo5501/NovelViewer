## Context

TTS連続再生では、セグメントごとにWAVファイルを一時ファイルに書き出し、`just_audio`（→ `just_audio_media_kit` → `media_kit` → mpv）で順次再生する。セグメント完了の検知は `playerStateStream` の `completed` 状態を監視して行う。

現在のオーディオスタックの階層:

```
TtsStreamingController / TtsEditController
    ↓ setFilePath / play / stop / pause
JustAudioPlayer (tts_adapters.dart)
    ↓ AudioPlayer API
just_audio 0.9.46
    ↓ platform interface
just_audio_media_kit 2.1.0 (MediaKitPlayer)
    ↓ Player API
media_kit 1.2.6
    ↓ mpv C API (NativePlayer)
mpv (libmpv)
    ↓ audio output
WASAPI (Windows) / CoreAudio (macOS)
```

### 問題の原因チェーン

1. mpvがファイル末尾をデコード完了 → `eof-reached` プロパティが `true` に変化
2. media_kitが `eof-reached` を検知 → `completed` ストリームイベントを発火
3. just_audio_media_kitが `completed` を受信 → `processingState = completed` に更新
4. just_audioが `playerStateStream` で `completed` を配信
5. **この時点でWASAPIの出力バッファにはまだ数百msの音声データが残っている**
6. 次のセグメントの `setFilePath` → `_player.open()` がWASAPIバッファを破棄

### just_audioの重要な内部動作

- **`play()` ガード**: `if (playing) return;`（line 939） — `playing`が`true`の間、`play()`はno-op
- **`stop()`の破壊性**: `_setPlatformActive(false)` を呼び、MediaKitPlayerインスタンスを完全に破棄・再生成する
- **`pause()`の軽量性**: `_playing = false` を設定し `_platform.pause()` を呼ぶだけ。プラットフォームは維持される
- **`completed`後の状態**: `playing`は`true`のまま。`stop()`か`pause()`を呼ぶまでリセットされない

## Goals / Non-Goals

**Goals:**

- セグメント間の音声途切れを解消し、全文が最後まで聞こえるようにする
- `stop()`によるプラットフォーム破壊を避け、`pause()`で`playing`フラグをリセットする
- バッファドレイン遅延をテストで注入可能にし、テストの実行速度を維持する
- 暫定デバッグログを除去してプロダクション品質にする

**Non-Goals:**

- just_audio/media_kit/mpvの上流バグ修正やパッチ
- WASAPI固有のバッファサイズ検出による動的遅延調整
- macOSでの検証（macOSでは別のオーディオバックエンドが使われるため、同じ問題が発生するかは未確認）
- `TtsStoredPlayerController`の修正（コールバック方式で連続再生の問題構造が異なる）

## Decisions

### Decision 1: `stop()` → `pause()` への置換

**選択**: セグメント完了後に`pause()`を呼び、`stop()`は使用しない

**理由**: `stop()`は`just_audio`内部で`_setPlatformActive(false)`を呼び、MediaKitPlayerを破棄する。これにより:
- WASAPIの出力バッファが強制破棄され、残りの音声が失われる
- プラットフォームの再生成コストがかかる

`pause()`は`_playing = false`を設定するだけでプラットフォームを維持する。`completed`後の`pause()`は事実上no-op（既にデコード完了しているため）だが、`_playing`フラグのリセットには有効。

**代替案**:
- `stop()` + 遅延: 遅延後にstop()を呼ぶ方法。しかしstop()自体がバッファを破棄するため、遅延が十分でなければ同じ問題が発生する
- 何もしない: `_playing`が`true`のままだと次の`play()`がno-opになり、`setFilePath`の`open(play: _playing)`による暗黙的な自動再生に依存する。動作はするが制御フローが不透明

### Decision 2: バッファドレイン遅延のコンストラクタ注入

**選択**: `TtsStreamingController`のコンストラクタに`Duration bufferDrainDelay`パラメータを追加（デフォルト値あり）

**理由**: テストでは実際のオーディオ出力がないため遅延は不要。`Duration.zero`を注入することでテスト実行速度を維持できる。プロダクションコードではデフォルト値が使用される。

**代替案**:
- `@visibleForTesting`フラグ: テスト専用のフラグでスキップする方法。コンストラクタ注入の方がDIパターンとして自然
- グローバル定数: テストで変更できない

### Decision 3: バッファドレイン遅延のデフォルト値

**選択**: 800ms（暫定。実機テストで調整する）

**理由**: 500msではユーザーから「ちょっと切れている感がある」とフィードバックあり。WASAPIの一般的なバッファサイズ（10-30ms）を考慮すると500msで十分なはずだが、mpv→WASAPIのパイプライン全体の遅延を含めると余裕が必要。1000msを超えるとセグメント間の沈黙が不自然になるため、800msを出発点とする。

**代替案**:
- 500ms: 現在値。ほぼ改善されるが僅かに途切れが残る
- 1000ms: 確実だがセグメント間の間が不自然になる可能性
- 動的検出: WASAPI APIで残バッファを監視する方法。実装コストが高く、mpv/media_kitの抽象化を突破する必要がある

### Decision 4: TtsEditControllerでも`pause()`を使用

**選択**: `playSegment()`末尾の`stop()`を`pause()`に変更

**理由**: `playAll()`は`playSegment()`をループで呼ぶため、`stop()`によるプラットフォーム破壊が同じ問題を引き起こす。`pause()`に変更することで`playAll()`のセグメント間遷移が正常化する。単体の`playSegment()`呼び出し時も、`pause()`はプラットフォームを維持するだけで副作用がない。

## Risks / Trade-offs

- **固定遅延の限界**: WASAPIのバッファサイズはオーディオデバイスにより異なる。800msが全環境で十分とは限らない → 遅延値をユーザー設定として公開することも将来的に検討可能
- **セグメント間の無音時間増加**: バッファドレイン遅延はセグメント間に無音を挿入する → 自然な朗読ではセンテンス間のポーズとして許容範囲内
- **`pause()`のプラットフォーム依存動作**: `completed`後の`pause()`がmpv/WASAPIにどう影響するかは完全には文書化されていない → 実機テストで確認。問題があればnull-opラッパーで対処
- **just_audioバージョン依存**: `play()`ガードや`stop()`の内部実装はjust_audioの非公開APIに依存 → バージョンアップ時に動作確認が必要
