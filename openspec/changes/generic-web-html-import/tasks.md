## 1. 事前確定（Open Questions の決着）

- [x] 1.1 本文「短すぎる」判定の最小文字数閾値を決める（200字に確定）。決定値を design に反映
- [x] 1.2 コレクション名スラッグ生成規則を決める（`web_${safeName(name)}`＋衝突サフィックス `_2,_3...`）。決定を design に反映
- [x] 1.3 エピソードファイル名の固定ゼロ埋め幅の桁数を決める（4桁固定）。決定を design に反映
- [x] 1.4 密度スコアのリンク減点係数 `k` と候補要素の絞り込み初期値を決める（k=1.0・直下<p>テキスト基準、定数化）

## 2. 本文抽出ヒューリスティック（generic-web-import）

- [x] 2.1 [テスト] ノイズ除去（script/style/nav/header/footer/aside/form）のテストを書き、失敗を確認
- [x] 2.2 [テスト] セマンティック優先（article/main/[role=main]）→ CMS定番セレクタ → 密度フォールバックの選択順テストを、固定HTMLフィクスチャで書き、失敗を確認
- [x] 2.3 [テスト] `<ruby>` 保持・`<br>` 改行の踏襲テストを書き、失敗を確認
- [x] 2.4 `GenericWebSite` の本文抽出（除去→セマンティック→CMS定番→密度）を実装し、2.1–2.3 を通す（既存 `blockToText`/`extractParagraphText` を再利用）
- [x] 2.5 [テスト] タイトル決定（og:title → h1 → title）のテストを書き、失敗を確認
- [x] 2.6 タイトル決定を実装し 2.5 を通す

## 3. 文字コード判定（generic-web-import）

- [x] 3.1 [テスト] Content-Type charset → `<meta charset>` → 既定UTF-8 の優先順テスト（Shift_JIS 個人ブログのフィクスチャ含む）を書き、失敗を確認
- [x] 3.2 `decodeBody` のオーバーライドで多段文字コード判定を実装し 3.1 を通す

## 4. レジストリ統合と空ガード（generic-web-import）

- [x] 4.1 [テスト] フォールバック受理（専用サイト優先・末尾で web 受理・非webスキーム拒否）のレジストリ解決テストを書き、失敗を確認
- [x] 4.2 `NovelSiteRegistry._sites` 末尾に `GenericWebSite` を追加し 4.1 を通す
- [x] 4.3 [テスト] 抽出が空/閾値未満なら `bodyContent=null` に倒すテストを書き、失敗を確認（`EmptyIndexException` 連携は download_service 既存ガードで担保）
- [x] 4.4 空/短すぎガードを実装し 4.3 を通す（既存 download_service の `EmptyIndexException` 経路に合流）
- [x] 4.5 抽出失敗時のエラー文言（JS描画ページの可能性を示唆）を整備し、ダイアログのエラー表示に反映（startCollectionDownload の EmptyIndexException 分岐で実装）
- [x] 4.6 挙動変化に伴う既存テスト更新（url_validation F119・download_dialog の「非対応URL」前提）→ web へ解決する新挙動に更新。design D9 に整理を明記

## 5. コレクションへの追記と採番（web-collection-download）

- [x] 5.1 [テスト] 新規コレクション作成（siteType='web'、フォルダ＝名前スラッグ、衝突サフィックス）のテストを書き、失敗を確認
- [x] 5.2 [テスト] 既存コレクションへの追記で `max(episode_index)+1` 採番・末尾追加・既存ファイル名不変（固定4桁）のテストを書き、失敗を確認
- [x] 5.3 download_service にコレクション追記フロー（`createCollectionDirectory`／`downloadArticleIntoCollection`／固定幅命名）を実装し 5.1–5.2 を通す
- [x] 5.4 [テスト] 記事タイトルがエピソードタイトルになることのテストを書き、実装して通す

## 6. 同一URL更新（web-collection-download）

- [x] 6.1 [テスト] 同一コレクションへの同一URL再取得で該当エピソードを上書き更新し、重複追加しない（タイトル変更時は旧ファイル削除）テストを書き、失敗を確認
- [x] 6.2 [テスト] 別コレクションへの同一URLは独立エピソードになる（各フォルダが独立 episode_cache を持つ）テストを書き、失敗を確認
- [x] 6.3 episode_cache（url 主キー）を用いた更新/採番ロジックを実装し 6.1–6.2 を通す

## 7. 取り込み先選択UI（web-collection-download）

- [x] 7.1 [テスト] ダイアログの取り込み先モード（新規/既存）切替UIが web URL で表示されるウィジェットテストを書き、実装して通す（既定名＝タイトルは provider 層: 空欄時 article.title を採用）
- [x] 7.2 [テスト] 既存コレクション候補が `siteType='web'` に限定される（専用サイト作品が出ない）テストを書き、実装して通す
- [x] 7.3 ダウンロードダイアログに取り込み先選択UI（web→コレクション、専用→従来宛先の分岐）を実装し 7.1–7.2 を通す
- [x] 7.4 事前バリデーション無効化に伴うダイアログ挙動を確認・調整（web は _isWebArticle 分岐で startCollectionDownload へ）

## 8. 空コレクションの事前作成（web-collection-download）

- [x] 8.1 空 web コレクション作成 provider（`createEmptyCollection`：folder＋episodeCount=0 metadata）を実装
- [x] 8.2 ライブラリ（home_screen ツールバー）に「新規コレクション」アクション＋名前入力ダイアログを実装

## 9. 統合確認（下流の無改修動作）

- [x] 9.1 複数記事を持つ web コレクションが `{4桁}_{タイトル}.txt` の標準レイアウトになることを collection_download_test で確認（LLM解析の `runAnalysis` はフォルダ内全 .txt を横断するため、基礎記事のファクトが応用記事解析に現れる）。実機での最終確認は Section 10 後に推奨
- [x] 9.2 web コレクションは既存の複数エピソード作品と同一のフォルダ構造のため、TTS・検索・閲覧が無改修で扱える（構造的保証＋既存スイートで担保）

## 10. 最終確認

- [ ] 10.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 10.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 10.3 `fvm flutter analyze`でリントを実行
- [ ] 10.4 `fvm flutter test`でテストを実行
