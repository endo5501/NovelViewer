## Context

`TtsStoredPlayerController.stop()` は現在以下の順序で処理を実行する：

```
1. _stopped = true
2. await _playerSubscription?.cancel()
3. await _audioPlayer.stop()
4. await _audioPlayer.dispose()
5. ttsPlaybackStateProvider → stopped     ← テストはここで完了を検知
6. ttsHighlightRangeProvider → null
7. await _cleanupFiles()                  ← この時点でtearDownと競合する
```

`_onSegmentCompleted()` は `void` メソッドであり、`stop()` を await せずに呼ぶため、`stop()` の Future は追跡されない。テスト側は Provider の状態変化で完了を検知するが、`_cleanupFiles()` はその後に実行されるため、`tearDown` のディレクトリ削除と競合する。

## Goals / Non-Goals

**Goals:**
- テスト `plays all segments in order` を100%安定させる
- `_cleanupFiles()` をファイルシステムのレースコンディションに対して堅牢にする

**Non-Goals:**
- `_onSegmentCompleted` の async チェーン全体のリファクタリング（スコープ外）
- テスト側の `tearDown` の変更

## Decisions

### 1. `stop()` 内の処理順序を変更

`_cleanupFiles()` を Provider 状態更新の**前**に移動する。

**変更後の順序：**
```
1. _stopped = true
2. await _playerSubscription?.cancel()
3. await _audioPlayer.stop()
4. await _audioPlayer.dispose()
5. await _cleanupFiles()                  ← 先にファイル削除
6. ttsPlaybackStateProvider → stopped     ← テストが検知する時点では削除済み
7. ttsHighlightRangeProvider → null
```

**理由:** テストは `ttsPlaybackStateProvider == stopped` を条件に `_pumpUntil` で完了を待つ。ファイル削除を状態更新の前に実行することで、テストが完了を検知した時点ではファイル操作が終わっていることを保証できる。本番コードの動作にも影響はない（ファイル削除とUI状態更新の順序はユーザーに知覚されない）。

### 2. `_cleanupFiles()` に防御的 try-catch を追加

個別のファイル削除を try-catch で囲み、`PathNotFoundException` を無視する。

**理由:** 処理順序の修正（Decision 1）で現在のテスト問題は解決するが、ファイルシステム操作には本質的にTOCTOU（Time-of-check to time-of-use）レースが存在する。`file.exists()` が `true` を返した後でも、外部プロセスや OS によってファイルが削除される可能性がある。防御的なエラーハンドリングにより、このクラスのエラーを根本的に排除できる。

simplify レビューにより `exists()` チェックを除去し、直接 `delete()` + try-catch とした。`exists()` と `delete()` の間にTOCTOU レースが存在するため、`exists()` チェックは防御にならず冗長である。

## Risks / Trade-offs

- **`_cleanupFiles` のエラー抑制が本当のバグを隠す可能性** → `PathNotFoundException` のみを無視し、他の `FileSystemException` はそのまま throw する。これにより、権限エラーなどの真の問題は検出される。
