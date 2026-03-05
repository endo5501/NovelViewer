## Context

qwen3-tts.cpp エンジンは10言語をサポートしており、C API に `qwen3_tts_set_language(ctx, language_id)` が実装済み。Dart 側の FFI バインディング (`tts_native_bindings.dart`) にも `setLanguage` が定義済み。しかし、`tts_engine.dart` では `languageJapanese = 2058` のみが定数定義され、`tts_isolate.dart` の `loadModel` でハードコーディングされている。

設定UIは Riverpod + SharedPreferences パターンで統一されており、既存の `ttsModelSizeProvider` / `ttsRefWavPathProvider` と同じ構造で言語設定を追加できる。

## Goals / Non-Goals

**Goals:**
- 設定画面の読み上げタブで10言語から選択可能にする
- 選択した言語をSharedPreferencesに永続化する
- TTS エンジン初期化時に選択言語を反映する
- デフォルトは日本語を維持する

**Non-Goals:**
- 言語の自動検出（テキストの言語を解析して自動切替）
- エピソードごとの言語設定
- C++ エンジン側のコード変更（既にマルチ言語対応済み）

## Decisions

### 1. 言語モデルとして enum を使用

言語を `TtsLanguage` enum で定義し、各値に `languageId` (int) と `displayName` (String) を持たせる。

**理由**: 既存の `TtsModelSize` enum パターンと統一性を保ち、型安全性を確保。language_id のマジックナンバーを排除。

**代替案**: Map<String, int> で管理する案 → 型安全性が低く、既存パターンと不一致。

### 2. 設定の永続化キー: `tts_language`

SharedPreferences に enum の `name` プロパティ（例: `"ja"`, `"en"`）を保存する。

**理由**: 人間が読みやすく、language_id (整数) より安定。enum 値の変更に強い。

### 3. 言語変更はモデル再ロード不要

`qwen3_tts_set_language()` は既にロード済みのコンテキストに対して言語を変更可能。モデルの再ロードは不要。

**理由**: C API の実装を確認済み。`setLanguage` はコンテキストの `language_id` フィールドを更新するだけ。

### 4. UIコンポーネント: DropdownButtonFormField

モデルサイズ選択で使われている SegmentedButton は選択肢が2つの場合に適しているが、10言語には不向き。ドロップダウンを使用する。

**理由**: 10項目の選択には DropdownButtonFormField が UX 的に最適。

## Risks / Trade-offs

- [言語切替タイミング] TTS 生成中に言語を変更した場合の挙動 → 生成中は設定変更を反映せず、次回生成時から適用。`TtsIsolate` に `SetLanguageMessage` を追加し、モデルロード後いつでも言語変更可能にする。
- [言語と音声の不一致] 日本語テキストに英語の言語設定で読み上げると品質が低下する → UIで注意書きは不要（ユーザーが明示的に選択する設定のため）。
