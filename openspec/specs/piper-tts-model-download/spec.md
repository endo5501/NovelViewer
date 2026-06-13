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

### Requirement: 旧モデル取得済みユーザの再取得は手動で行う
モデルの基底リビジョンを変更した場合、既にモデルを取得済みのユーザのディスク上には旧（非互換の可能性がある）モデルファイルが残り、`areModelsDownloaded()` がマーカーとファイルの存在により取得済みと判定するため、システムは自動的な再取得を行わない（SHALL NOT, 現行方針）。互換モデルへ入れ替えるには、ユーザが `models/piper/` 内のモデルファイル（`*.onnx` / `*.onnx.json` / `.piper_models_complete` マーカー）を手動削除してから再ダウンロードする必要がある。`open_jtalk_dic/` の削除は不要とする。

#### Scenario: 旧モデルが残っていると自動再取得されない
- **WHEN** 基底リビジョンを変更したが、ユーザのディスクに旧モデルファイルと完了マーカーが残っている
- **THEN** `areModelsDownloaded()` は取得済み（true）と判定し、新リビジョンのモデルは自動取得されない

#### Scenario: 手動削除後に互換モデルが取得される
- **WHEN** ユーザが `models/piper/` のモデルファイルと完了マーカーを削除し、再ダウンロードを実行する
- **THEN** ピン留めされたリビジョンの互換モデルが取得され、`open_jtalk_dic/` は既存のまま再利用される

