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
```

## テスト

```bash
# 全テストを実行
fvm flutter test

# 特定のテストファイルを実行
fvm flutter test test/features/text_download/narou_site_test.dart
```

## プロジェクト構成

```
lib/
├── main.dart                          # エントリポイント（デフォルトディレクトリの初期化）
├── app.dart                           # MaterialApp定義
├── home_screen.dart                   # 3カラムレイアウト・AppBar
└── features/
    ├── file_browser/                  # ファイルブラウザ機能
    │   ├── data/                      #   ファイルシステム操作
    │   ├── providers/                 #   Riverpod状態管理
    │   └── presentation/             #   UIウィジェット
    ├── text_download/                 # 小説ダウンロード機能
    │   ├── data/
    │   │   ├── sites/                #   サイトごとのHTMLパーサー
    │   │   ├── download_service.dart #   ダウンロード・ファイル保存
    │   │   └── novel_library_service.dart  # デフォルトディレクトリ管理
    │   ├── providers/                #   ダウンロード状態管理
    │   └── presentation/            #   ダウンロードダイアログ
    ├── text_viewer/                   # テキスト表示機能
    └── settings/                      # 設定機能
```

## 技術スタック

- **フレームワーク**: Flutter (Dart)
- **状態管理**: Riverpod
- **HTTPクライアント**: http パッケージ
- **HTML解析**: html パッケージ
- **対象プラットフォーム**: macOS（デスクトップ）
