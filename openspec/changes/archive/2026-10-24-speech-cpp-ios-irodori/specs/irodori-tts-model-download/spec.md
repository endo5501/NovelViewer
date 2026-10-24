## MODIFIED Requirements

### Requirement: Irodori モデル資産の一括ダウンロード
システムは `IrodoriModelDownloadService` を提供し、**選択中の variant に対応する単一の GGUF ファイル**をその variant の取得元からダウンロードしなければならない (SHALL)。

| variant | 取得元 | 相対パス | バイト数 | SHA-256 |
|---|---|---|---:|---|
| `v3` | endo5501 の Hugging Face リポジトリ | `Irodori-TTS-600M-v3-VoiceDesign-GGUF/irodori-tts-600m-v3-voicedesign-f16.gguf` | 1,463,787,680 | （検証しない） |
| `v4` | endo5501 の Hugging Face リポジトリ | `Irodori-TTS-v4-Small-GGUF/irodori-tts-v4-small-f16.gguf` | 1,762,161,536 | （検証しない） |
| `v4.1-mf` | `sakasegawa/Irodori-TTS-v4.1-Small-MF-GGUF`、リビジョン `9db7da1bec3d1069ef8e29732e0497be60c7b047` に固定 | `Irodori-TTS-v4.1-Small-MF-GGUF/Irodori-TTS-866M-MF-v4.1-F16.gguf` | 1,920,321,792 | `e237dc3eefe469b8bba87872beacf12fb7fe00dbdf85767edca8ec04ab910d13` |

精度は **f16** でなければならない (MUST)。audio.cpp の variant に q8_0 パッケージを配布してはならない (MUST NOT)。ggml の Vulkan バックエンドが q8_0 の重みで出力を一定のフルスケールに張り付かせるためである（design D7）。`v4.1-mf` も F16 とする。iPad の試聴で、Q8_0 は一部の語が発音しきれず、Q4_K は音が崩れたためである（`speech-cpp-ios-spike`）。

GGUF は model spec / model_config / tokenizer をすべて埋め込んでいる。そのため、兄弟ディレクトリ（`llm-jp-3-150m`、`Semantic-DACVAE-Japanese-32dim`）を配置してはならない (MUST NOT)。保存レイアウトは、variant ごとのディレクトリの下に `.gguf` を 1 本置く形でなければならない (MUST)。

ダウンロード完了後のサイズは、上表に固定した値と一致しなければならない (MUST)。SHA-256 を固定した variant では、ハッシュも一致しなければならない (MUST)。どちらかが一致しないときは、そのファイルを削除したうえでエラーとしなければならない (SHALL)。ハッシュの検証はダウンロードを完了するときに行う。ダウンロード済みかどうかの判定では、これまでどおりサイズだけを確かめる。

#### Scenario: v4 のダウンロード完了
- **WHEN** ユーザが variant `v4` を選択してモデルダウンロードを開始し、完走する
- **THEN** `Irodori-TTS-v4-Small-GGUF/irodori-tts-v4-small-f16.gguf` が存在し、サイズが 1,762,161,536 バイトである

#### Scenario: v4.1-mf は固定したリビジョンから取得される
- **WHEN** variant `v4.1-mf` のダウンロードを開始する
- **THEN** 取得する URL は `sakasegawa/Irodori-TTS-v4.1-Small-MF-GGUF` の、リビジョン `9db7da1bec3d1069ef8e29732e0497be60c7b047` のファイルを指す

#### Scenario: v4.1-mf のダウンロード完了
- **WHEN** variant `v4.1-mf` のダウンロードが完走し、サイズと SHA-256 が固定値と一致する
- **THEN** `Irodori-TTS-v4.1-Small-MF-GGUF/Irodori-TTS-866M-MF-v4.1-F16.gguf` が存在し、ダウンロード済みと判定される

#### Scenario: ハッシュ不一致は破棄される
- **WHEN** variant `v4.1-mf` の転送が完了し、サイズは一致するが SHA-256 が一致しない
- **THEN** そのファイルは削除され、ダウンロード済みとは判定されない

#### Scenario: GGUF 単体でモデルが解決できる
- **WHEN** ダウンロード完了後に variant のディレクトリをネイティブエンジンへ渡す
- **THEN** 兄弟ディレクトリなしでモデルのロードが成功する

#### Scenario: サイズ不一致は破棄される
- **WHEN** 転送が完了したがファイルサイズが固定値と一致しない
- **THEN** そのファイルは削除され、「ダウンロード済み」と判定されない
