## Why

英語のTTS再生時、文章が文字数（200文字ちょうど）で機械的に分割され、単語の途中（例: "scales｜with usage"、"pr｜ototype"）で切れてしまう。原因は `TextSegmenter` が全角の文末記号（`。！？`）と全角読点（`、`）しか認識せず、英語の `.` `,` `!` `?` やスペース区切りを扱わないため。多言語（なろう/カクヨムにも混在する英文や、英語小説）の読み上げ品質が著しく損なわれている。

## What Changes

- `TextSegmenter` の文分割に**半角の文末記号**（`.` `!` `?`）を追加する。誤分割（小数点 `3.14`、略語など）を避けるため、半角文末記号は**直後が空白・文末・閉じ括弧の場合のみ**文末とみなす。
- 文末直後の**半角閉じ括弧/引用符**（`"` `)`）も全角同様に第1セグメント側へ含める。
- 200文字超の長文分割（`_findSplitPosition`）に**半角読点 `,`** を追加する。さらに読点が無い場合は**直近の空白（単語境界）で分割**し、空白も無い場合のみ従来どおり200文字で強制分割する。これにより英文が単語の途中で切れなくなる。
- 既存の日本語分割挙動（全角記号・読点・改行・閉じ括弧・ルビ処理・オフセット追跡）は完全に維持する（後方互換）。

## Capabilities

### New Capabilities

なし（新規capabilityの追加はない）

### Modified Capabilities

- `tts-playback`: 「Text segmentation for TTS」要件に半角文末記号（`.` `!` `?`、直後が空白/文末/閉じ括弧のときのみ）と半角閉じ括弧（`"` `)`）の分割ルールを追加。
- `tts-text-length-guard`: 「Text length-based sentence splitting」要件に半角読点 `,` での分割と、読点不在時の空白（単語境界）分割フォールバックを追加。

## Impact

- コード: `lib/features/tts/data/text_segmenter.dart`（`_sentenceEnders` / `_closingBrackets` / `_splitTextBySentence` / `_findSplitPosition`）
- テスト: `test/features/tts/data/text_segmenter_test.dart`
- 影響範囲: TTSストリーミング再生・蓄積再生・編集画面・音声エクスポートなど、`TextSegmenter` を経由する全TTS経路（出力セグメント境界が変わる）。日本語のみのテキストでは挙動不変。
