## Why

閲覧画面でテキストを選択して読み上げを開始しても、選択位置から再生されない。ルビ（`<ruby>`タグ）を含む小説では、選択位置より手前にあるルビタグのマークアップ長ぶん再生開始位置が後方へずれ、ずれが本文残量を超えると「そのページで生成した最後の行」から再生が始まる。ルビを含まないテキストでは現象が出ないことを実機で確認済み。

原因は再生開始位置の決定が2箇所で壊れていることにある。

1. **座標系の不一致**: `TtsControlsBar` は選択テキストを生本文（ルビHTMLタグ込み）に対して `indexOf` で探し、その結果を「生本文オフセット」として渡す。一方 `TextSegmenter` が算出しDBに保存する `text_offset` は「ルビ除去後の表示テキスト」上のオフセットである。なろうのルビは `outerHtml` のまま保存されるため（例: `<ruby>魔法<rp>《</rp><rt>まほう</rt><rp>》</rp></ruby>` は生47文字・表示2文字）、ルビ1個につき約45文字の誤差が累積する。加えて、選択範囲自体がルビを含む場合は `indexOf` が-1を返すため開始位置が失われ、先頭から再生される。
2. **DB既存行への依存**: 開始セグメントの決定に `findSegmentByOffset`（`tts_segments` テーブルへの問い合わせ）を使っているが、DB行は生成済み・編集済みのセグメントにしか存在しない。途中で生成を停止した話数（partial）で未生成の行を選ぶと、必ず「最後に生成した行」に落ちる。

この機能は2026-02-18に専用関数 `determineStartOffset`（テスト付き）として実装されたが、バッチ生成UI統合の際に関数もテストも削除され、`indexOf` 一行のインライン実装に置き換わったまま現在まで無検証で残っていた。

## What Changes

- 選択状態を「テキストのみ」から「テキスト＋表示テキスト座標のオフセット」に拡張する。`selectedTextProvider` は選択テキストと、ルビ除去後の表示テキスト上での選択開始オフセットの両方を保持する。
- 横書きモード: `SelectableText.rich` の選択オフセット（WidgetSpanを1文字として数える表示座標）を、表示テキスト座標へ変換して保存する。変換は既存の `extractSelectedText` と同じセグメント走査で行う。
- 縦書きモード: 選択開始エントリのインデックスを表示テキスト座標へ変換して保存する。逆方向の変換は `VerticalTextPage._computeTtsHighlights` に既に存在するため、これと対称な関数を用意する。
- `TtsControlsBar` の `widget.content.indexOf(selectedText)` による位置推測を廃止する。これにより、短い一般的な語を選択したときに別の箇所へ誤ヒットする問題も同時に解消される。
- `TtsStreamingController._startPlayback` の開始セグメント決定を、DB問い合わせ（`findSegmentByOffset`）から、その場で分割した `List<TextSegment>` のオフセット探索へ変更する。未生成のセグメントも開始位置になれるようにする。
- `TtsAudioRepository.findSegmentByOffset` は利用者がいなくなるため削除する。

## Capabilities

### New Capabilities
なし（既存機能の不具合修正のため、新規capabilityは追加しない）

### Modified Capabilities
- `tts-playback`: 「Playback start position」要件を、DB問い合わせベースから「表示テキスト座標の選択オフセット × その場のセグメント列」ベースへ変更する。座標系がルビ除去後の表示テキストであることを明示し、未生成セグメントからも開始できることを規定する。
- `tts-streaming-pipeline`: 「Unified streaming start」の `startOffset` の解釈を、保存済みセグメント（stored segments）からの検索ではなく、分割結果のセグメント列からの検索に変更する。
- `text-viewer`: 「Text selection」要件を拡張し、選択テキストに加えて表示テキスト座標での選択開始オフセットを追跡することを規定する。
- `vertical-text-selection`: 「Selected text extraction in vertical mode」要件を拡張し、抽出テキストと併せて表示テキスト座標のオフセットを通知することを規定する。
- `ruby-text-rendering`: 表示座標（WidgetSpan=1文字）から表示テキスト座標（ルビはbase長）への変換を提供することを規定する。
- `tts-audio-storage`: `TtsAudioRepository` の提供メソッドから `findSegmentByOffset` を削除する。

## Impact

- `lib/features/text_viewer/providers/text_viewer_providers.dart`: `selectedTextProvider` の状態型変更
- `lib/features/text_viewer/data/ruby_text_parser.dart`: 表示座標→表示テキスト座標の変換関数を追加
- `lib/features/text_viewer/data/vertical_text_layout.dart`: エントリindex→表示テキスト座標の変換関数を追加
- `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart`: 横書き `onSelectionChanged` の呼び出し変更
- `lib/features/text_viewer/presentation/vertical_text_page.dart` / `vertical_text_viewer.dart`: 縦書き選択通知のシグネチャ変更（ページ原点 `pageStartTextOffset` の加算を含む）
- `lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart`: `indexOf` による位置推測の削除
- `lib/features/tts/data/tts_streaming_controller.dart`: 開始セグメント決定ロジックの変更
- `lib/features/tts/data/tts_audio_repository.dart`: `findSegmentByOffset` の削除
- `lib/home_screen.dart`: `selectedTextProvider` を検索（Ctrl+F）で読む箇所の追従
- DBスキーマの変更なし。既存の生成済み音声データへの影響なし。
