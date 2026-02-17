# NovelViewer

Web小説サイトから小説をダウンロードし、ローカルで閲覧するためのノベルビューア

## 対応プラットフォーム

- macOS
- Windows
- Linux(未確認)

## 機能

- **横書き/縦書き表示切り替え**: 設定から表示モードを切り替え可能
- **テキスト検索**: ライブラリ内の全テキストを横断検索
- **ブックマーク**: ブックマークの登録・解除 
- **LLM要約**: 指定した単語をネタばれあり/なしを指定して確認可能  
(Ollama / OpenAI互換APIに対応)

![画面](images/view.png)

### LLM(Ollama)設定

1. Ollamaをダウンロード
2. 以下のように、使用したいモデルをダウンロード
```bash
ollama pull qwen3:8b
```
1. NovelVeiwerの設定画面にてLLMプロバイダを`Ollama`、エンドポイントURLに`http://localhost:11334`、モデル名にダウンロードしたモデル名(上記の場合、`qwen3:8b`)を設定

## 開発

### 前提条件

- [FVM](https://fvm.app/) (Flutter Version Management)
- Flutter stable channel（FVM経由で管理）

### セットアップ

```bash
# リポジトリをクローン
git clone git@github.com:endo5501/NovelViewer.git
cd NovelViewer

# Flutter SDKのセットアップ（FVM経由）
fvm install

# 依存パッケージの取得
fvm flutter pub get
```

### セットアップ:AI

Claude Code/Codex等コーディングエージェントを準備してください

```bash
# OpenSpec
npm install -g @fission-ai/openspec@latest

# Codex CLI
npm i -g @openai/codex

# superpowers (in Claude Code)
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

### ビルド・実行

```bash
# macOSで実行
fvm flutter run -d macos

# macOS向けReleaseビルド
fvm flutter build macos

# Windows向けReleaseビルド
fvm flutter build windows
```

### テスト

```bash
# 全テストを実行
fvm flutter test

# 特定のテストファイルを実行
fvm flutter test test/features/text_download/narou_site_test.dart
```

### リンター

`flutter_lints` パッケージによる静的解析を導入しています。コード修正後はリンターを実行して問題がないことを確認してください。

```bash
# 静的解析を実行
fvm flutter analyze
```

リントルールは `analysis_options.yaml` で設定されています。

### リリース

タグ（`v*`パターン）をpushすると、GitHub ActionsによりWindows版の自動ビルド・リリースが実行されます。

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 技術スタック

- **フレームワーク**: Flutter (Dart)
- **状態管理**: Riverpod
- **データベース**: SQLite (sqflite / sqflite_common_ffi)
- **設定永続化**: SharedPreferences
- **HTTP通信**: http パッケージ
- **HTMLパース**: html パッケージ
