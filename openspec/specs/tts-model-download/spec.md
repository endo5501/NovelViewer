## ADDED Requirements

### Requirement: Download TTS model files from HuggingFace
The system SHALL download GGUF model files from HuggingFace's `endo5501/qwen3-tts.cpp` repository using HTTPS streaming. The files to download SHALL depend on the selected model size:
- For `small` (0.6B): `qwen3-tts-0.6b-f16.gguf` and `qwen3-tts-tokenizer-f16.gguf`
- For `large` (1.7B): `qwen3-tts-1.7b-f16.gguf` and `qwen3-tts-tokenizer-f16.gguf`

The base URL SHALL be `https://huggingface.co/endo5501/qwen3-tts.cpp/resolve/main`.

The download SHALL use HTTP streaming (`StreamedResponse`) to write directly to disk without loading the entire file into memory.

#### Scenario: Download 0.6B model files successfully
- **WHEN** the user initiates a model download with model size `small`
- **THEN** `qwen3-tts-0.6b-f16.gguf` and `qwen3-tts-tokenizer-f16.gguf` are downloaded from `endo5501/qwen3-tts.cpp` and saved to the `models/0.6b/` directory

#### Scenario: Download 1.7B model files successfully
- **WHEN** the user initiates a model download with model size `large`
- **THEN** `qwen3-tts-1.7b-f16.gguf` and `qwen3-tts-tokenizer-f16.gguf` are downloaded from `endo5501/qwen3-tts.cpp` and saved to the `models/1.7b/` directory

#### Scenario: Download uses streaming to avoid memory issues
- **WHEN** a model file is being downloaded
- **THEN** the file content is streamed directly to disk using `StreamedResponse` without buffering the entire file in memory

### Requirement: Models directory path resolution
The models base directory SHALL be located at the same level as the NovelViewer library directory. The path SHALL be resolved by taking the parent directory of the library path and appending `models` using the platform's native path joining. Each model size SHALL have its own subdirectory: `models/0.6b/` for small and `models/1.7b/` for large. If the subdirectory does not exist, it SHALL be created automatically before downloading.

#### Scenario: Resolve models subdirectory for small model
- **WHEN** the library path is `~/Documents/NovelViewer` and model size is `small`
- **THEN** the models directory is `~/Documents/models/0.6b`

#### Scenario: Resolve models subdirectory for large model
- **WHEN** the library path is `~/Documents/NovelViewer` and model size is `large`
- **THEN** the models directory is `~/Documents/models/1.7b`

#### Scenario: Create model subdirectory if not exists
- **WHEN** a download is initiated and the model subdirectory does not exist
- **THEN** the system creates the subdirectory (including any intermediate directories) before downloading

#### Scenario: Tests use platform-native path construction
- **WHEN** tests verify path resolution or compare paths
- **THEN** tests SHALL construct expected paths using `p.join()` from the `path` package instead of hardcoding path separators

### Requirement: Download progress tracking
The system SHALL track and report download progress during file download. Progress SHALL be calculated from the `Content-Length` HTTP response header and the bytes received so far. The progress SHALL include the current file name being downloaded and a progress ratio (0.0 to 1.0).

#### Scenario: Report progress during download
- **WHEN** a model file is being downloaded and the server provides `Content-Length`
- **THEN** the system reports progress as a ratio of bytes received to total bytes, along with the current file name

#### Scenario: Handle missing Content-Length
- **WHEN** a model file is being downloaded and the server does not provide `Content-Length`
- **THEN** the system reports progress as indeterminate (progress ratio is null) while still showing the current file name

### Requirement: Detect already downloaded models
The system SHALL check whether model files already exist in the model-size-specific subdirectory. A model set is considered "already downloaded" when the completion marker file (`.tts_models_complete`) exists and all required model files exist with non-zero file size.

#### Scenario: 0.6B model files already exist
- **WHEN** the system checks for existing models with size `small` and both `qwen3-tts-0.6b-f16.gguf` and `qwen3-tts-tokenizer-f16.gguf` exist with non-zero size in `models/0.6b/` with completion marker
- **THEN** the system reports that the small model is already downloaded

#### Scenario: 1.7B model not yet downloaded
- **WHEN** the system checks for existing models with size `large` and `models/1.7b/` does not exist or is incomplete
- **THEN** the system reports that the large model is not yet downloaded

### Requirement: Auto-set model directory after download
The system SHALL NOT explicitly set the TTS model directory after download. The model directory SHALL be derived automatically from the selected model size. After a successful download, the system SHALL only update the download state to completed.

#### Scenario: Model directory auto-derived after download
- **WHEN** a model download completes successfully
- **THEN** the download state changes to completed and the model directory is available via the automatic resolution from model size

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
