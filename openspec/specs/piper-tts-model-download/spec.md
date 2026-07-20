## Purpose

Stream-download Piper TTS model files (`.onnx` + `.onnx.json`) from HuggingFace and OpenJTalk dictionary into `models/piper/` alongside the library, with directory auto-creation, dictionary skip-if-present, and a Riverpod download-state machine (idle / downloading / completed / error).
## Requirements
### Requirement: Download piper-plus model files from HuggingFace
The system SHALL download piper-plus model files from HuggingFace using HTTPS streaming. The initial supported model SHALL be `ja_JP-tsukuyomi-chan-medium` requiring two files: the ONNX model file (`.onnx`) and its JSON config file (`.onnx.json`). The download SHALL use HTTP streaming to write directly to disk without loading the entire file into memory.

#### Scenario: Download Japanese model files successfully
- **WHEN** the user initiates a piper model download for `ja_JP-tsukuyomi-chan-medium`
- **THEN** `ja_JP-tsukuyomi-chan-medium.onnx` and `ja_JP-tsukuyomi-chan-medium.onnx.json` are downloaded and saved to the `models/piper/` directory

#### Scenario: Download uses streaming to avoid memory issues
- **WHEN** a model file is being downloaded
- **THEN** the file content is streamed directly to disk without buffering the entire file in memory

#### Scenario: Download shows progress
- **WHEN** a piper model download is in progress
- **THEN** the current file name and download percentage are reported via the download state

### Requirement: Download OpenJTalk dictionary with model
The system SHALL download the OpenJTalk dictionary files as part of the piper model download process. The dictionary SHALL be saved to `models/piper/open_jtalk_dic/`. If the dictionary directory already exists and is non-empty, the download SHALL be skipped.

#### Scenario: Download dictionary with first model
- **WHEN** the user downloads a piper model and `models/piper/open_jtalk_dic/` does not exist
- **THEN** the OpenJTalk dictionary is downloaded and extracted to `models/piper/open_jtalk_dic/`

#### Scenario: Skip dictionary download when already present
- **WHEN** the user downloads a second piper model and `models/piper/open_jtalk_dic/` already exists with files
- **THEN** the dictionary download step is skipped

### Requirement: Piper models directory path resolution
The piper models directory SHALL be located at `models/piper/` relative to the NovelViewer library directory's parent. The OpenJTalk dictionary SHALL be at `models/piper/open_jtalk_dic/`. If the directory does not exist, it SHALL be created automatically before downloading.

#### Scenario: Resolve piper models directory
- **WHEN** the library path is `~/Documents/NovelViewer`
- **THEN** the piper models directory is `~/Documents/models/piper/`

#### Scenario: Resolve OpenJTalk dictionary directory
- **WHEN** the library path is `~/Documents/NovelViewer`
- **THEN** the OpenJTalk dictionary directory is `~/Documents/models/piper/open_jtalk_dic/`

### Requirement: Piper model download state management
The system SHALL manage piper model download state using a Riverpod provider with states: idle, downloading (with currentFile and progress), completed (with modelsDir), and error (with message). The state management SHALL follow the same pattern as the existing qwen3-tts model download.

#### Scenario: Initial state is idle
- **WHEN** the app starts and no download is in progress
- **THEN** the piper download state is idle

#### Scenario: Download error shows retry option
- **WHEN** a piper model download fails
- **THEN** the state transitions to error with the failure message, and a retry action is available

### Requirement: Piper モデルは推論ランナーと互換な固定リビジョンから取得する
システムは Piper モデルファイル（`.onnx` / `.onnx.json`）を、同梱する piper-plus 推論ランナー（`third_party/piper-plus` サブモジュールの固定コミット）と**互換なモデルリビジョンに固定**して取得しなければならない（SHALL）。HuggingFace の `main` などの**可変参照からのライブ取得を行ってはならない**（MUST NOT）。モデル取得元の基底 URL は、互換性が確認された固定リビジョン（コミット SHA）を指し、その選定理由を near コメントで明示しなければならない（SHALL）。

理由: モデル（実行時取得）と推論ランナー（git ピン留め）の参照方式が非対称だと、上流モデルの更新（例: 話者条件付けを `sid` から `speaker_embedding` + `speaker_embedding_mask` へ変更する 2026-05-03 のデコーダ刷新）により、ランナーが供給しない ONNX 入力を新モデルが要求し、合成が `Missing Input: speaker_embedding_mask` で失敗する。

#### Scenario: 基底 URL は可変参照でなく固定リビジョンを指す
- **WHEN** Piper モデルのダウンロード元基底 URL を検査する
- **THEN** URL は `/resolve/main`（または他のブランチ名・可変タグ）ではなく、固定コミット SHA（`/resolve/<commit-sha>`）を含む

