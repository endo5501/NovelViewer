## Context

TTS音声MP3エクスポート機能は `export-tts-audio-mp3` changeとしてWindows向けに実装済み。Dartコード（`lame_enc_bindings.dart`）は `Platform.isMacOS` に対応しており `liblame_enc_ffi.dylib` を返す。dylib自体も `macos/Frameworks/liblame_enc_ffi.dylib`（arm64）としてビルド済み。

macOSで動作しない原因は2つ:

1. **エンタイトルメント**: `com.apple.security.files.user-selected.read-only` のため、`FilePicker.platform.saveFile()` が `NSSavePanel` を開けずnullを返す。コード上は `savePath == null → return false → silent return` となり、ユーザーには何も起きないように見える。
2. **dylibバンドル**: Xcodeビルドフェーズ「Embed TTS Library」が `libqwen3_tts_ffi.dylib` のみをコピーしており、`liblame_enc_ffi.dylib` がアプリバンドルに含まれない。

## Goals / Non-Goals

**Goals:**

- macOSでMP3エクスポートのファイル保存ダイアログが正常に開く
- macOSアプリバンドルに `liblame_enc_ffi.dylib` が含まれ、ランタイムで正常にロードされる
- 既存のWindows動作に影響を与えない

**Non-Goals:**

- Dartコードの変更（既にmacOS対応済み）
- macOS向けのCI/CDパイプライン追加
- dylibの再ビルド（既にビルド済み）

## Decisions

### 1. エンタイトルメントの変更: `read-only` → `read-write`

**選択**: `DebugProfile.entitlements` と `Release.entitlements` の両方で `com.apple.security.files.user-selected.read-only` を `com.apple.security.files.user-selected.read-write` に変更する。

**理由**: `file_picker` パッケージの `saveFile()` は macOS の `NSSavePanel` を使用し、`read-write` エンタイトルメントが必要。`read-write` は `read-only` の上位互換であり、既存のファイル読み取り操作（設定画面のディレクトリ選択 `getDirectoryPath()`）に影響しない。

### 2. dylibバンドル: 既存のビルドフェーズスクリプトを拡張

**選択**: Xcodeの「Embed TTS Library」ビルドフェーズのシェルスクリプトに `liblame_enc_ffi.dylib` のコピーとcodesignを追加する。

現在のスクリプト:
```bash
DYLIB_SRC="${SRCROOT}/Frameworks/libqwen3_tts_ffi.dylib"
DYLIB_DST="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
if [ -f "$DYLIB_SRC" ]; then
  mkdir -p "$DYLIB_DST"
  cp "$DYLIB_SRC" "$DYLIB_DST/"
  codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" "$DYLIB_DST/libqwen3_tts_ffi.dylib" || true
fi
```

変更後のスクリプト:
```bash
DYLIB_DST="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
mkdir -p "$DYLIB_DST"

for DYLIB_NAME in libqwen3_tts_ffi.dylib liblame_enc_ffi.dylib; do
  DYLIB_SRC="${SRCROOT}/Frameworks/${DYLIB_NAME}"
  if [ -f "$DYLIB_SRC" ]; then
    cp "$DYLIB_SRC" "$DYLIB_DST/"
    codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" "$DYLIB_DST/${DYLIB_NAME}" || true
  fi
done
```

**代替案**: dylib毎に個別のif文を追加する方法もあるが、ループ化することで将来さらにdylibが増えた場合も1行追加で済む。

**理由**: 既存のビルドフェーズの責務「ネイティブライブラリの埋め込み」に合致。新しいビルドフェーズを追加するよりもシンプル。ビルドフェーズ名は「Embed TTS Library」→「Embed Native Libraries」に変更し、汎用的な役割を反映する。

## Risks / Trade-offs

- **`read-write` への変更範囲** → `read-write` は `read-only` の完全な上位集合。既存機能への悪影響なし。macOS App Store審査での追加確認が必要になる可能性はあるが、ファイル保存はユーザー起点の操作であり正当な用途。
- **ビルドフェーズスクリプト変更** → `project.pbxproj` のシェルスクリプト文字列を直接編集する必要がある。エスケープに注意が必要だが、既存パターンが確立されており低リスク。
