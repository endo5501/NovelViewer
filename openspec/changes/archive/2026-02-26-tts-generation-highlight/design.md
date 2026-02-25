## Context

バッチTTS音声生成は `TtsGenerationController` が文ごとに順次合成を行い、`onProgress(current, total)` コールバックで進捗を通知する。UIは `ttsGenerationProgressProvider` 経由でプログレスバーと「N/M文」テキストを表示する。

一方、再生時には `ttsHighlightRangeProvider` にテキスト範囲を設定することで、横書きモードでは自動スクロール（`_scrollToTtsHighlight`）、縦書きモードではページ自動送り（`_pendingTtsOffset` → `_findPageForOffset` → `_goToPage`）が動作する。このハイライト＋ページ追従の仕組みは再生専用だが、生成時にも同じプロバイダを更新すればそのまま動作する。

## Goals / Non-Goals

**Goals:**
- 生成中に処理対象の文をハイライト表示し、ユーザーに「今どこを処理しているか」を視覚的に伝える
- 処理対象の文が別ページにある場合、自動的にページを切り替える
- 既存の再生時ハイライト機構を再利用し、最小限の変更で実現する

**Non-Goals:**
- 生成中のハイライトアニメーション（再生時と異なり、文単位の静的ハイライトで十分）
- 生成中のユーザー手動ページ操作との競合制御（生成中はハイライト追従を優先）
- 生成速度の改善

## Decisions

### 1. `onProgress` とは別に `onSegmentStart` コールバックを追加

**選択**: 既存の `onProgress` を変更せず、新しい `onSegmentStart(int textOffset, int textLength)` コールバックを `TtsGenerationController` に追加する。

**理由**: `onProgress` は生成完了後に呼ばれるが、ハイライトは生成開始前に更新したい。タイミングが異なるため、別コールバックとして分離する方が責務が明確。`onProgress` のシグネチャ変更も不要。

**代替案**: `onProgress` のシグネチャを拡張して `(int current, int total, int textOffset, int textLength)` とする方法。シンプルだが、進捗通知とハイライト通知のタイミングが合わない（開始時 vs 完了時）ため不採用。

### 2. 生成完了・キャンセル時にハイライトをクリア

**選択**: 生成完了後およびキャンセル時に `ttsHighlightRangeProvider.set(null)` を呼ぶ。

**理由**: 生成完了後は `TtsAudioState.ready` に遷移し再生ボタンが表示される。この状態でハイライトが残っていると、再生開始時のハイライトと混乱する。

## Risks / Trade-offs

- **ハイライトが長時間同じ文に留まる**: 1文の合成に数秒〜十数秒かかるため、ハイライトが静止した状態が続く。ただしプログレスバーが同時に表示されているため、処理が進行中であることは認識できる → 許容範囲
- **生成時と再生時のハイライトプロバイダ共有**: 同じ `ttsHighlightRangeProvider` を使うため、生成中に再生を開始すると競合する可能性がある → 生成中は再生ボタンが非表示のため実際には発生しない
