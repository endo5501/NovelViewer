## ADDED Requirements

### Requirement: WAV reference audio accepts WAVE_FORMAT_EXTENSIBLE

参照音声として渡された WAV の `fmt` チャンクの `wFormatTag` が `WAVE_FORMAT_EXTENSIBLE` (`0xFFFE`) である場合、システムは `fmt` チャンク拡張部の SubFormat GUID の先頭 2 バイトを実フォーマットとして解決し、通常の PCM / IEEE float として復号 SHALL する。解決した値が `0x0001` (PCM) でも `0x0003` (IEEE float) でもない場合、システムは非対応フォーマットとして失敗 SHALL する。

`fmt` チャンクが `0xFFFE` を宣言しているにもかかわらず SubFormat GUID を含むだけの長さを持たない場合、`bitsPerSample` が 16 または 24 であれば PCM と推定して復号 SHALL する。`bitsPerSample` が 32 の場合は推定 SHALL NOT — 整数 PCM32 と IEEE float32 はレイアウトが同一で GUID でしか区別できず、誤推定は整数サンプルをノイズとして復号するため、非対応フォーマットとして失敗 SHALL する。

#### Scenario: EXTENSIBLE with PCM SubFormat
- **WHEN** `fmt` チャンクが 40 バイトで `wFormatTag = 0xFFFE`、SubFormat GUID の先頭 2 バイトが `0x0001`、`bitsPerSample = 16` である WAV を参照音声として読み込む
- **THEN** PCM 16-bit として復号され、サンプル値・サンプリングレート・チャンネル数が正しく得られる

#### Scenario: EXTENSIBLE with IEEE float SubFormat
- **WHEN** `fmt` チャンクが 40 バイトで `wFormatTag = 0xFFFE`、SubFormat GUID の先頭 2 バイトが `0x0003`、`bitsPerSample = 32` である WAV を参照音声として読み込む
- **THEN** IEEE float 32-bit として復号され、サンプル値が正しく得られる

#### Scenario: EXTENSIBLE with truncated fmt chunk falls back to bit depth
- **WHEN** `fmt` チャンクが 18 バイトしかなく（SubFormat GUID を含まない）`wFormatTag = 0xFFFE`、`bitsPerSample = 16` である WAV を読み込む
- **THEN** PCM 16-bit と推定して復号され、例外は発生しない

#### Scenario: EXTENSIBLE with truncated fmt chunk at 32 bits is rejected
- **WHEN** `fmt` チャンクが 18 バイトしかなく `wFormatTag = 0xFFFE`、`bitsPerSample = 32` である WAV を読み込む
- **THEN** 復号は失敗し、非対応フォーマットである旨のエラーメッセージが返る

#### Scenario: EXTENSIBLE with unknown SubFormat is rejected
- **WHEN** `wFormatTag = 0xFFFE` で SubFormat GUID の先頭 2 バイトが `0x0001` でも `0x0003` でもない WAV を読み込む
- **THEN** 復号は失敗し、非対応フォーマットである旨を示すエラーメッセージが返る

#### Scenario: macOS recording is accepted end to end
- **WHEN** macOS の録音機能が生成した WAV（先行する `JUNK` および `FLLR` チャンクを持ち、`fmt` が `0xFFFE` の 40 バイト、`data` が offset 4096 から始まる）を参照音声として指定して合成する
- **THEN** 参照音声の読み込みは成功し、合成が完了する

### Requirement: WAV parsing tolerates trailing corruption after a complete parse

WAV のチャンク走査において、`fmt` チャンクと `data` チャンクの両方を取得済みである状態で走査中に破損（不正なチャンクサイズ、ファイル範囲を超えるシーク、チャンクヘッダ途中での終端）に遭遇した場合、システムは走査を打ち切り、取得済みのフォーマット情報と音声データを用いて復号を継続 SHALL する。取得済みの結果を破棄して失敗させることは SHALL NOT。

`fmt` または `data` のいずれかが未取得の状態で同種の破損に遭遇した場合、システムは従来どおり失敗 SHALL する。

チャンクの宣言サイズが入力の残りバイト数を超える場合、システムは残りバイト数までにクランプして読み取り SHALL する。クランプの結果 `data` が空である場合は、不完全な WAV として失敗 SHALL する。

#### Scenario: Garbage after the data chunk is ignored
- **WHEN** `fmt` と `data` が正常に読める WAV の末尾に、不正なチャンク ID と入力サイズを大きく超えるチャンクサイズを持つ 36 バイトの余剰データが付いているファイルを読み込む
- **THEN** 走査は打ち切られ、`data` チャンクから読み取ったサンプルが正常に返る

