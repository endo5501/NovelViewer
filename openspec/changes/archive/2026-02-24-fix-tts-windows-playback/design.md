## Context

NovelViewerのTTS読み上げ機能は`just_audio`パッケージでWAVファイルを再生している。macOSでは`just_audio`が組み込みでプラットフォームサポートを提供するが、Windowsでは追加のプラットフォーム実装パッケージが必要。現状、Windows向けの実装パッケージが`pubspec.yaml`に含まれていないため、TTS合成は成功するが音声再生が行われない。

## Goals / Non-Goals

**Goals:**
- Windows環境でTTS音声再生を動作させる
- 既存のmacOS動作に影響を与えない
- 最小限の変更で対応する

**Non-Goals:**
- Linux対応（現時点ではスコープ外）
- 音声再生品質の改善
- TTS合成エンジン自体の修正

## Decisions

### 1. `just_audio_media_kit`を使用する（`just_audio_windows`ではなく）

**選択**: `just_audio_media_kit` + `media_kit_libs_windows_audio`

**理由**:
- `just_audio`の公式exampleが`just_audio_media_kit`を推奨している
- `just_audio_windows`は2024年9月以降更新がなく、メンテナンスが停滞している
- `just_audio_media_kit`は2025年4月にも更新されており、より活発にメンテナンスされている
- media_kit（libmpv）ベースで安定した再生が期待できる

**却下した選択肢**:
- `just_audio_windows`: WinRT MediaPlayer使用。メンテナンスが停滞しているためリスクが高い

### 2. 初期化は`main.dart`のWindows判定ブロックに追加

`main.dart`の`main()`関数内、`WidgetsFlutterBinding.ensureInitialized()`の後に`JustAudioMediaKit.ensureInitialized()`を呼び出す。既存のプラットフォーム判定ブロック付近に配置し、Windowsのみで有効化する。

### 3. macOSでは`just_audio_media_kit`を無効化

`JustAudioMediaKit.ensureInitialized()`の呼び出しで`windows: true`を明示し、macOSでは既存の組み込みサポートを使用し続ける。

## Risks / Trade-offs

- **media_kitの追加依存**: アプリサイズが若干増加する（libmpvのバイナリが含まれる） → 許容範囲内。音声再生のみに使用するため`media_kit_libs_windows_audio`（ビデオなし）を使用し最小化
- **初期化順序の問題**: `ensureInitialized()`は`WidgetsFlutterBinding.ensureInitialized()`の後に呼ぶ必要がある → `main.dart`の既存初期化フローに自然に組み込める
