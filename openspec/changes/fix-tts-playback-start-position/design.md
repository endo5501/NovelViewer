## Context

閲覧画面の「選択位置から読み上げ開始」が、ルビを含む小説で機能していない。原因は再生開始位置の決定経路に、互いに異なる3つの文字位置座標系が混在していることにある。

```
座標系A: 生本文座標 (raw)
  ファイルに保存されている文字列そのもの。ルビは <ruby>…</ruby> のHTMLタグ込み。
  例: "彼は<ruby>魔法<rp>《</rp><rt>まほう</rt><rp>》</rp></ruby>を" → 51文字

座標系B: 表示テキスト座標 (plain / display-text)   ★ 正準座標系
  ルビを base に置換した後の文字列上の位置。
  例: "彼は魔法を" → 5文字
  - TextSegmenter._stripRubyTags(useRubyText:false) の結果に対して
    TextSegment.offset が計算される
  - tts_segments.text_offset に保存される値
  - ttsHighlightRangeProvider の TextRange もこの座標系
  - parseRubyText の PlainTextSegment.text + RubyTextSegment.base 連結と一致する
    （tts-playback 仕様「Ruby tag pattern matches parseRubyText pattern」で保証）

座標系C: ウィジェット表示座標 (widget-display)
  SelectableText.rich が扱うオフセット。WidgetSpan（=ルビ1個）が U+FFFC の1文字。
  例: "彼は□を" → 4文字
  - TextSelection.start / end がこの座標系
  - ruby_text_parser.dart の extractSelectedText が既にこの前提で走査している

座標系D: 縦書きエントリindex
  VerticalCharEntry のリスト上のインデックス。1エントリ = 1書記素相当。
  ルビ1個 = 1エントリ、改行 = 1エントリ（うち視覚的な折返しは原文0文字）。
```

現在の壊れた経路:

```
選択(C or D) ──▶ 文字列だけ抽出 ──▶ selectedTextProvider: String?
                                          │
                                          ▼  tts_controls_bar.dart:174-179
                             widget.content.indexOf(selectedText)
                                          │   ✗ Aの座標を得る（Bと比較すべき値）
                                          ▼  tts_streaming_controller.dart:211-219
                             repository.findSegmentByOffset(episodeId, offset)
                                              ✗ Bの text_offset と比較
                                              ✗ さらにDBに行があるセグメントしか候補にしない
```

`indexOf` は選択位置より手前のルビタグ長ぶん常に過大な値を返す（ルビ1個あたり約45文字）。誤差が本文残量を超えると最終セグメントが選ばれる。選択範囲自体にルビが含まれる場合は、選択テキストが base 展開済みでタグ込み生本文には存在しないため -1 を返し、開始位置が失われる。

## Goals / Non-Goals

**Goals:**

- 選択位置から再生を開始する機能を、ルビの有無にかかわらず正しく動作させる。
- 横書き・縦書きの両モードで同一の座標系（B）を用いて開始位置を決定する。
- 未生成（DBに行がない）セグメントを選択した場合も、その位置から生成・再生を開始できるようにする。
- 位置決定ロジックにユニットテストを付け、2026-02-18に一度失われた検証を復活させる。

**Non-Goals:**

- ルビ座標変換のための新しい共通抽象レイヤ（座標系ラッパー型など）の導入。既存の走査パターンを踏襲する。
- `TextSegmenter._splitLongSegments` が長文セグメント分割時に行っている比例配分によるオフセット近似の改善。これは200文字上限を超える段落でのみ発生する既存の制約であり、本変更のスコープ外とする。
- 選択がいつクリアされるか（FABクリック時の挙動など）の変更。現状の挙動を維持する。
- DBスキーマの変更、および既存の生成済み音声データのマイグレーション。

## Decisions

### D1. 座標系Bを正準とし、選択状態にオフセットを持たせる

`selectedTextProvider` の状態を `String?` から「選択テキスト＋座標系Bでの選択開始オフセット」を持つ不変値へ拡張する。`null` は「選択なし」を表す従来どおりの意味とする。

**理由**: `indexOf` による位置の事後推測は原理的に復元不可能な情報を推測しているため、いくら補正しても正しくならない。選択が発生した時点では正確な位置が手元にあるので、それを捨てずに持ち回るのが唯一の正しい解。副次的に、短い一般語を選択したときに文書内の最初の出現へ誤ヒットする既存バグも消える。

座標系Bを正準に選ぶのは、既に `tts_segments.text_offset` と `ttsHighlightRangeProvider` がBであり、DBに保存済みのデータと互換だからである。AやCを正準にすると既存データの意味が変わる。

**検討した代替案**:
- *案: `indexOf` の前に content からルビタグを除去する* — 1箇所の修正で済むが、座標系Cでの選択情報を捨てている点は変わらないため、同一文字列の誤ヒット問題が残る。また縦書き・横書きで別々に同じ除去処理を持つことになる。
- *案: `text_offset` を座標系Aに変更する* — DBの既存行の意味が変わり、ハイライト表示（B前提）も全面的に作り直しになる。影響範囲が桁違いに大きい。

### D2. 座標変換は既存の走査パターンと対称な関数として実装する

