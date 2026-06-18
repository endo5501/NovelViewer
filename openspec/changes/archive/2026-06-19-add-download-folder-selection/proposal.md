## Why

現在、小説をダウンロードすると保存先が常にライブラリのルートフォルダに固定されており、ユーザーが整理用に作成したサブフォルダへ直接保存できない。ライブラリはすでに小説フォルダのネスト（任意の深さ）に対応している（leaf名による判定・パス解決）にもかかわらず、ダウンロード経路だけがルート固定という非対称な状態になっている。ユーザーがダウンロード時に保存先フォルダを選べるようにし、整理の手間（ダウンロード後に手動で移動する操作）をなくす。

## What Changes

- ダウンロードダイアログに「保存先フォルダ」の選択UIを追加する。ライブラリルート配下の既存サブフォルダ（整理用フォルダ）から選択でき、既定はライブラリルート（現状互換）とする。
- 選択された保存先を `DownloadNotifier.startDownload` の `outputPath` として渡し、小説フォルダ（`{siteType}_{novelId}`）を選択フォルダ配下に作成する。
- **更新（refresh）整合性の修正**: サブフォルダに保存された小説を「更新」した際、ルート直下に重複ダウンロードするのではなく、その小説が物理的に存在する場所に上書き再ダウンロードする。`refreshNovel` の呼び出し元が保持する物理パスを利用して保存先を解決する。
- 新規に追加されるユーザー可視文字列は en/ja/zh の `.arb` で完全な対訳を提供する。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `text-download`: 「Download save location」要件を変更する。常にライブラリルートへ保存するのではなく、ダウンロード時にユーザーが指定したライブラリ配下のフォルダへ保存できるようにする。未指定（既定）の場合はライブラリルートへ保存する従来動作を維持する。Windows/macOS/Linux のライブラリルート解決ロジック自体は不変。
- `novel-refresh`: 「Refresh triggers download with stored URL」要件を変更する。更新の再ダウンロード先を、ルート固定ではなく対象小説の現在の物理フォルダ位置に解決する。

## Impact

- UI: `lib/features/text_download/presentation/download_dialog.dart`（保存先選択UIの追加）
- Provider: `lib/features/text_download/providers/text_download_providers.dart`（`refreshNovel` の保存先解決の修正）
- 呼び出し元: `lib/features/file_browser/presentation/file_browser_panel.dart`（refresh呼び出し時に物理パスを渡す）
- サブフォルダ列挙: `lib/features/file_browser/data/file_system_service.dart`（`listSubdirectories` 等の既存APIを利用）
- ローカライズ: `lib/l10n/*.arb`（保存先選択UIの文字列追加、en/ja/zh）
- スキーマ変更なし（`novel_metadata.db` のマイグレーション不要 — 物理位置はDBに保存しない、既存の「leaf名主義」設計を維持）
