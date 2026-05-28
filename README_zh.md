# ![](macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png) NovelViewer

[日本語](README.md) | [English](README_en.md) | **中文**

从网络小说网站下载小说并在本地阅读的小说阅读器。

## 支持平台

- macOS
- Windows
- Linux（未测试）

## 功能

- **横排/竖排切换**：可在设置中切换显示模式
- **文本搜索**：在书库中跨作品全文搜索
- **书签**：添加和删除书签
- **LLM摘要**：指定关键词并选择是否包含剧透进行查询
（支持 Ollama / OpenAI 兼容 API）
- **语音朗读**：使用指定的参考音色进行朗读 / 编辑朗读文本

![阅读界面](images/view3.png)

![编辑界面](images/view2.png)

### LLM（Ollama）设置

1. 下载 Ollama
2. 下载所需模型：
```bash
ollama pull qwen3:8b
```
3. 在 NovelViewer 的设置界面中，将 LLM 提供者设为 `Ollama`，端点 URL 设为 `http://localhost:11434`，模型名称设为已下载的模型名（如 `qwen3:8b`）

## 开发

### 前提条件

- [FVM](https://fvm.app/)（Flutter 版本管理）
- Flutter stable 频道（通过 FVM 管理）
- Visual Studio 2022（Windows）
- Vulkan SDK（Windows）

### 环境搭建

```bash
# 克隆仓库
git clone --recursive git@github.com:endo5501/NovelViewer.git
cd NovelViewer

# 设置 Flutter SDK（通过 FVM）
fvm install

# 获取依赖包
fvm flutter pub get
```

### 环境搭建：AI

请准备 Claude Code / Codex 等编程代理。

```bash
# OpenSpec
npm install -g @fission-ai/openspec@latest

# Codex CLI
npm i -g @openai/codex

# superpowers（在 Claude Code 中）
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

### 构建与运行

```bash
# 在 macOS 上运行
fvm flutter run -d macos

# macOS Release 构建
scripts/build_tts_macos.sh
scripts/build_lame_macos.sh
fvm flutter build macos

# Windows Release 构建
scripts/build_tts_windows.bat
scripts/build_lame_windows.bat
fvm flutter build windows
```

### 测试

```bash
# 运行所有测试
fvm flutter test

# 运行特定测试文件
fvm flutter test test/features/text_download/narou_site_test.dart
```

### 代码检查

项目使用 `flutter_lints` 包进行静态分析。修改代码后请运行代码检查以确认没有问题。

```bash
# 运行静态分析
fvm flutter analyze
```

检查规则在 `analysis_options.yaml` 中配置。

### 发布

推送匹配 `v*` 模式的标签后，GitHub Actions 会自动构建并发布 Windows 版本。

```bash
git tag v1.0.0
git push origin v1.0.0
```

每个发布会附带以下 4 个文件：

- `novel_viewer-setup-v*.exe` — Windows 安装程序（推荐，适合长期使用）
- `novel_viewer-setup-v*.exe.sha256` — 安装程序的 SHA256 哈希
- `novel_viewer-windows-x64-v*.zip` — 便携版（解压即用）
- `novel_viewer-windows-x64-v*.zip.sha256` — ZIP 的 SHA256 哈希

## Windows 安装

### 安装程序（推荐）

如果希望"稳定地长期使用"，请选择安装程序版本。

1. 从 GitHub Releases 下载 `novel_viewer-setup-v*.exe`
2. 运行（安装到 `%LOCALAPPDATA%\Programs\NovelViewer\`，无需 UAC）
3. 从开始菜单启动

**关于 SmartScreen 警告：** 当前安装程序未签名，首次启动时 Windows 会显示"Windows 已保护你的电脑"。请点击"详细信息"→"仍要运行"以继续（代码签名计划在未来支持）。

**用户数据位置：** 用户创建的数据保存在以下路径（均位于安装根目录 `%LOCALAPPDATA%\Programs\NovelViewer\` 之下）：

- `NovelViewer\` — 小说文本、书签、阅读进度
- `novel_metadata.db` — 小说元数据数据库
- `models\` — TTS 模型（用于语音合成，体积较大）
- `voices\` — 参考音频

安装程序只放置 Flutter 构建产物（`novel_viewer.exe`、各类 DLL、`data\` 子目录、许可证文件），不会触及上述用户数据。

- 覆盖安装（升级）：用户数据保留
- 卸载：用户数据保留（如需删除，请手动删除上述各路径）

### 便携版（ZIP）

用于动作确认、特定用途或多环境并行运行时，请使用 ZIP 版本。

1. 从 GitHub Releases 下载 `novel_viewer-windows-x64-v*.zip`
2. 解压到任意文件夹
3. 运行 `novel_viewer.exe`

数据保存在解压后的可执行文件旁，与安装程序版本结构相同（`NovelViewer\`、`novel_metadata.db`、`models\`、`voices\`）。整个文件夹复制到其他位置即可连同数据一起克隆环境。

## 技术栈

- **框架**：Flutter (Dart)
- **状态管理**：Riverpod
- **数据库**：SQLite (sqflite / sqflite_common_ffi)
- **设置持久化**：SharedPreferences
- **HTTP 通信**：http 包
- **HTML 解析**：html 包
- **语音合成**：qwen3-tts.cpp
- **MP3 输出**：lame
