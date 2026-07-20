## Context

参照音声機能は「ユーザーが任意の音声ファイルを持ち込む」機能である。したがって WAV パーサは、規格の周辺部（EXTENSIBLE、余分なチャンク、多少の破損）に対して現実的な寛容さを持つ必要がある。現状の `wav_reader.cpp` は素直な実装で、そのどちらにも対応していない。

### 現状のパーサ構造

`third_party/audio.cpp/src/framework/audio/wav_reader.cpp` は次の流れで動く。

```
read_audio_f32(path)
  └─ ファイル全体をメモリへ読み込む
      └─ has_wav_header() → read_wav_f32(string_view)
            └─ ReadOnlyMemoryStreamBuffer に載せて istream として走査
```

`ReadOnlyMemoryStreamBuffer::seekoff` は `target > end` で `-1` を返す実装のため、EOF 越えシークが必ず失敗する。`std::ifstream` 経路なら通っていた可能性があるが、実際に使われるのはメモリ経路である。

走査ループは以下の構造で、`data` を読んだ後もファイル末尾まで回り続ける。

```cpp
while (input) {
    read chunk_id(4); chunk_size(4);
    if (fmt)  → 各フィールドを読む
    if (data) → data.resize(chunk_size); read(chunk_size)
    else      → skip_bytes(chunk_size)     // 失敗すると throw
    if (chunk_size odd) skip_bytes(1);     // 失敗すると throw
}
```

フォーマット判定は `audio_format` の素の値でのみ行われる。

### 2つの失敗の実測

| | macOS 録音 (`test.wav`) | Windows 録音 (`test_rec.wav`) |
|---|---|---|
| 生成元 | AVAudioRecorder | record_windows 2.2.2 |
| 先行チャンク | `JUNK`(28B), `FLLR`(3984B) | なし |
| `fmt` サイズ | 40 | 18 |
| `wFormatTag` | `0xFFFE` (EXTENSIBLE) | `0x0001` (PCM) |
| SubFormat GUID | あり (先頭 `0x0001` = PCM) | なし |
| `data` の宣言 | offset 4096 / 149834B（整合） | offset 46 / 155458B（**実データは offset 82**） |
| 余剰バイト | なし | 末尾 36 バイト |
| 失敗箇所 | `unsupported WAV encoding` | `failed to seek inside WAV file` |

Windows 側は `data` の読み込み自体は成功しており、その直後に余剰バイトを不正なチャンクヘッダ（`chunk_id = 01 00 00 00`, `chunk_size = 0x00020000 = 131072`）として解釈し、範囲外シークで落ちている。

### エラー文言が失われる箇所

```
audio.cpp が throw
  → qwen3_tts_get_error に格納
    → tts_engine.dart:88  TtsEngineException('Synthesis failed: $error')   ← 文言あり
      → isolate worker が SynthesisResultResponse.error に載せる           ← 文言あり
        → tts_session.dart:163  _log.warning(...) して null を返す         ← ★ここで消える
          → tts_edit_controller.dart:471  onError?.call('Synthesis failed') ← 固定文言
            → tts_edit_dialog.dart:97  表示
```

## Goals / Non-Goals

**Goals:**

- macOS / Windows の録音 WAV がいずれも参照音声として読み込めること
- 「実データは無傷なのにパーサ都合で拒否する」ケースを一般的に解消すること（今回の2ファイルへの個別対応にしない）
- 合成失敗時、ユーザーが原因を特定できる情報が UI に届くこと
- 真に非対応・真に読めないファイルは、引き続き明確に失敗すること

**Non-Goals:**

- `record_windows` が生成する WAV の破損そのものの修正（上流の不具合。別途 issue 報告）
- Windows 録音の冒頭に残る約 1.1ms のクリックの除去
- WAV の全チャンク種別への対応（`LIST`/`cue` などのメタデータ利用予定はない）
- A-law / μ-law / 8bit PCM など、今回の原因と無関係なフォーマットの追加対応

## Decisions

### D1: EXTENSIBLE は SubFormat GUID で解決し、GUID 欠損時は `bitsPerSample` で推定する

`wFormatTag == 0xFFFE` のとき、`fmt` チャンク拡張部（`cbSize` に続く `WAVEFORMATEXTENSIBLE` の残り）の SubFormat GUID 先頭 2 バイトが実フォーマットを表す。これを読んで `audio_format` を置き換え、既存の PCM16 / PCM24 / float32 分岐をそのまま再利用する。

拡張部が読み取れない場合（`fmt` サイズが不足している破損ファイル）は例外にせず、`bitsPerSample` から推定する：16/24 → PCM、32 → IEEE float。

