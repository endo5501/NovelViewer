## Context

NovelViewerはダウンロード済み小説のメタデータ（URL含む）をSQLiteに保存している。`DownloadService`はエピソードキャッシュの`last_modified`ヘッダーによる差分検出を既にサポートしており、`NovelRepository.upsert()`は既存レコードの更新にも対応済み。現在の課題は、これらの既存機能を活用する「更新」UIが存在しないことのみ。

## Goals / Non-Goals

**Goals:**

- ライブラリルートの小説フォルダの右クリックコンテキストメニューに「更新」オプションを追加する
- 保存済みURLを使って既存の`DownloadNotifier.startDownload()`を呼び出し、差分ダウンロードを実行する
- 更新中の進捗をダイアログで表示する
- 更新完了後、ファイル一覧とメタデータを自動リフレッシュする

**Non-Goals:**

- 自動更新・定期更新（スケジュール機能）
- 更新のバックグラウンド実行
- DownloadServiceやNovelRepositoryの既存ロジックの変更

## Decisions

### 1. UIの配置: 既存コンテキストメニューに追加

右クリックコンテキストメニュー（現在「削除」のみ）に「更新」項目を追加する。

**理由**: 既にGestureDetector + showMenuのパターンが実装済みで、小説フォルダに対する操作として自然な位置。ツールバーやFABに比べてUI変更が最小限で済む。

**代替案**:
- ツールバーにボタン追加 → 現在のUI構成では「選択中の小説フォルダ」の概念がツールバーレベルにないため不適切
- フォルダ名横にアイコンボタン追加 → ListTile構成の大幅な変更が必要

### 2. 更新ロジック: `DownloadNotifier`に`refreshNovel`メソッドを追加

`DownloadNotifier`に`refreshNovel(String folderName)`メソッドを追加する。内部で`NovelRepository.findByFolderName()`で保存済みURLを取得し、既存の`startDownload()`を呼び出す。

**理由**: 既存の`startDownload`がupsertロジック・キャッシュ・進捗コールバックをすべて処理済み。新しいProviderやServiceの作成は不要で、1メソッド追加で完結する。

**代替案**:
- 専用の`RefreshNotifier`を新規作成 → `startDownload`とほぼ同じロジックの重複になる
- `DownloadService`にリフレッシュメソッド追加 → Providerレイヤーでのメタデータ取得が必要なため、Notifier側で処理する方が適切

### 3. 進捗表示: ダウンロードダイアログと同様のパターン

更新開始時にモーダルダイアログを表示し、`DownloadState`を監視して進捗を表示する。完了/エラー時にダイアログを自動更新する。

**理由**: 既存の`DownloadDialog`が`downloadProvider`を監視するパターンを踏襲でき、ユーザーに一貫したUXを提供する。モーダルにすることで更新中の他操作を防ぐ。

### 4. ライブラリパスの取得

`refreshNovel`メソッドは`libraryPathProvider`から出力パスを取得する。`DownloadNotifier`は既にNotifierでありrefにアクセス可能。

## Risks / Trade-offs

- **[DownloadNotifierの状態競合]** → 既存のダウンロードと更新が同時に実行される可能性がある。対策: 更新開始前に`DownloadStatus.idle`をチェックし、実行中であれば処理しない。
- **[folderNameが見つからない場合]** → `findByFolderName`がnullを返す可能性がある（手動でフォルダを作成した場合など）。対策: エラーメッセージを表示して処理を中断する。
