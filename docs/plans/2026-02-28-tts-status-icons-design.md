# TTS Status Icons in File Browser - Design

## Overview

ファイルブラウザのエピソード一覧に、TTS読み上げデータの生成状態を示すアイコンを表示する。

## Architecture

### Approach: Provider + Batch Query

`directoryContentsProvider` の `DirectoryContents` にTTS状態マップを統合し、ディレクトリ変更時に一括クエリで全エピソードの状態を取得する。

### Data Layer

#### TtsEpisodeStatus enum

3つの状態を定義:
- `none` — DB未登録（TTS未使用）
- `partial` — 一部セグメントのみ生成済み（DB status = `partial` or `generating`）
- `completed` — 全セグメント生成済み（DB status = `completed`）

#### TtsAudioRepository 新メソッド

```dart
Future<Map<String, TtsEpisodeStatus>> getAllEpisodeStatuses()
```

`SELECT file_name, status FROM tts_episodes` で全行取得し、status文字列をTtsEpisodeStatusに変換。

#### DirectoryContents 拡張

```dart
class DirectoryContents {
  final List<FileEntry> files;
  final List<DirectoryEntry> subdirectories;
  final Map<String, TtsEpisodeStatus> ttsStatuses; // New
}
```

### Provider Layer

`directoryContentsProvider` 内で、小説フォルダ配下の場合のみ `tts_audio.db` を開いて状態を一括取得。ライブラリルートでは空マップ。

TTS生成完了後は `directoryContentsProvider` を `ref.invalidate()` で再取得。

### UI Layer

#### File Browser ListTile

エピソードの `ListTile` に `trailing` としてTTS状態アイコンを追加。

#### Icon Mapping

| Status | Icon | Color | Tooltip |
|---|---|---|---|
| `completed` | `Icons.check_circle` | `Colors.green` | 読み上げ生成済み |
| `partial` | `Icons.pie_chart` | `Colors.orange` | 読み上げ一部生成 |
| `none` | 非表示 | — | — |

## Affected Files

- `lib/features/tts/data/tts_audio_repository.dart` — 新メソッド追加
- `lib/features/file_browser/data/file_system_service.dart` — DirectoryContents拡張
- `lib/features/file_browser/providers/file_browser_providers.dart` — TTS状態取得統合
- `lib/features/file_browser/presentation/file_browser_panel.dart` — UIアイコン追加
