## Context

現在 NovelViewer は Windows 環境で以下のようにデータを分散配置している：
- メタデータDB: `getDatabasesPath()` → カレントディレクトリ依存（`.dart_tool/sqflite_common_ffi/databases/`）
- テキストファイル: `getApplicationDocumentsDirectory()` → `C:\Users\<user>\Documents\NovelViewer\`

簡易ビューアツールとして、ポータブルな構成が望ましい。macOS は現状維持。

## Goals / Non-Goals

**Goals:**
- Windows 環境で exe と同じディレクトリにすべてのデータ（DB・テキスト）を配置する
- macOS/Linux の動作に影響を与えない
- `Platform.resolvedExecutable` を使用して exe のディレクトリを安定的に取得する

**Non-Goals:**
- 既存データの自動マイグレーション（開発中のため不要）
- macOS/Linux のデータ配置変更
- 設定によるデータディレクトリのカスタマイズ

## Decisions

### Decision 1: exe ディレクトリの取得方法

**選択: `Platform.resolvedExecutable` の親ディレクトリを使用**

`Platform.resolvedExecutable` はシンボリックリンクを解決した exe の絶対パスを返す。`p.dirname()` で親ディレクトリを取得する。

代替案:
- `Platform.executable`: シンボリックリンクを解決しないため不安定
- `Directory.current`: カレントディレクトリはショートカットの設定等で変わるため不適切

### Decision 2: Windows 判定と分岐ポイント

**選択: `NovelLibraryService` と `NovelDatabase` の各パス解決メソッド内で `Platform.isWindows` 分岐**

- `NovelLibraryService.resolveLibraryPath()`: Windows → exe ディレクトリ基準、macOS → 現状維持
- `NovelDatabase._open()`: Windows → exe ディレクトリに直接配置、macOS → `getDatabasesPath()` 現状維持

代替案:
- main.dart で一元的にパスを決定して DI する: 各クラスの責務が明確な現状の設計を崩す必要はない

### Decision 3: DB ファイルの配置場所

**選択: exe と同じディレクトリに `novel_metadata.db` を直接配置**

`.dart_tool/sqflite_common_ffi/databases/` のような中間ディレクトリは作らず、exe と同階層にフラットに配置する。シンプルで発見しやすい。

## Risks / Trade-offs

- [exe ディレクトリに書き込み権限がない場合] → Program Files 等に配置した場合は書き込めない。ただし本ツールは build 出力先や任意のフォルダに置く想定なので問題なし
- [開発時（flutter run）の挙動] → `Platform.resolvedExecutable` は `build\windows\x64\runner\Debug\novel_viewer.exe` を指すため、Debug フォルダにデータが配置される。開発環境としては許容範囲
