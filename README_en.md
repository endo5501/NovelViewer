# ![](macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png) NovelViewer

[日本語](README.md) | **English** | [中文](README_zh.md)

A novel viewer for downloading and reading web novels locally from web novel sites.

## Supported Platforms

- macOS
- Windows
- Linux (untested)

## Features

- **Horizontal/Vertical text layout**: Switch between display modes in settings
- **Text search**: Full-text search across all novels in your library
- **Bookmarks**: Add and remove bookmarks
- **LLM Summarization**: Look up specified terms with spoiler/no-spoiler options
(Supports Ollama / OpenAI-compatible APIs)
- **Text-to-Speech**: Read aloud using a specified reference voice / edit read-aloud text

![Reading view](images/view1.png)

![Editing view](images/view2.png)

### LLM (Ollama) Setup

1. Download Ollama
2. Download your desired model:
```bash
ollama pull qwen3:8b
```
3. In NovelViewer's settings, set the LLM provider to `Ollama`, the endpoint URL to `http://localhost:11334`, and the model name to the downloaded model (e.g., `qwen3:8b`)

## Development

### Prerequisites

- [FVM](https://fvm.app/) (Flutter Version Management)
- Flutter stable channel (managed via FVM)
- Visual Studio 2022 (Windows)
- Vulkan SDK (Windows)

### Setup

```bash
# Clone the repository
git clone --recursive git@github.com:endo5501/NovelViewer.git
cd NovelViewer

# Set up Flutter SDK (via FVM)
fvm install

# Get dependencies
fvm flutter pub get
```

### Setup: AI

Prepare a coding agent such as Claude Code / Codex.

```bash
# OpenSpec
npm install -g @fission-ai/openspec@latest

# Codex CLI
npm i -g @openai/codex

# superpowers (in Claude Code)
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

### Build & Run

```bash
# Run on macOS
fvm flutter run -d macos

# Release build for macOS
scripts/build_tts_macos.sh
scripts/build_lame_macos.sh
fvm flutter build macos

# Release build for Windows
scripts/build_tts_windows.bat
scripts/build_lame_windows.bat
fvm flutter build windows
```

### Testing

```bash
# Run all tests
fvm flutter test

# Run a specific test file
fvm flutter test test/features/text_download/narou_site_test.dart
```

### Linter

Static analysis is configured using the `flutter_lints` package. Run the linter after code changes to ensure there are no issues.

```bash
# Run static analysis
fvm flutter analyze
```

Lint rules are configured in `analysis_options.yaml`.

### Release

Pushing a tag matching the `v*` pattern triggers an automatic Windows build and release via GitHub Actions.

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **Database**: SQLite (sqflite / sqflite_common_ffi)
- **Settings Persistence**: SharedPreferences
- **HTTP**: http package
- **HTML Parsing**: html package
- **Text-to-Speech**: qwen3-tts.cpp
- **MP3 Output**: lame
