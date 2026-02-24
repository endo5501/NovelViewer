## ADDED Requirements

### Requirement: Download TTS model files from HuggingFace
The system SHALL download two GGUF model files from HuggingFace's koboldcpp repository using HTTPS streaming. The files SHALL be:
- `qwen3-tts-0.6b-f16.gguf` from `https://huggingface.co/koboldcpp/tts/resolve/main/qwen3-tts-0.6b-f16.gguf`
- `qwen3-tts-tokenizer-f16.gguf` from `https://huggingface.co/koboldcpp/tts/resolve/main/qwen3-tts-tokenizer-f16.gguf`

The download SHALL use HTTP streaming (`StreamedResponse`) to write directly to disk without loading the entire file into memory.

#### Scenario: Download both model files successfully
- **WHEN** the user initiates a model download
- **THEN** both `qwen3-tts-0.6b-f16.gguf` and `qwen3-tts-tokenizer-f16.gguf` are downloaded sequentially and saved to the models directory

#### Scenario: Download uses streaming to avoid memory issues
- **WHEN** a model file is being downloaded
- **THEN** the file content is streamed directly to disk using `StreamedResponse` without buffering the entire file in memory

### Requirement: Models directory path resolution
The models directory SHALL be located at the same level as the NovelViewer library directory. The path SHALL be resolved by taking the parent directory of the library path (provided by `libraryPathProvider`) and appending `models`. If the `models` directory does not exist, it SHALL be created automatically before downloading.

#### Scenario: Resolve models directory on macOS
- **WHEN** the library path is `~/Documents/NovelViewer`
- **THEN** the models directory is `~/Documents/models`

#### Scenario: Resolve models directory on Windows
- **WHEN** the library path is `{exeDir}/NovelViewer`
- **THEN** the models directory is `{exeDir}/models`

#### Scenario: Create models directory if not exists
- **WHEN** a download is initiated and the models directory does not exist
- **THEN** the system creates the `models` directory (including any intermediate directories) before downloading

### Requirement: Download progress tracking
The system SHALL track and report download progress during file download. Progress SHALL be calculated from the `Content-Length` HTTP response header and the bytes received so far. The progress SHALL include the current file name being downloaded and a progress ratio (0.0 to 1.0).

#### Scenario: Report progress during download
- **WHEN** a model file is being downloaded and the server provides `Content-Length`
- **THEN** the system reports progress as a ratio of bytes received to total bytes, along with the current file name

#### Scenario: Handle missing Content-Length
- **WHEN** a model file is being downloaded and the server does not provide `Content-Length`
- **THEN** the system reports progress as indeterminate (progress ratio is null) while still showing the current file name

### Requirement: Detect already downloaded models
The system SHALL check whether model files already exist in the models directory. A model file is considered "already downloaded" when the file exists and has a file size greater than 0 bytes.

#### Scenario: Both model files already exist
- **WHEN** the system checks for existing models and both `qwen3-tts-0.6b-f16.gguf` and `qwen3-tts-tokenizer-f16.gguf` exist with non-zero size in the models directory
- **THEN** the system reports that models are already downloaded

#### Scenario: One or no model files exist
- **WHEN** the system checks for existing models and fewer than two valid model files are found
- **THEN** the system reports that models are not yet downloaded

### Requirement: Auto-set model directory after download
The system SHALL automatically set the TTS model directory path setting to the models directory path after a successful download. This SHALL be done through the `ttsModelDirProvider` notifier.

#### Scenario: Auto-set model directory on download completion
- **WHEN** both model files have been downloaded successfully
- **THEN** the TTS model directory setting is automatically updated to point to the models directory

### Requirement: Download error handling
The system SHALL handle download errors gracefully. On HTTP errors, network errors, or file system errors, the system SHALL report the error and clean up any partially downloaded files.

#### Scenario: HTTP error during download
- **WHEN** the server responds with a non-200 status code during download
- **THEN** the system reports an error with the HTTP status code and removes any partially downloaded file

#### Scenario: Network error during download
- **WHEN** a network connection error occurs during download
- **THEN** the system reports a network error and removes any partially downloaded file

#### Scenario: File system error during download
- **WHEN** a file system error occurs while writing the downloaded file
- **THEN** the system reports the error to the caller
