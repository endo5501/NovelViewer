## Why

バッチTTS音声生成中、進捗は「N/M文」のテキストとプログレスバーのみで表示されており、どの文を処理中か視覚的に分からない。生成は1文あたり数秒かかるため、待ち時間中にどこを処理しているか本文上でハイライト表示し、ページも自動追従させることで、生成中の体験を改善する。

## What Changes

- バッチ音声生成中に、現在処理中の文をテキストビューア上でハイライト表示する
- 生成対象の文が別ページにある場合、自動的にページを切り替えて追従する
- ハイライト更新は生成開始時（合成前）に行い、「今この文を処理中」というフィードバックを提供する
- 生成完了またはキャンセル時にハイライトをクリアする

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `tts-batch-generation`: 生成中の現在処理セグメントのテキスト位置情報をUIに通知し、既存のTTSハイライト機構を使って本文上にハイライト表示とページ自動追従を行う要件を追加

## Impact

- **変更対象コード**: `TtsGenerationController`（セグメント位置通知コールバック追加）、`TextViewerPanel._startGeneration()`（ハイライトプロバイダ更新）、`TextViewerPanel._cancelGeneration()`（ハイライトクリア）
- **再利用コード**: `ttsHighlightRangeProvider`、`VerticalTextViewer`の自動ページ送り、横書きモードの`_scrollToTtsHighlight`
- **新規依存**: なし
