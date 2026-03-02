## Context

`TtsEditController.generateSegment()` は2つの目的で `refWavPath` パラメータを使用している：
1. TTS合成エンジンに渡すフルパス（合成用）
2. 新規セグメントをDBに挿入する際の `ref_wav_path` 値（メタデータ保存用）

これらは本来異なる値であるべきだが、現在は同じパラメータが両方に使われている。合成用には `/Users/.../voices/voice.wav` のようなフルパスが渡されるが、DBに保存すべきは `null`（設定値）、`''`（なし）、`voice.wav`（ファイル名）のいずれかである。

## Goals / Non-Goals

**Goals:**
- `generateSegment()` が新規セグメントをDBに挿入する際、セグメントのメタデータ値（`segment.refWavPath`）を保存するようにする
- 編集画面を閉じて再度開いた際、リファレンス音声の表示が正しく維持されるようにする

**Non-Goals:**
- 既存のDBデータの修正（再生成またはリセットで自然に修正される）
- `TtsStreamingController` の変更（そちらは `refWavPath` を渡していないため問題なし）

## Decisions

### `insertSegment()` に渡す値を `segment.refWavPath` に変更

`generateSegment()` 内の `insertSegment()` 呼び出しで、パラメータの `refWavPath`（合成用フルパス）ではなく `segment.refWavPath`（メタデータ）を使用する。

**理由:** `segment.refWavPath` は UI のドロップダウンと1:1対応しており（`null` = "設定値"、`''` = "なし"、ファイル名 = 特定ファイル）、再読み込み時に正しく表示される。合成用パスは一時的な解決値であり、永続化すべきではない。

**代替案:** `generateSegment()` に保存用の別パラメータを追加する方法もあるが、`segment` オブジェクト自体が正しいメタデータを持っているため不要。

## Risks / Trade-offs

- [Risk] 既にフルパスが保存された既存データ → リセットまたは再生成で修正される。自動マイグレーションは不要と判断。