**代替案**: EXTENSIBLE を無条件に PCM とみなす。
→ 却下。32bit float の EXTENSIBLE を PCM32 として誤読すると、無音やホワイトノイズとして出力される。GUID が読める限りは読むべき。

**代替案**: GUID 欠損時は例外にする。
→ 却下。`record_windows` の `FillWavHeader` は `wFormatTag` と `cbSize` だけをコピーして拡張部を書かない実装なので、この形の破損は現実に存在しうる。`bitsPerSample` からの推定は情報として十分で、誤読のリスクは低い。

### D2: 走査ループを「`fmt` と `data` が揃ったら best-effort」に格下げする

走査中の失敗（不正なチャンクサイズ、範囲外シーク、途中での EOF）を、次の2つの状態で区別する。

```
状態 A: fmt または data が未取得
        → 従来どおり throw（不完全なファイルは失敗させる）

状態 B: fmt と data の両方を取得済み
        → 走査を打ち切り、取得済みの結果を返す（破損は無視）
```

これは「壊れたファイルを黙って受け入れる」のではなく、「成功したパース結果を、その後に続く破損で捨てない」という線引きである。`data` の後に `LIST` などの正常なチャンクが続く場合も走査は継続し、破損に当たった時点で打ち切る。これらのチャンクの内容は現在利用していないため、情報欠落による実害はない。

**代替案**: `data` を読んだ時点で即座に `break` する。
→ 却下ではないが採用しない。実装は最も単純になるものの、「`data` の後にも `fmt` が来る」という規格上ありえない配置には対応できず、将来メタデータを読みたくなった際に手戻りになる。走査は続けるが失敗に寛容、という形の方が意図が素直。

**代替案**: 走査ループ全体を try/catch で包む。
→ 却下。状態 A と B の区別ができず、完全に壊れたファイルまで「incomplete WAV file」という曖昧なメッセージで失敗するようになり、原因究明が難しくなる。

### D3: `chunk_size` を残りバイト数でクランプする

`data` チャンクの宣言サイズがファイルの残りを超える場合、読めるだけ読んで続行する。Windows のファイルは `data` の宣言サイズと実際の残りが整合しているため今回は発動しないが、「ヘッダのサイズ欄だけが壊れている」タイプの破損に対する一般的な防御になる。ここでも、クランプ後に `data` が空であれば従来どおり `incomplete WAV file` で失敗する。

### D4: エラー文言は `TtsSession.synthesize` の戻り値ではなく、専用の経路で伝える

現在 `synthesize` は `Future<SynthesisResultResponse?>` を返し、失敗時は `null` である。`null` の代わりにエラー入りのレスポンスを返すよう変えると、既存の全呼び出し元（ストリーミングパイプライン、バッチ生成）が「`null` でなければ成功」という前提で書かれているため、破綻する。

代わりに、失敗理由を伝える手段を追加し、既存の `null` 契約は維持する。実装時に以下のいずれかを選ぶ（どちらでも要件を満たす）：

- `TtsSession` に「直近の合成失敗理由」を保持させ、呼び出し元が `null` を受けた際に参照する
- `synthesize` にエラー通知コールバックを渡す

前者の方が呼び出し元の変更が小さく、既存のコールバック引数の増加も避けられるため第一候補とする。

**代替案**: 例外を投げる。
→ 却下。`null` を返す設計は「ワーカー死亡時にハングしない」という既存の設計意図（F144 対応）と結び付いており、例外化は影響範囲が読みにくい。

### D6: 「ネイティブのエラー文字列を露出させない」という既存の制限を撤回し、両画面で「ローカライズされた見出し + 原因」を表示する

既存仕様 `tts-streaming-pipeline` の「Failure is reported to the user via a localized notification」は、`TtsControlsBar` のスナックバーについて **ネイティブのエラー文字列を露出させないこと** を明示的に要求している。

しかし現状を確認すると、この制限は目的を果たしていない。

| 画面 | 実装 | ローカライズ | 原因の提示 |
|---|---|---|---|
| ストリーミング再生 | `tts_controls_bar.dart:216` → `textViewer_ttsGenerationFailed` | されている（ja/en/zh 揃い） | なし |
| 読み上げ編集画面 | `tts_edit_controller.dart:471` → `'Synthesis failed'` 固定 | **されていない**（生の英語） | なし |

制限が守らせたかったはずの「英語の技術文字列を出さない」は、編集画面ではそもそも守られていない。両画面とも原因が分からず、片方はローカライズもされていない。**制限のコストだけを払い、便益を得られていない状態**である。

この制限の本来の意図は「ユーザー向けの文言はローカライズされているべき」であって、「技術的な詳細を一切出してはならない」ではなかったと解釈するのが妥当である。**ローカライズされた見出しと、ネイティブが返した原因文言を連結する**形であれば、本来の意図を満たしたうえで診断可能になる。

