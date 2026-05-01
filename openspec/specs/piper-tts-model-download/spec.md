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
