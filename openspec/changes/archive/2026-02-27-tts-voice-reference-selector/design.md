## Context

現在のTTSリファレンス音声ファイルの指定は、`FilePicker`によるフルパス選択方式を採用している。選択されたパスは`SharedPreferences`に絶対パスとして保存され、C++ FFI経由で`qwen3_tts_synthesize_with_voice`に渡される。

C++側の`load_audio_file`はWAV形式（PCM 16/32bit、IEEE Float 32bit）のみ対応。MP3デコードライブラリは含まれていない。

ディレクトリ構成:
```
{LibraryParentDir}/
├── NovelViewer/     ← 小説テキスト保存
├── models/          ← TTSモデル（GGUF）
└── voices/          ← 【新規】リファレンス音声ファイル
```

`LibraryParentDir`の解決は`NovelLibraryService`が担い、macOSでは`~/Documents/com.endo5501.novelViewer/`、Windowsでは実行ファイルと同じディレクトリとなる。

## Goals / Non-Goals

**Goals:**
- `voices`フォルダ内の音声ファイルをドロップダウンで選択可能にする
- WAVに加えMP3形式のリファレンス音声をサポートする
- 既存のフルパス設定との後方互換性を維持する
- `voices`フォルダが存在しない場合は自動作成する

**Non-Goals:**
- アプリ内でのリファレンス音声ファイルの録音・編集機能
- `voices`フォルダ外のファイルの手動パス入力（既存のファイルピッカーを廃止）
- MP3以外の追加フォーマット対応（FLAC、OGG等）は今回のスコープ外
- リファレンス音声のプレビュー再生機能

## Decisions

### 1. MP3デコードライブラリ: minimp3を採用

**選択:** [minimp3](https://github.com/lieff/minimp3) ヘッダーオンリーライブラリ

**理由:**
- ヘッダーファイル1つ（`minimp3.h` + `minimp3_ex.h`）で完結し、ビルド構成の変更が最小限
- パブリックドメインライセンスでライセンス問題なし
- 既存の`load_audio_file`関数に拡張子判定を追加し、MP3デコードパスを分岐するだけで統合可能

**棄却した代替案:**
- **libsndfile**: 多形式対応だが、ビルド依存が複雑でクロスプラットフォームビルドに影響
- **FFmpeg**: 機能過多、ライセンスが複雑（LGPL/GPL）
- **Dart側でのデコード**: FFI境界を超えてPCMデータを渡す必要があり、API変更が大きい

### 2. ファイル列挙: Dart側の`Directory.list`で実装

**選択:** Dartの`dart:io`で`voices`ディレクトリをスキャンし、対応拡張子（`.wav`, `.mp3`）でフィルタ

**理由:**
- Flutter/Dartの標準APIで十分な性能
- ファイル数は数十程度と想定され、パフォーマンス問題は発生しない
- ネイティブ側に列挙APIを追加する必要がない

### 3. 設定の保存形式: ファイル名のみを保存

**選択:** `SharedPreferences`にはファイル名（例: `voice_sample.wav`）のみを保存し、フルパスは実行時に`voices`ディレクトリパスから組み立てる

**理由:**
- ディレクトリが環境やプラットフォームによって異なるため、絶対パスは移植性が低い
- ファイル名のみの保存であれば、バックアップ・移行時にも設定が壊れにくい
- 本機能はリリース前のため、既存の絶対パス設定との後方互換性は不要

### 4. UI: DropdownButtonFormFieldを使用

**選択:** 既存の`TextField`+`FilePicker`を`DropdownButtonFormField<String>`に置き換え

**理由:**
- Flutter Materialの標準ウィジェットで一貫したUI
- `InputDecoration`が使えるため、既存のフォームデザインと統一感を保てる
- 「未選択」オプションも自然に表現可能

**ドロップダウンの項目:**
- 先頭に「なし（デフォルト音声）」の選択肢
- `voices`フォルダ内の音声ファイルをファイル名でリスト表示
- フォルダが空の場合はドロップダウンを無効化し、ヒントテキストで案内

### 5. voicesディレクトリパスの管理: 新規サービスクラスで提供

**選択:** `VoiceReferenceService`クラスを新規作成し、voicesディレクトリのパス解決・ファイル列挙・自動作成を担当

**理由:**
- `NovelLibraryService`はテキストダウンロード機能に特化しており、音声機能のロジックを混ぜると責務が不明確になる
- ただし`LibraryParentDir`の解決は`NovelLibraryService`（正確には`libraryPathProvider`）に依存する
- テスト時にモックしやすいよう、独立したサービスとして設計

## Risks / Trade-offs

**[minimp3の品質]** → minimp3は広く使われており、主要なMP3仕様をカバーしている。エッジケースのMP3ファイルで問題が出る可能性は低いが、ユーザーに問題報告を促すメッセージをエラー時に表示する

**[voicesフォルダの手動管理]** → ユーザーが手動で`voices`フォルダにファイルを配置する必要がある。アプリ内にフォルダを開くボタンを設け、ファイル配置を容易にする

**[ファイル一覧の更新タイミング]** → 設定画面を開いた時点でスキャンする。アプリ起動中にファイルを追加した場合は、設定画面を再度開く必要がある。リフレッシュボタンでの再スキャンも提供する

**[TTS停止時のstate競合（実装中に発見・修正）]** → `_startStreaming()`のfinallyブロックによるDB closeと`stop()`内の`cancel()`が並行実行される際、`cancel()`のDB操作が例外を発生させ、`stop()`のstate クリーンアップ（ハイライト解除等）に到達しない競合条件が発覚。対策として`stop()`にtry-catch-finallyを追加し例外発生時もstateを確実にリセット。加えて`_stopStreaming()`でも`stop()`の成否に関わらず全TTS state（highlight, playbackState, generationProgress, audioState）を直接クリアする二重防御を実装