#### Scenario: Oversized data chunk size is clamped
- **WHEN** `data` チャンクの宣言サイズが実際の残りバイト数を超えている WAV（`data` の後に何も続かない）を読み込む
- **THEN** 残りバイト数までが読み取られ、そのサンプルが返る

#### Scenario: Zero-size data placeholder does not block the real chunk
- **WHEN** サイズ 0 の `data` チャンクの後に実データを持つ `data` チャンクが続く WAV を読み込む
- **THEN** 実データの `data` チャンクが読み取られ、そのサンプルが返る

#### Scenario: Duplicate fmt or data chunks keep the first usable one
- **WHEN** 使用可能な `fmt` および `data` チャンクの後に、同じ ID を名乗る別のチャンク（末尾破片がたまたま `fmt `/`data` の 4 バイトを含む形）が続く WAV を読み込む
- **THEN** 最初に取得した `fmt` のメタデータと `data` のサンプルが維持され、後続のチャンクによって置き換えられない

### Requirement: Unreliable data sizes do not decode trailing chunks as audio

`data` チャンクの宣言サイズが信頼できないと判明した場合（宣言サイズが残りバイト数を超えてクランプされた、またはペイロード直後の走査で非印字のチャンク ID に遭遇した）、システムは読み取った音声データの中に「入力の終端までちょうど到達するチャンク列」が埋まっていないかを走査し、見つかった場合はその開始位置で音声を切り詰め SHALL する。これにより、過大な宣言サイズが飲み込んだ後続のメタデータチャンク（`LIST` 等）がフルスケールに近いノイズとして復号されることを防ぐ。

ただし、発見したチャンク列が `fmt ` または `data` を含む場合、それは末尾のメタデータではなくペイロード先頭に埋め込まれた古いヘッダ（record_windows が残す形）であり、音声そのものがその中にあるため、切り詰め位置として採用 SHALL NOT。

宣言サイズが正しく読み取れたファイルでは、この走査は実行 SHALL NOT（正常なファイルが誤って切り詰められるリスクを持ち込まない）。

#### Scenario: Unpatched streaming size with trailing metadata
- **WHEN** `data` の宣言サイズが `0xFFFFFFFF`（パッチされないままのストリーミングヘッダ）で、実ペイロードの後に `LIST` チャンクが続く WAV を読み込む
- **THEN** `LIST` チャンクの開始位置で音声が切り詰められ、ペイロードのサンプルのみが返る

#### Scenario: Unpatched streaming size with audio to EOF
- **WHEN** `data` の宣言サイズが `0xFFFFFFFF` で、実ペイロードがファイル終端まで続く WAV を読み込む
- **THEN** 終端までの全サンプルが返る（切り詰めは発生しない）

#### Scenario: Overstated size swallowing the next chunk head
- **WHEN** `data` の宣言サイズが数バイト過大で、後続する `LIST` チャンクの先頭を飲み込んでいる WAV を読み込む
- **THEN** 飲み込まれたチャンク境界で音声が切り詰められ、本来のサンプルのみが返る

#### Scenario: Embedded old header is not a truncation point
- **WHEN** `data` ペイロードの先頭に古いヘッダの破片（`fmt ` チャンクと、終端をちょうど指す `data` ヘッダ）が埋まっている WAV（record_windows の生成形）を読み込む
- **THEN** 埋め込まれた古いヘッダ列は切り詰め位置として採用されず、宣言範囲の音声データがそのまま返る

#### Scenario: Missing fmt chunk still fails
- **WHEN** `fmt` チャンクを持たない WAV を読み込む
- **THEN** 復号は失敗し、不完全な WAV である旨のエラーメッセージが返る

#### Scenario: Missing data chunk still fails
- **WHEN** `data` チャンクを持たない WAV を読み込む
- **THEN** 復号は失敗し、不完全な WAV である旨のエラーメッセージが返る

#### Scenario: Corruption before fmt and data are complete still fails
- **WHEN** `fmt` を読む前に不正なチャンクサイズで範囲外シークが発生する WAV を読み込む
- **THEN** 復号は失敗する

#### Scenario: Windows recording is accepted end to end
- **WHEN** Windows の録音機能が生成した WAV（`data` の宣言位置と実データの開始位置が 36 バイトずれ、末尾に余剰バイトが残る）を参照音声として指定して合成する
- **THEN** 参照音声の読み込みは成功し、合成が完了する
