## Context

NovelViewer はリファレンス音声ファイルを `voices/` ディレクトリで管理し、TTS のボイスクローニングに使用している。現在、リファレンス音声の追加手段はファイルのドラッグ&ドロップまたは `voices/` フォルダへの手動コピーのみ。ユーザーが自分や他者の声をクローンしたい場合、外部ツールで録音してからインポートする必要があり手間がかかる。

既存のアーキテクチャ:
- `VoiceReferenceService` が `voices/` ディレクトリのファイル管理（一覧・追加・リネーム）を担当
- `SettingsDialog` の `_buildVoiceReferenceSelector()` がリファレンス音声選択 UI を提供
- 音声再生には `just_audio` + `just_audio_media_kit` を使用
- 状態管理は Riverpod を使用

## Goals / Non-Goals

**Goals:**
- 設定画面から直接マイク録音でリファレンス音声を作成・保存できる
- 録音中の状態（経過時間、波形レベル）をユーザーにフィードバックする
- 録音完了後にファイル名を指定して `voices/` フォルダに保存する
- macOS および Windows の両プラットフォームで動作する

**Non-Goals:**
- 録音した音声の編集機能（トリミング、ノイズ除去など）
- 録音音声のプレビュー再生機能（将来的に追加可能だが今回はスコープ外）
- 録音品質（サンプルレート、ビット深度）のカスタマイズ
- モバイルプラットフォーム対応

## Decisions

### 1. 録音パッケージの選定: `record` パッケージ

**選択**: [`record`](https://pub.dev/packages/record) パッケージを採用

**理由**:
- macOS、Windows の両方をサポート
- WAV 形式での録音に対応
- 録音中の音声レベル（振幅）のストリーム取得に対応し、UI フィードバックに利用できる
- Flutter デスクトップでの録音用途として広く使われている

**検討した代替案**:
- `flutter_sound`: モバイル向けが主で、デスクトップサポートが限定的
- `audioplayers` + ネイティブコード: 自前実装のメンテナンスコストが高い

### 2. 録音フォーマット: WAV (PCM 16-bit, 16kHz, mono)

**選択**: WAV フォーマット、16kHz サンプルレート、16-bit PCM、モノラル

**理由**:
- TTS エンジン（Qwen3-TTS）のリファレンス音声として一般的なフォーマット
- 非圧縮形式のため品質劣化がない
- `voices/` ディレクトリで既にサポートされている拡張子（`.wav`）

### 3. アーキテクチャ: 録音ダイアログとして分離

**選択**: 録音 UI を独立したダイアログ (`VoiceRecordingDialog`) として実装

**理由**:
- 設定画面の `_buildVoiceReferenceSelector()` 内に録音 UI を直接埋め込むと、状態管理が複雑になる
- ダイアログとして分離することで、録音のライフサイクル（開始・停止・保存・キャンセル）を明確に管理できる
- `SettingsDialog` には録音ボタンのみを追加し、押下時にダイアログを表示する

**検討した代替案**:
- インラインUI（設定画面内に直接展開）: 設定画面のレイアウトが複雑化するため不採用

### 4. サービス層: `VoiceRecordingService` を新規作成

**選択**: `VoiceReferenceService` とは別に `VoiceRecordingService` を新規作成

**理由**:
- 単一責任の原則: `VoiceReferenceService` はファイル管理、`VoiceRecordingService` は録音操作を担当
- 録音サービスは `record` パッケージの `AudioRecorder` をラップし、録音開始・停止・一時ファイル管理を提供
- 録音完了後のファイル保存は既存の `VoiceReferenceService.addVoiceFile()` を活用するのではなく、一時ファイルから直接 `voices/` に保存（`addVoiceFile` はコピーのため中間ファイルが不要な場合は直接リネーム/移動が効率的）

### 5. macOS 権限設定

**必要な変更**:
- `Info.plist`: `NSMicrophoneUsageDescription` キーを追加（マイクアクセス許可ダイアログの説明文）
- `DebugProfile.entitlements`: `com.apple.security.device.audio-input` を追加
- `Release.entitlements`: `com.apple.security.device.audio-input` を追加

現在の entitlements にはオーディオ入力の権限がないため、追加が必須。

### 6. 録音フロー

```
[録音ボタン押下] → [VoiceRecordingDialog 表示]
  → [録音開始ボタン] → 録音中（経過時間・音声レベル表示）
  → [停止ボタン] → 一時ファイルに WAV 保存
  → [ファイル名入力ダイアログ] → バリデーション（重複チェック）
  → [保存] → voices/ に移動 → ファイルリスト更新 → ダイアログ閉じる
```

### 7. WAVE_FORMAT_EXTENSIBLE 対応（C++ WAV パーサー）

**問題**: macOS の `record` パッケージは WAV ファイルを `WAVE_FORMAT_EXTENSIBLE` (format code 0xFFFE) ヘッダーで生成する。TTS エンジン（Qwen3-TTS）の C++ WAV パーサー (`qwen3_tts.cpp`) は format code 1 (PCM) と 3 (IEEE float) のみ対応しており、録音した WAV ファイルを読み込めない。

**選択**: C++ WAV パーサーに `WAVE_FORMAT_EXTENSIBLE` 対応を追加

**理由**:
- `WAVE_FORMAT_EXTENSIBLE` は PCM/IEEE float のラッパー形式。拡張ヘッダの SubFormat GUID 先頭 2 バイトに実際の format code が格納されている
- パーサー側で対応することで、`record` パッケージ以外が生成した EXTENSIBLE 形式の WAV にも対応できる
- Dart 側で WAV ヘッダーを書き換える方法と比較して、確実かつ汎用的

**修正箇所**:
- `third_party/qwen3-tts.cpp/src/qwen3_tts.cpp` - メインライブラリの `load_wav_file`
- `third_party/qwen3-tts.cpp/tests/test_encoder.cpp` - テスト用ローダー
- `third_party/qwen3-tts.cpp/scripts/compare_e2e.py` - Python 比較スクリプト

## Risks / Trade-offs

- **マイク権限拒否** → ユーザーがマイクアクセスを拒否した場合、録音ボタン押下時にエラーメッセージを表示。`record` パッケージの `hasPermission()` で事前チェックする
- **`record` パッケージの互換性** → デスクトップ対応は比較的新しいため、プラットフォーム固有の問題が発生する可能性がある。初期実装で macOS を優先検証し、Windows は追って確認する
- **一時ファイルの残留** → 録音後にユーザーがキャンセルした場合、一時ファイルを確実に削除する必要がある。`VoiceRecordingDialog` の dispose で一時ファイルのクリーンアップを行う
- **録音中のダイアログ閉じ操作** → `WillPopScope` (または `PopScope`) でダイアログの意図しない閉じ操作を防ぎ、録音中の場合は確認を求める
- **WAV フォーマット互換性** → `record` パッケージが生成する WAV のヘッダ形式はプラットフォーム依存。macOS では `WAVE_FORMAT_EXTENSIBLE` が使用されるため、TTS エンジン側のパーサーで対応が必要
