## ADDED Requirements

### Requirement: 参照音声の WAV / MP3 対応

`audiocpp_synthesize` に渡される `ref_wav_path` は WAV と MP3 の両方を受け付けなければならない (SHALL)。シェイム層は WAV 専用の読み込み関数ではなく、フォーマットを判別する共通リーダ `engine::audio::read_audio_f32` を経由しなければならない (SHALL)。判別は先頭バイト (`RIFF`…`WAVE`) を優先し、判別できない場合に拡張子 (`.mp3` / `.mpa` / `.mpeg`) をフォールバックとして用いなければならない (SHALL)。デコード結果はサンプリングレートとチャンネル数を保持し、WAV 経路と同一の内部表現でエンジンに渡されなければならない (SHALL)。この対応により `voice-reference-library` が列挙する `.wav` / `.mp3` の両方が Irodori エンジンで実際に使用可能になる。

#### Scenario: MP3 の参照音声でクローン合成する

- **WHEN** `voices/` 内の MP3 ファイルのパスを `ref_wav_path` に指定して合成する
- **THEN** MP3 がデコードされ、参照話者の声質を持つ音声が生成される (エラーにならない)

#### Scenario: WAV の参照音声は従来どおり動作する

- **WHEN** WAV ファイルのパスを `ref_wav_path` に指定して合成する
- **THEN** 従来と同一の経路 (`read_wav_f32`) で読み込まれ、既存の挙動が変化しない

#### Scenario: 非 ASCII のファイル名を持つ MP3 を読み込む

- **WHEN** `月ノ美兎.mp3` のような非 ASCII 名の MP3 を参照音声に指定する
- **THEN** Windows を含む全プラットフォームでデコードに成功する

#### Scenario: 拡張子が .wav で中身が MP3 のファイル

- **WHEN** 中身が MP3 のファイルが `.wav` 拡張子で指定される
- **THEN** MP3 として読み替えず、`invalid WAV RIFF header` を含むエラーになる (拡張子が `.wav` の場合は拡張子の宣言を優先する)

### Requirement: 未対応フォーマットの診断可能なエラー

参照音声の読み込みに失敗した場合、エラーメッセージは対象ファイルのパスと、対応フォーマットの一覧を含まなければならない (SHALL)。このメッセージは `audiocpp_get_error(ctx)` 経由で Dart 層まで伝播し、アプリログに記録されなければならない (SHALL)。

#### Scenario: 未対応フォーマットを指定する

- **WHEN** WAV でも MP3 でもないファイルを `ref_wav_path` に指定する
- **THEN** `unsupported audio input format: <path> (supported: WAV, MP3)` に相当するメッセージで失敗する

#### Scenario: 空または破損した MP3 を指定する

- **WHEN** 空ファイル、またはデコードできない MP3 を `ref_wav_path` に指定する
- **THEN** 対象パスを含むエラーメッセージで失敗し、プロセスがクラッシュしない

#### Scenario: 非 ASCII パスを含むエラーメッセージ

- **WHEN** `月ノ美兎.txt` のような非 ASCII 名のファイルで読み込みが失敗する
- **THEN** エラーメッセージ中のパスは UTF-8 でエンコードされ、Dart 側の UTF-8 デコードが `FormatException` を起こさない (Windows の ANSI コードページに変換されてはならない)