したがって、既存の「SHALL NOT expose the native engine error string」を撤回し、両画面で以下の形に統一する。

```
ローカライズされた見出し + ": " + ネイティブの原因文言（あれば）

例) 音声の生成に失敗しました: unsupported WAV encoding (need PCM16, PCM24, or float32)
    Audio generation failed: failed to seek inside WAV file
```

原因文言はネイティブ層が動的に生成する英語文字列であり、キー化できないため翻訳対象としない。原因が得られない場合は見出しのみを表示し、従来と同じ体験になる。

**代替案**: 編集画面だけ原因を出し、ストリーミング側は現状維持。
→ 却下。今回の調査で `Synthesis failed` の情報欠落が原因究明を大きく遅らせた。同じ失敗がストリーミング再生でも起きうる以上、片方だけ直す理由がない。また、編集画面のハードコード英語をローカライズする作業はどのみち必要で、両画面を同じ形に揃える方が仕様としても実装としても素直。

**代替案**: 原因文言も翻訳する。
→ 却下。ネイティブ層が任意の文字列を返すため、キーの網羅は不可能。

### D7: ストリーミング側は `TtsSession` を dispose する前に失敗理由を退避する

`TtsStreamingController.start()` は `finally` ブロックで `_session.dispose()` を呼んでから戻る。したがって呼び出し元 (`TtsControlsBar`) が `start()` の戻り値を受けた後にセッションへ問い合わせることはできない。

コントローラ側が、失敗判定を行う時点（`_PlaybackResult` を `TtsStartOutcome` に畳み込む箇所）でセッションから失敗理由を読み取り、自身のフィールドに退避する。呼び出し元はコントローラからそれを参照する。

`TtsStartOutcome` は enum であり、ここに文字列を持たせると既存の比較箇所（`outcome == TtsStartOutcome.failed` 等）がすべて壊れるため、enum は変更しない。

### D5: 回帰テストはバイト列をテストコード内で組み立てる

`test_wav_reader.cpp` に、以下を生成するヘルパを置いてテストする。

- `WAVE_FORMAT_EXTENSIBLE` + SubFormat GUID(PCM) の 40 バイト `fmt`
- `WAVE_FORMAT_EXTENSIBLE` + SubFormat GUID(IEEE float) の 40 バイト `fmt`
- `WAVE_FORMAT_EXTENSIBLE` だが拡張部が欠損した 18 バイト `fmt`（推定フォールバック）
- 先行する `JUNK` / `FLLR` チャンク
- `data` の後に不正なチャンクヘッダが続くファイル
- `data` の宣言サイズが残りバイト数を超えるファイル
- `fmt` が無い / `data` が無い → 従来どおり失敗すること

バイナリ資産を追加しないことで、テストが何を検証しているかがコード上で読める。

## Risks / Trade-offs

**[破損の許容範囲が広がり、本来検出すべき壊れたファイルを見逃す]** → 寛容化は「`fmt` と `data` の両方を取得済み」という条件下に限定する。パースが不完全なファイル、真に非対応のフォーマットは従来どおり明示的に失敗させる。テストで両方向（許容すべき / 失敗すべき）を固定する。

**[EXTENSIBLE の GUID 解釈を誤ると、無音やノイズが出力される]** → GUID の先頭 2 バイトが `0x0001` / `0x0003` のいずれでもない場合は、推定にフォールバックせず `unsupported WAV encoding` で失敗させる。テストで PCM / float 双方のケースを固定する。

**[audio.cpp は他プロジェクトからも使われる共有ライブラリであり、挙動変更の影響が本アプリに閉じない]** → 変更は「今まで例外だったものが読めるようになる」方向のみで、今まで読めていたファイルの挙動は変わらない。既存の `test_wav_reader.cpp` / `test_audio_reader.cpp` が回帰の網になる。

**[ビルド成果物の差し替え漏れ]** → `macos/Frameworks/libaudiocpp_ffi.dylib` と Windows 側 DLL は手動で再ビルド・差し替えが必要。実際の録音ファイルでの動作確認をタスクに含め、差し替え漏れを検出できるようにする。

**[Windows 録音の冒頭にクリックが残る]** → 本変更では許容する。録音の冒頭は通常無音区間であり、18 サンプルのノイズが話者埋め込みに与える影響は無視できる範囲と判断した。実際に音質劣化が観測された場合は、上流修正または先頭数ミリ秒のトリムを別変更で検討する。

**[上流 `record_windows` が将来修正され、ヘッダの形が変わる]** → パーサ側の寛容化は特定の破損パターンに依存しない一般的な処理であるため、上流が修正されても壊れない。
