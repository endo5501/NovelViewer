# NovelViewer

Web小説サイト（なろう、カクヨム）から小説をダウンロードし、ローカルで閲覧するためのFlutterデスクトップアプリケーション。

## 機能

- **小説ダウンロード**: なろう（syosetu.com）、カクヨム（kakuyomu.jp）のURLを指定してエピソードを一括ダウンロード
- **ファイルブラウザ**: ダウンロードした小説をディレクトリ単位で閲覧・ナビゲーション
- **テキストビューア**: テキストファイルの内容を表示
- **3カラムレイアウト**: ファイルブラウザ（左）、テキストビューア（中央）、検索サマリ（右）の3カラム構成

## 前提条件

- [FVM](https://fvm.app/) (Flutter Version Management)
- Flutter stable channel（FVM経由で管理）

## セットアップ

```bash
# リポジトリをクローン
git clone <repository-url>
cd NovelViewer

# Flutter SDKのセットアップ（FVM経由）
fvm install

# 依存パッケージの取得
fvm flutter pub get
```

## ビルド・実行

```bash
# macOSで実行
fvm flutter run -d macos
# macOS向けReleaseビルド
fvm flutter build macos
```

## テスト

```bash
# 全テストを実行
fvm flutter test

# 特定のテストファイルを実行
fvm flutter test test/features/text_download/narou_site_test.dart
```

## リンター

`flutter_lints` パッケージによる静的解析を導入しています。コード修正後はリンターを実行して問題がないことを確認してください。

```bash
# 静的解析を実行
fvm flutter analyze
```

リントルールは `analysis_options.yaml` で設定されています。
