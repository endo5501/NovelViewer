## Why

TTS読み上げ機能において、テキストハイライトの位置ズレと縦書きモードでの自動ページ遷移の不具合が発生しており、ユーザー体験を大きく損なっている。具体的には3つのバグが報告されている：(1) 読み上げが進むにつれてハイライト位置が実際の読み上げテキストからズレていく、(2) 縦書きモードで2ページ目に遷移した後すぐに1ページ目に戻ってしまう、(3) 縦書きモードで2ページ目のテキストが読み上げ対象になってもページ遷移が発生しない。

## What Changes

- テキストハイライトのオフセット計算ロジックを修正し、読み上げが進んでもハイライト位置がズレないようにする
- 縦書きモードの自動ページ遷移ロジックを修正し、TTS読み上げ中のページフリッカー（遷移後に1ページ目に戻る現象）を解消する
- 縦書きモードでTTSハイライトが次のページに移った際に確実に自動ページ遷移が行われるようにする

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-playback`: テキストハイライトのオフセット計算の正確性に関する要件を強化。TextSegmenterで生成されるオフセットとRubyテキスト処理後のオフセットの整合性を確保する
- `vertical-text-display`: 縦書きモードでのTTS自動ページ遷移の信頼性に関する要件を強化。ページ遷移後の状態管理とビルドサイクルでの再ページネーション処理の安定性を確保する

## Impact

- **影響コード**:
  - `lib/features/tts/data/text_segmenter.dart` — テキスト分割とオフセット計算
  - `lib/features/tts/data/tts_playback_controller.dart` — ハイライト範囲の設定
  - `lib/features/text_viewer/presentation/vertical_text_page.dart` — 縦書きハイライト計算（`_computeTtsHighlights`）
  - `lib/features/text_viewer/presentation/vertical_text_viewer.dart` — 自動ページ遷移ロジック（`_pendingTtsOffset`、`_goToPage`、`_findPageForOffset`）
  - `lib/features/text_viewer/presentation/ruby_text_builder.dart` — 水平表示ハイライト計算（`_applyTtsHighlight`）
- **依存関係**: なし（既存機能の修正のみ）
- **破壊的変更**: なし
