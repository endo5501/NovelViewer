## Context

TTS編集画面では、セグメントごとにリファレンス音声ファイルを選択できる。個別生成ボタンではUI層（`_resolveRefWavPath()`）がファイル名をフルパスに解決してからコントローラに渡すため正常に動作する。一方、全生成（`generateAllUngenerated()`）ではセグメントの `refWavPath`（ファイル名のみ）がそのままC++エンジンに渡され、`fopen()` が失敗する。

現在のパス解決フロー:
- 個別生成: Dialog → `_resolveRefWavPath()` → `voiceService.resolveVoiceFilePath()` → フルパス → Controller
- 全生成: Dialog → `globalRefWavPath`（フルパス）のみ → Controller（セグメント個別パスは未解決）

## Goals / Non-Goals

**Goals:**
- 全生成時にセグメント個別のリファレンス音声パスをフルパスに解決する
- コントローラが `VoiceReferenceService` に直接依存しない設計を維持する

**Non-Goals:**
- DBに保存するパス形式の変更（ファイル名のみで保存する現行方式を維持）
- 個別生成のフローの変更

## Decisions

### コールバック関数による依存性注入

`generateAllUngenerated()` に `String? Function(String)? resolveRefWavPath` パラメータを追加する。

**理由**: コントローラが `VoiceReferenceService` を直接参照する必要がなく、テスタビリティが保たれる。個別生成で既に確立されているUI層でのパス解決パターンとも一致する。

**代替案**:
- VoiceReferenceServiceをコントローラに注入 → コントローラの責務が増え、既存の設計方針に反する
- Dialog側で全セグメントのパスを事前解決してMapで渡す → オーバーエンジニアリング

### switch式の修正

```dart
// Before
_ => segmentRef,
// After
_ => resolveRefWavPath?.call(segmentRef) ?? segmentRef,
```

コールバックが未提供の場合は従来通りそのまま渡す（後方互換性）。

## Risks / Trade-offs

- [リスク] `resolveRefWavPath` が `null` の場合、従来と同じバグが発生する → 呼び出し側で必ずコールバックを渡すことで軽減。既存テストでカバー。
- [トレードオフ] パス解決の責任がDialog層に残る → 意図的な設計。コントローラはパスの形式を知る必要がない。