新しい抽象は導入せず、既存コードと同じ形の関数を各データ層に1本ずつ足す。

- 横書き（C → B）: `ruby_text_parser.dart` に追加。`extractSelectedText` が `PlainTextSegment → text.length` / `RubyTextSegment → 1` で走査しているのに対し、`RubyTextSegment → base.length` を積む同型の走査を行い、選択開始位置までの累積長を返す。
- 縦書き（D → B）: `vertical_text_layout.dart` に追加。`VerticalTextPage._computeTtsHighlights`（`vertical_text_page.dart:655-687`）が「B座標 → エントリindex」の変換を既に実装しているので、その逆向きを同じ規則で書く。すなわち視覚的な折返し改行は0文字、実改行（`lineBreakEntryIndices` に含まれる）は1文字として積む。

**理由**: この2つの走査規則は既にコードベースで実績があり、テストも通っている。新しい共通型を作ると、その型に合わせて既存の走査3箇所（`extractSelectedText`・`_computeTtsHighlights`・`_computeHighlights`）も書き換えたくなり、変更が肥大化する。

**サロゲートペアの扱い**: 縦書きエントリは `text.runes` で構築されるため1エントリが2 UTF-16コードユニットになりうるが、変換では `entry.text.length`（コードユニット数）を積むので座標系Bと整合する。これは `_computeTtsHighlights` と同じ扱いである。

### D3. 縦書きはページ原点を加算してグローバルB座標にする

`VerticalTextPage` の `_charEntries` は現在表示中のページ分のみを保持するため、変換結果はページローカルなB座標になる。`VerticalTextPage` は既に `pageStartTextOffset`（ページ先頭のグローバルB座標）を受け取っているので、これを加算してからプロバイダへ通知する。

**理由**: `_computeTtsHighlights` が `globalStart - pageOffset` でグローバル→ローカル変換をしているのと対称。原点の管理場所を1箇所（`VerticalTextPage`）に閉じ込められる。

### D4. 開始セグメントの決定をDBからその場のセグメント列へ移す

`TtsStreamingController._startPlayback` は既に `_textSegmenter.splitIntoSentences(text)` の結果（`List<TextSegment>`、offset昇順）を引数で受け取っている。開始インデックスはこのリストに対して「`offset <= startOffset` を満たす最大のindex」を求める形に変える。該当がなければ0。

これに伴い `TtsAudioRepository.findSegmentByOffset` は利用者が無くなるため削除する。

**理由**: DBの `tts_segments` 行は生成済み・編集済みのセグメントにしか存在しない疎な集合であり、開始位置の候補集合として不適切。途中停止した話数（partial）で未生成行を選ぶと必ず「最後に生成した行」に落ちる。一方 `segments` は現在の本文を分割した完全な列であり、`textHash` 一致チェックを通過している以上DB行の `segment_index` とも1対1で対応する。DBに問い合わせる必然性がない。

副次的に、開始位置決定が非同期DBアクセスから純粋関数になるためテストが容易になる。

**検討した代替案**:
- *案: `findSegmentByOffset` を残しつつ、該当なしの場合だけセグメント列にフォールバックする* — 2つの真実の源が残り、どちらが使われたかで挙動が変わる。DBが疎であること自体が問題なので、DBを見る意味がない。

### D5. 探索は線形走査とする

セグメント列は offset 昇順なので二分探索が可能だが、1話数のセグメント数はたかだか数百であり、再生開始時に一度だけ実行される処理である。可読性を優先して線形走査（または `lastIndexWhere`）とする。

## Risks / Trade-offs

- **[選択状態の型変更が広範囲に波及する]** → `selectedTextProvider` は検索（`home_screen.dart` の Ctrl+F）・辞書追加・LLM解析からも読まれている。これらは選択「テキスト」しか使わないため、新しい型からテキストを取り出すアクセサを1つ用意すれば追従は機械的な置換で済む。型変更をコンパイルエラーとして検出できるので、追従漏れは静的に潰せる。

- **[`TextSegmenter` の表示テキストと `parseRubyText` の base 連結がずれると全体が破綻する]** → 両者が同一の正規表現を使うことは `tts-playback` 仕様の「Ruby tag pattern matches parseRubyText pattern」シナリオで既に要求されており、テストも存在する。本変更はこの不変条件への依存を強めるため、当該テストが回帰検知の要になる。

- **[長文段落での開始位置が最大200文字ずれる]** → `_splitLongSegments` はルビを含む長文セグメントを分割する際、オフセットを文字数比で近似している。この誤差は本変更でも解消されない。ただし影響は同一段落内での開始セグメント選択に限られ、「ページの最後の行に飛ぶ」ような可視的な破綻は起こさない。Non-Goalsとして明示し、別途扱う。

- **[縦書きで選択後にページ送りしてから再生した場合]** → ページ送り時点で選択はクリアされる（`vertical-text-selection` の既存要件）ため、古いページ原点のオフセットが残ることはない。

- **[`findSegmentByOffset` の削除]** → 現在の利用者は `TtsStreamingController` のみであることを確認済み。削除により `tts-audio-storage` 仕様の該当記述も更新が必要になる。
