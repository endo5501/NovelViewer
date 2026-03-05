## Why

TTS エンジン (qwen3-tts.cpp) は10言語 (en, ru, zh, ja, ko, de, fr, es, it, pt) をサポートしているが、アプリケーション側では日本語 (language_id=2058) がハードコーディングされており、他言語での読み上げができない。海外の小説や多言語コンテンツを扱うユーザーのために、設定画面から言語を切り替えられるようにする。

## What Changes

- 設定画面の「読み上げ」タブに言語選択ドロップダウンを追加
- 選択された言語をSharedPreferencesに永続化
- TTS エンジン初期化時に選択言語のlanguage_idを渡すよう変更
- デフォルトは日本語 (ja) を維持

## Capabilities

### New Capabilities

- `tts-language-selection`: TTS読み上げ言語の選択・永続化・エンジンへの反映

### Modified Capabilities

- `tts-settings`: 読み上げタブに言語選択UIを追加

## Impact

- `lib/features/settings/presentation/settings_dialog.dart` - 言語選択UIの追加
- `lib/features/settings/data/settings_repository.dart` - 言語設定の永続化
- `lib/features/tts/providers/tts_settings_providers.dart` - 言語設定のプロバイダー追加
- `lib/features/tts/data/tts_engine.dart` - 言語定数の拡充
- `lib/features/tts/data/tts_isolate.dart` - 言語設定の動的渡し
- `lib/features/tts/data/tts_generation_controller.dart` - 言語設定の参照
