## ADDED Requirements

### Requirement: WAV reference audio accepts WAVE_FORMAT_EXTENSIBLE

参照音声として渡された WAV の `fmt` チャンクの `wFormatTag` が `WAVE_FORMAT_EXTENSIBLE` (`0xFFFE`) である場合、システムは `fmt` チャンク拡張部の SubFormat GUID の先頭 2 バイトを実フォーマットとして解決し、通常の PCM / IEEE float として復号 SHALL する。解決した値が `0x0001` (PCM) でも `0x0003` (IEEE float) でもない場合、システムは非対応フォーマットとして失敗 SHALL する。

`fmt` チャンクが `0xFFFE` を宣言しているにもかかわらず SubFormat GUID を含むだけの長さを持たない場合、システムは失敗せず `bitsPerSample` から実フォーマットを推定 SHALL する（16 および 24 は PCM、32 は IEEE float）。

#### Scenario: EXTENSIBLE with PCM SubFormat
- **WHEN** `fmt` チャンクが 40 バイトで `wFormatTag = 0xFFFE`、SubFormat GUID の先頭 2 バイトが `0x0001`、`bitsPerSample = 16` である WAV を参照音声として読み込む
- **THEN** PCM 16-bit として復号され、サンプル値・サンプリングレート・チャンネル数が正しく得られる

#### Scenario: EXTENSIBLE with IEEE float SubFormat
- **WHEN** `fmt` チャンクが 40 バイトで `wFormatTag = 0xFFFE`、SubFormat GUID の先頭 2 バイトが `0x0003`、`bitsPerSample = 32` である WAV を参照音声として読み込む
- **THEN** IEEE float 32-bit として復号され、サンプル値が正しく得られる

#### Scenario: EXTENSIBLE with truncated fmt chunk falls back to bit depth
- **WHEN** `fmt` チャンクが 18 バイトしかなく（SubFormat GUID を含まない）`wFormatTag = 0xFFFE`、`bitsPerSample = 16` である WAV を読み込む
- **THEN** PCM 16-bit と推定して復号され、例外は発生しない

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
- **WHEN** `data` チャンクの宣言サイズが実際の残りバイト数を超えている WAV を読み込む
- **THEN** 残りバイト数までが読み取られ、そのサンプルが返る

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
