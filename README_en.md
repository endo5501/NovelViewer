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

![Reading view](images/view3.png)

![Editing view](images/view2.png)

### LLM (Ollama) Setup

1. Download Ollama
2. Download your desired model:
```bash
ollama pull qwen3:8b
```
3. In NovelViewer's settings, set the LLM provider to `Ollama`, the endpoint URL to `http://localhost:11434`, and the model name to the downloaded model (e.g., `qwen3:8b`)

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

Each release attaches the following four files:

- `novel_viewer-setup-v*.exe` — Windows installer (recommended for long-term use)
- `novel_viewer-setup-v*.exe.sha256` — SHA256 of the installer
- `novel_viewer-windows-x64-v*.zip` — Portable build (extract and run)
- `novel_viewer-windows-x64-v*.zip.sha256` — SHA256 of the ZIP

## Windows Installation

### Installer (Recommended)

Use the installer for long-term, "settled" usage.

1. Download `novel_viewer-setup-v*.exe` from GitHub Releases
2. Run it (installs to `%LOCALAPPDATA%\Programs\NovelViewer\`, no UAC required)
3. Launch from the Start Menu

**About the SmartScreen warning:** The installer is currently unsigned, so Windows shows "Windows protected your PC" on first run. Click "More info" → "Run anyway" to proceed. Code signing is planned for the future.

**User data location:** Novel text, database, and other user data live under `%LOCALAPPDATA%\Programs\NovelViewer\NovelViewer\`. The installer never touches this subfolder.

- Reinstall / upgrade: user data is preserved
- Uninstall: user data is left behind (delete `%LOCALAPPDATA%\Programs\NovelViewer\NovelViewer\` manually if you want to remove it)

### Portable (ZIP)

Use the ZIP build for compatibility testing, ad-hoc environments, or running multiple independent setups in parallel.

1. Download `novel_viewer-windows-x64-v*.zip` from GitHub Releases
2. Extract anywhere
3. Run `novel_viewer.exe`

Data is stored in a `NovelViewer/` subfolder beside the extracted executable. Copying the whole folder elsewhere clones the environment along with the data.

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **Database**: SQLite (sqflite / sqflite_common_ffi)
- **Settings Persistence**: SharedPreferences
- **HTTP**: http package
- **HTML Parsing**: html package
- **Text-to-Speech**: qwen3-tts.cpp
- **MP3 Output**: lame