#### Scenario: 取得モデルが凍結ランナーと互換である
- **WHEN** ピン留めされたリビジョンから取得したモデルで Piper 合成を実行する
- **THEN** 合成はネイティブランナーのエラー（例: `Missing Input: speaker_embedding_mask`）なく完了し、音声が生成される

### Requirement: 完了マーカーは取得元リビジョンを記録する

モデルの完了マーカー (`.piper_models_complete`) は、取得元のピン留めリビジョンを記録しなければならない (SHALL)。`areModelsDownloaded()` はマーカーの内容が現在のピン留めリビジョンと一致しない場合、モデルを未取得として扱わなければならない (SHALL)。リビジョンを記録しない旧形式のマーカー (タイムスタンプのみ) も不一致として扱われる (SHALL)。これにより、ピン留め前に取得された非互換モデルは通常のダウンロード導線で再取得され、ユーザによるファイルの手動削除を必要としない (SHALL NOT require manual deletion)。

再取得ではモデルファイル (`*.onnx` / `*.onnx.json`) が同名で上書きされ、`open_jtalk_dic/` は再取得の対象外とする (SHALL)。

移行時の副作用として、ピン留め後に正しいモデルを取得済みのユーザも、マーカーが旧形式であるため一度だけ再取得が発生する。ローカルのモデルが互換であるか否かを判別する手段がないため、これは意図された挙動とする。

#### Scenario: 旧形式マーカーは未取得として扱われる

- **WHEN** モデルファイルが存在し、マーカーの内容がタイムスタンプ (旧形式) である
- **THEN** `areModelsDownloaded()` は false を返し、ダウンロード導線が再取得を提示する

#### Scenario: 異なるリビジョンのマーカーは未取得として扱われる

- **WHEN** マーカーの内容が現在のピン留めリビジョンと異なる SHA である
- **THEN** `areModelsDownloaded()` は false を返す

#### Scenario: 一致するマーカーは取得済みとして扱われる

- **WHEN** マーカーの内容が現在のピン留めリビジョンと一致し、モデルファイルが揃っている
- **THEN** `areModelsDownloaded()` は true を返し、再取得は発生しない

#### Scenario: ダウンロード完了時にリビジョンが記録される

- **WHEN** モデルのダウンロードが正常に完了する
- **THEN** マーカーには取得元のピン留めリビジョンが書き込まれる

### Requirement: モデルロード前の取得状態の検証

システムはモデルのロードが必要になった時点で、対象エンジンのモデルが取得済みであることを検証しなければならない (SHALL)。未取得または取得状態が現在のピン留めと一致しない場合、モデルをロードしてはならず (MUST NOT)、再ダウンロードが必要である旨をユーザに提示しなければならない (SHALL)。検証に失敗した場合、システムは自動的に大容量のダウンロードを開始してはならない (MUST NOT) — 従量課金回線での不意の通信を避けるため、再取得はユーザが設定画面から明示的に実行する。

検証は、本文の読み上げ開始と編集画面の生成の双方の経路に適用される (SHALL)。ただし**モデルを必要としない操作を妨げてはならない** (MUST NOT)。生成済み音声の再生は DB に保存された音声を再生するだけでモデルをロードしないため、モデルが未取得であっても従来どおり再生できなければならない (SHALL)。

理由: 完了マーカーの検査は設定画面の表示にしか使われておらず、設定画面を経由せず再生を開始したユーザは、非互換モデルがロードされて合成時に `Missing Input: speaker_embedding_mask` で失敗するまで問題に気づけなかった。一方で読み上げ開始は再生と生成の共通入口であり、入口で一律に拒否すると、モデルを必要としない再生まで巻き添えで止まる。

#### Scenario: 旧モデルのまま未生成のエピソードを読み上げる

- **WHEN** マーカーが現在のピン留めリビジョンと一致しない状態で、音声が未生成のエピソードの読み上げを開始する
- **THEN** モデルはロードされず、再ダウンロードが必要である旨のメッセージが表示される

#### Scenario: 旧モデルでも生成済み音声は再生できる

- **WHEN** マーカーが一致しない状態で、全セグメントの音声が生成済みのエピソードを再生する
- **THEN** 保存済みの音声が最後まで再生され、モデルのロードは一度も行われず、再ダウンロードのメッセージも表示されない

#### Scenario: 生成済みと未生成が混在するエピソード

- **WHEN** マーカーが一致しない状態で、一部のセグメントのみ音声が生成済みのエピソードを再生する
- **THEN** 生成済みのセグメントは再生され、未生成のセグメントに到達した時点で中断し、再ダウンロードが必要である旨のメッセージが表示される

#### Scenario: 旧モデルのまま編集画面で生成する

- **WHEN** 同じ状態で編集画面のセグメント生成を実行する
- **THEN** 生成は開始されず、同じメッセージが表示される

#### Scenario: 取得済みモデルでは検証が妨げにならない

- **WHEN** マーカーが一致し、モデルファイルが揃っている
- **THEN** 検証は透過的に通り、従来どおり合成が開始される

