## Why

現在、TTS読み上げのリファレンス音声ファイルはファイルピッカーでフルパスを指定する必要があり、ユーザーにとって不便である。また、対応フォーマットがWAVのみに限定されている。専用の`voices`フォルダにリファレンス音声ファイルを配置し、ドロップダウンで簡単に選択できるようにすることで、音声クローン機能の使い勝手を向上させる。

## What Changes

- `{LibraryParentDir}/voices/` フォルダを音声リファレンスファイルの格納場所として導入
- 設定UIのリファレンスファイル指定を、テキストフィールド＋ファイルピッカーからドロップダウンセレクターに変更
- `voices`フォルダ内の音声ファイル一覧を自動検出してドロップダウンに表示
- 対応フォーマットをWAVのみからWAV/MP3等の複数フォーマットに拡張
- C++ネイティブエンジン側のMP3等の音声読み込み対応（`load_audio_file`の拡張）
- 設定の保存形式をフルパスからファイル名のみに変更（`voices`フォルダからの相対参照）

## Capabilities

### New Capabilities
- `voice-reference-library`: `voices`フォルダの管理、音声ファイルの列挙、パス解決を担うケーパビリティ

### Modified Capabilities
- `tts-settings`: リファレンス音声の選択UIをファイルピッカーからドロップダウンに変更し、対応フォーマットを拡張
- `tts-native-engine`: `load_audio_file`でMP3等の追加フォーマットを読み込めるよう拡張

## Impact

- **UI**: `settings_dialog.dart` のTTSタブ - ファイルピッカーをドロップダウンに置き換え
- **状態管理**: `tts_settings_providers.dart` - ファイル一覧の取得とパス解決ロジックの追加
- **永続化**: `settings_repository.dart` - 保存形式の変更（フルパス→ファイル名）
- **ネイティブ**: `third_party/qwen3-tts.cpp` - MP3等のデコード対応（minimp3等のライブラリ追加の可能性）
- **ディレクトリ**: `novel_library_service.dart` - `voices`ディレクトリパスの解決ロジック追加
- **データベース**: `tts_episodes`/`tts_segments`テーブルの`ref_wav_path`カラム - 既存データとの互換性考慮
