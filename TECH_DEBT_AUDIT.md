# Tech Debt Audit — NovelViewer

Generated: 2026-06-11（第2回。前回: 2026-04-29、`lib/` のみ対象・58件）
Scope: リポジトリ全体（lib/ 約22,000 LOC + test/ + scripts/ + .github/ + installer/ + ドキュメント）
Method: モジュール別に6並列の監査エージェント（text_viewer系 / tts / download・search / DB・file_browser系 / settings・LLM・update系 / 横断）+ `fvm flutter analyze`（指摘ゼロ）

> **前回監査との関係:** 前回の58件は `TECH_DEBT_AUDIT_RESOLUTION.md` により37件Resolved / 20件Deferred / 1件部分対応と記録されており、今回の調査でも解決済み項目の再燃は確認されなかった（Sprint 1–5 のリファクタは実際に定着している）。本書の指摘はすべて **NEW**。ただし前回 Deferred のうち今回再浮上したものは `再掲(F0xx)` と注記した。旧ID（F001–F058）との衝突を避けるため、今回は **F101から採番** する。

## Executive summary

1. **最大のテーマは「静かな失敗」**: TTS合成失敗がエラー表示ゼロで `completed` 扱いになり（F101）、ダウンロードは目次2ページ目以降の取得失敗を握り潰して「完了」と報告し（F102）、サイト改修で空になったエピソードを保存して永久キャッシュする（F105）。自動更新の失敗も空catchで消える（F140）。エラーは起きているのにUIにもログにも届かない構造が複数機能を貫通している。
2. **小説の同一性（novel_id）の契約が壊れている**: フォルダ管理機能でネスト配置が可能になった後も、ブックマーク/読書進捗は「ライブラリ直下の第1セグメント」をキーにしており（F106）、ネストされた小説の移動でデータが孤児化する。小説削除はブックマークをカスケードしない（F107）。絶対パス保存も移動/リネームで壊れる（F128）。
3. **DBハンドルのライフサイクルがUI層の振り付け頼み**: commit 81ca506 で直したのは削除フローのみで、move/rename/空フォルダ削除には同じ「fire-and-forget invalidate がファイル操作とレースする」パターンが残っている（F108）。根本はDBラッパーに open/close のインターロックがないこと（F124）。
4. **縦書きビューアはビルド毎に全文再ページネーション+マーク再計算**: TTSハイライトの1ティックごとに小説全体の禁則処理・段組みが走る（F115/F116/F117）。横書き側は同じ理由でメモ化済みであり、非対称。 — ✅ 解決済み(memoize-vertical-text-viewer): F117→F115→F116の順で横書き側と対称な identity ベースのメモ化を導入し、3件すべて解消。
5. **push/PR時のCIが存在しない**: テストは192ファイルあるのに、analyze/testが走るのはリリースタグを打った時だけ（F114）。TDD駆動のリポジトリとして最も費用対効果の高い1件。
6. **LLMクライアントの文字コード処理が危険**: `response.body` は charset 無指定時に latin1 へフォールバックするため、OpenAI互換エンドポイントからの日本語要約が文字化けし得る（F113）。LLM応答のスキーマ検証もなく、失敗時は生JSONがそのまま要約として永続化される（F132）。
7. **テストは量より分布が問題**: 失敗系（failedCount検証ゼロ）、DBマイグレーション（v3→v4カバレッジゼロ）、isolate/FFI境界、スクレイパーの実HTMLフィクスチャがいずれも空白（F122/F129/F158）。一方で死んだコードに対するテストが2箇所で維持されている（F133/F146）。
8. **i18nはUI層では233キー完全パリティだが、provider層の日本語ハードコードが漏れる**: EN/ZHユーザにはエラーメッセージだけ日本語で表示される（F142）。
9. **インストーラ自動更新はSHA256（同一オリジン取得）のみで署名検証なし**（F134）。TLSが唯一の信頼アンカーであることは少なくとも文書化すべき。
10. **健全な点も明記する**: lint指摘ゼロ、TODO/FIXMEゼロ、Riverpodはレガシーパターンゼロ、.arb完全パリティ、前回監査の返済実績あり。debt は溜まる一方ではなく返済されているリポジトリである。

## アーキテクチャのメンタルモデル

Flutterデスクトップアプリ（Windows主、macOS従、Linuxは名目）。`lib/features/<機能>/{data,domain,presentation,providers}` のfeature-first構成14モジュール + 薄い `shared/`。状態はRiverpod 3（レガシーパターンなし）、画面は `HomeScreen` の3カラム1枚でルーターなし。

データは二層: グローバル `novel_metadata.db`（小説メタデータ・要約・fact cache・読書進捗・ブックマーク、v7までのマイグレーション持ち）と、小説フォルダごとの `episode_cache.db` / `tts_audio.db` / `tts_dictionary.db`。**per-folder DBはRiverpodのfamily providerがハンドルを保持するため、フォルダの削除/移動/リネームの前に必ずハンドルを閉じる必要があり、この調整がアプリ最大の構造的リスク**（findings 多数がここに集まる）。

TTSが複雑性の中心: FFIで `qwen3-tts.cpp`（abort対応・24kHz）と `piper`（abort非対応・22.05kHz）の2エンジンを専用isolateで駆動し、文単位セグメントをWAV BLOBとしてSQLiteに永続化、lameでMP3エクスポート。isolate間は生ポインタアドレスをintで渡すドキュメント済みハックがある。

スクレイパーは `NovelSite` 抽象の4実装（Narou / Kakuyomu(Apollo state) / Hameln / Aozora(ShiftJIS)）。堅牢化のレベルがアダプタごとに非対称で、ダウンロード本体には「空の結果」を異常とみなすガードがない。

開発プロセスはOpenSpec駆動（specs 80+、変更はアーカイブ付き）で、前回監査の解決記録も残る。READMEと実装の矛盾は前回指摘（Ollamaポート）が修正済みで、今回は「対応サイト一覧の不在」「Linux対応の過大表示」が残る程度。

## Findings

| ID | Category | File:Line | Severity | Effort | Description | Recommendation |
|----|----------|-----------|----------|--------|-------------|----------------|
| F101 | エラー処理 | lib/features/tts/data/tts_streaming_controller.dart:127-133,205-225 | **Critical** | S | モデルロード/合成失敗時はループを`break`するだけで`_stopped`がfalseのまま→episodeが**completed**としてマークされる。UIは completed→ready 変換（tts_audio_state_provider.dart:15-17）のため、音声ゼロのepisodeに再生/エクスポートボタンが出現し、エラーは一切表示されない | ✅ 対応済み(fix-tts-silent-failure): 失敗を停止と区別し検出、音声ゼロはepisode削除/途中まではpartial、UIはlocalized snackbar通知（error値の新設はせずstatusで表現） |
| F102 | エラー処理 | lib/features/text_download/data/download_service.dart:205-207 | High | S | 目次ページネーションのループが`catch (_) { break; }`で全例外を握り潰す。2ページ目以降の失敗が`failedCount=0`の「完了」として報告される | ✅ 対応済み(fix-download-silent-failures): `DownloadResult.indexTruncated`フラグで表面化し、UIで打ち切り警告＋WARNINGログ。ページ上限到達は truncated=false |
| F103 | 堅牢性 | lib/features/text_download/data/download_service.dart:68-71 | High | S | `_client.get`にタイムアウトが一切ない（lib配下に`.timeout(`はゼロ件）。接続スタックでダウンロードが永久ハングし、キャンセル手段もない | ✅ 対応済み(fix-download-silent-failures): 全`_client.get`に`.timeout()`(既定30秒・注入可)。加えて`CancellationToken`新設＋ダイアログのキャンセルボタンでユーザ中断を実装 |
| F104 | アーキテクチャ | lib/features/text_download/data/download_service.dart:21-26,370-372 | High | M | ファイル名のゼロ埋め幅が「現在の総話数」依存。99話→100話で全話の期待ファイル名が変わり（`01_`→`001_`）、スキップ判定が全部外れて全話再DL＋旧名ファイルがゴミとして残留 | 固定幅パディング、またはDL前に旧幅ファイルをリネーム |
| F105 | エラー処理 | sites/narou_site.dart:149 / kakuyomu_site.dart:129 / hameln_site.dart:134 / aozora_site.dart:61 + download_service.dart:323-333 | High | M | 全アダプタの`parseEpisode`がセレクタ不一致（サイト改修）時に空文字を返し、それを正常として空.txtを保存＆キャッシュ登録。以降のインクリメンタル更新で永久にスキップされ直らない | ✅ 対応済み(fix-download-silent-failures): 空パース結果はsave/cacheせず`failedCount++`（次回再試行）。空判定はdownload_service側の1箇所に集約しアダプタ契約は不変 |
| F106 | 型・契約 | lib/features/bookmark/providers/bookmark_providers.dart:12-22（同ロジック: reading_progress_providers.dart:61） | High | M | `novel_id`をライブラリ直下の**第1セグメント**から導出。フォルダ管理機能のネスト配置（file_browser_panel.dart:383）では整理フォルダ名がキーになり、小説を別フォルダへ移動するとブックマーク/進捗が全て孤児化。novel判定は他所では任意深度の葉名（novel_folder_classifier.dart:7-9）で矛盾 | ✅ 対応済み(fix-novel-identity-consistency): 共有`resolveNovelId`を新設し葉名(folder_name)に一本化。`currentNovelIdProvider`をFutureProvider化、reading_progressリスナーも差し替え。`selectedNovelTitleProvider`の重複走査も委譲。既存ネスト孤児行のクリーンアップはF128後続changeで対応 |
| F107 | アーキテクチャ | lib/features/novel_delete/data/novel_delete_service.dart:44-49 | High | S | 削除カスケードがnovels/word_summaries/fact_cache/reading_progressのみで**bookmarksを消さない**。孤児行が永久蓄積し、同名フォルダ再DLで古い絶対パス付きで復活する | ✅ 対応済み(fix-novel-identity-consistency): カスケードに`BookmarkRepository.deleteByNovelId`を追加。novel_idは葉名(folder_name)で統一されsave側とキー一致（F106同時解消） |
| F108 | DBハイジーン | lib/features/file_browser/presentation/file_browser_panel.dart:445-451（使用箇所 :422,:476,:505） | High | M | move/rename/空フォルダ削除がfire-and-forgetの`ref.invalidate`でDBハンドルを「解放」するが、closeはunawaitedなFuture。`Directory.rename`/`delete`がWindowsのファイルロックとレースする。削除フローだけは修正済み（novel_delete_providers.dart:27-32が理由までコメント済み） | novel_delete_providers.dartのawait付きclose-then-invalidateヘルパーを3フローでも使う |
| F109 | アーキテクチャ | lib/features/tts/presentation/tts_edit_dialog.dart:103 + tts_edit_controller.dart:58,436-441 | High | S | 編集ダイアログが`sampleRate: 24000`をハードコード。Piper（22050Hz）で全生成するとメタデータが24000になり、MP3エクスポートが約8.8%ピッチずれ音声になる | engine configから実サンプルレートを取得 |
| F110 | リソース | lib/features/tts/data/tts_edit_controller.dart:410-415 | High | S | `dispose()`が`_segmentPlayer.dispose()`を呼ばない。編集ダイアログ開閉のたびにプラットフォームプレイヤーがリーク（streaming側はdispose済み） | dispose()に追加 |
| F111 | 並行性 | lib/features/tts/data/tts_isolate.dart:140-145,231-238 | High | M | `abort()`はメインisolateから`_ctxAddress`経由でnativeを直接叩くが、モデル再ロード時に旧ctxがfreeされた後も`ModelLoadedResponse`到着までアドレスがstale。ロード中（数秒窓）のstopで解放済みポインタへのFFI呼び出し＝use-after-free | `loadModel()`送信時に`_ctxAddress = null`を先行クリア。恒久対応はctx寿命と分離したabortフラグ専用アロケーション |
| F112 | エラー処理 | lib/features/tts/data/tts_session.dart:52-56,98-106 | High | S | nativeのエラーメッセージ（ModelLoadedResponse.error等）がbool/nullに潰されログにもUIにも出ない。edit側は固定文言、streaming側は無言（F101の片割れ） | ✅ 対応済み(fix-tts-silent-failure): `_log.warning(response.error)` を ensureModelLoaded/synthesize に追加（戻り値契約は不変） |
| F113 | 型・契約 | lib/features/llm_summary/data/openai_compatible_client.dart:45（ollama_client.dart:24,38,60も） | High | S | `response.body`はcharset無指定時latin1にフォールバック（実OpenAIは裸の`application/json`を返す）→日本語要約が文字化けし得る。`choices[0]`は空配列でRangeError、`json['models'] as List`は生TypeErrorが設定UIへ | 全箇所`utf8.decode(response.bodyBytes)`＋形状ガード＋型付き例外 |
| F114 | CI | .github/workflows/release.yml:3-6 | High | S | リポジトリ唯一のワークフローが`v*`タグでのみ起動。analyze/test（:68-72）はリリース時しか走らず、push/PRはCIゼロでマージされる | pub get + analyze + test だけの`test.yml`をpush/PRトリガで追加（単体テストにVulkan/DLLは不要） |
| F115 | パフォーマンス | lib/features/text_viewer/presentation/vertical_text_viewer.dart:249（実体 :605-678） | High | M | `_paginateLines`がLayoutBuilder内で**毎ビルド**全文再ページネーション（flatten+禁則+段組+オフセット計算）。TTSハイライトの1ティック、ページ送りのsetState毎に小説全体を再計算。横書き側は同じ理由でメモ化済み（text_content_renderer.dart:192-200）で非対称 | ✅ 対応済み(memoize-vertical-text-viewer): `_paginateLines`を重い層(pages/pageStarts/charOffset/lineStartColumns)と軽い層(targetPage/bookmarkPages/firstLinePerPage)に分離し、重い層を`(segments identity, constraints, style, columnSpacing)`キーでメモ化。bookmark/target変化では重い層を無効化しない。回数スパイ＋同値テスト追加 |
| F116 | パフォーマンス | lib/features/text_viewer/presentation/vertical_text_page.dart:164-209 | High | M | build()毎に`computeMarkedEntries`+`computeMarkedRanges`+`_computeHighlights`（全バッファ走査+per-char Map）＋per-char widgetリスト再構築。選択ドラッグの1ポインタ移動毎（:352-365のsetState）にも走り、:209の無条件`_scheduleHitRegionRebuild()`がO(全文字)の`localToGlobal`をポストフレームに積む | ✅ 対応済み(memoize-vertical-text-viewer): マークマップとTTSハイライトを入力(entries/markedWords/lineBreaks/range/pageOffset)でメモ化。無条件のhit-region再構築を撤去し、segments/baseStyle/columnSpacing変化時のみ再スケジュール。回数スパイ＋出力同値テスト追加 |
| F117 | アーキテクチャ | lib/features/text_viewer/data/vertical_marked_entries.dart:13-50 + vertical_marked_ranges.dart:46-100 | High | S | `computeMarkedEntries`と`computeMarkedRanges`が同一のバッファ走査＋`findMarks`を行単位で重複実装し、**両方が**毎ビルド呼ばれる（vertical_text_page.dart:169-178）—同じ入力にマーク照合が2回/フレーム | ✅ 対応済み(memoize-vertical-text-viewer): `MarkStyle`を`MarkInfo`へ畳み込み、entriesマップは`_markedRanges[i]?.style`で導出。`computeMarkedEntries`(と旧テスト)を削除しマーク照合を2回→1回/buildに半減 |
| F118 | 一貫性 | kakuyomu_site.dart:30-116 vs narou_site.dart:51-127, hameln_site.dart:72-126 + download_service.dart:139-168 | Medium | M | 防御の非対称: Kakuyomuのみ構造ドリフトで説明的throw、他は黙ってtitle空/episodes 0件を返す。DownloadService側に「何もパースできなかった」ガードがなく空フォルダ＋「完了」になる | parseIndexが空なら例外化。Kakuyomu流の防御を基底契約に |
| F119 | セキュリティ | lib/features/text_download/data/sites/kakuyomu_site.dart:25-27 | Medium | S | `url.host.contains('kakuyomu.jp')`は`kakuyomu.jp.evil.com`にもマッチ。他3アダプタは厳密ホスト集合。schemeチェックはどこにもない | 厳密ホスト一致＋https限定に統一 |
| F120 | 一貫性 | download_service.dart:59-61,70 vs hameln_site.dart:17-18,44-51 | Medium | S | UA方針が分裂: デフォルトはChrome偽装、HamelnのみCloudflare 403回避で正直UA上書き。上書きが効くのはヘッダspread順という暗黙契約 | UA決定を`NovelSite.requestHeaders`に一本化し、spread順依存をテストで固定 |
| F121 | 堅牢性 | lib/features/text_download/data/download_service.dart:318-340 | Medium | M | エピソード取得はリトライなしの一発勝負。一時的503が即failedCountになる | 5xx/タイムアウトのみ1〜2回の指数バックオフ |
| F122 | テスト | test/features/text_download/（全アダプタテスト） | Medium | M | 実ページfixture（.html）がリポジトリに0件、全テストが極小合成HTML。さらに失敗系の検証もゼロ（`failedCount`を見るテストが1件もない）。スクレイパー最大の故障モード＝実マークアップドリフトと部分失敗をオフラインで検出できない | サニタイズ済み実ページスナップショットをtest/fixtures/へ＋失敗パステスト追加（F102/F105の現挙動固定から） |
| F123 | テスト | test/features/text_download/incremental_download_test.dart:558-624 | Medium | S | 実時間2秒のrequestDelayを流してwall-clockをassert。毎回4秒超遅く、CI負荷でflaky | 遅延注入をクロック/フック化し呼び出し位置を直接検証 |
| F124 | DBハイジーン | lib/features/novel_metadata_db/data/novel_database.dart:71-75,480-483（同形: episode_cache_database.dart:17-21, tts_audio_database.dart:17-21） | Medium | M | `database` getterにin-flight openガードがなく`close()`にインターロックがない。close直前に始まったopenがclose完了**後**に新ハンドルを代入し、削除中のファイルを再ロックする。これがwidget層の振り付け（F125）で覆い隠している根本原因 | open中の`Future<Database>`をキャッシュし、close()はin-flight openをawaitして再openをゲート |
| F125 | アーキテクチャ | lib/features/file_browser/presentation/file_browser_panel.dart:586-615 | Medium | L | DBハンドルのライフサイクルをwidget層が振り付け（currentDirectory退避→選択クリア→awaited close、の順序が必須）。per-folder DB providerの新規消費者を追加するたびにlocked-DBバグが再発する構造 | open/closeを所有するper-folder DBハンドルレジストリ（awaitableな`closeAll(folder)`）を導入し、providerは薄いビューに |
| F126 | 一貫性 | lib/shared/database/folder_db_key.dart:3-5 vs lib/features/tts/providers/tts_audio_database_provider.dart:13-32 ほか約8呼び出し箇所 | Medium | S | `folderDbKey`のドキュメントは3つのper-folder DB familyすべての正規化を謳うが、適用されているのはepisode_cacheのみ。TTS系は生パス綴りがキーで、`'$a/$b'`連結パスを渡す未来の呼び出し1つでcommit 81ca506のバグがtts_audio.dbで再発する | 各family provider本体の中で`folderDbKey`を適用し、呼び出し側の規律を不要に |
| F127 | DBハイジーン | lib/features/novel_delete/data/novel_delete_service.dart:44-49 | Medium | S | 同一DBへの4連DELETEがトランザクションなし。novels行（リトライのアンカー）削除後のクラッシュでword_summaries/fact_cache/reading_progressが永久孤児化 | ✅ 対応済み(fix-novel-identity-consistency): 5テーブル削除(novels/word_summaries/fact_cache/reading_progress/bookmarks)を単一`db.transaction`で原子化。各repo delete に optional `DatabaseExecutor? txn` を追加 |
| F128 | DBハイジーン | lib/features/bookmark/domain/bookmark.dart:5 / novel_database.dart:229-235（reading_progress） | Medium | M | 両テーブルが絶対`file_path`を保存。フォルダ移動/リネームで進捗の自動オープンが無言で外れ（reading_progress_providers.dart:100）、ブックマークジャンプは「ファイルなし」（bookmark_list_panel.dart:107-113）。`file_name`列は既にある | novel相対パス（novel_id + file_name）保存に移行＋既存行のワンショットマイグレーション |
| F129 | テスト | lib/features/novel_metadata_db/data/novel_database.dart:238-246 | Medium | M | v3→v4ブックマーク移行（RENAME/再作成/コピー/DROP）のテストカバレッジゼロ。v1→v7のフルチェーン昇格テストもなく、`runMigrationForTesting`（:432-471）は_onUpgradeのステップ順序を迂回するため各versionブロックの相互作用が未検証 | 各歴史版をシードして`NovelDatabase`経由で開くパラメタライズドテスト |
| F130 | テスト | test/features/novel_delete/data/novel_delete_service_test.dart:38-80 ほか計5フィクスチャ | Medium | M | 本番DDLがテストに手書きコピーされ、`_onCreate`（novel_database.dart:98-120）とのスキーマドリフトがテストを通過して本番で壊れる構造 | フィクスチャを`NovelDatabase(dbDirPath:)`+`setDatabase`経由か共有スキーマヘルパーで構築（v6移行テストが正しい手本） |
| F131 | テスト | lib/features/file_browser/presentation/file_browser_panel.dart:422,:505 | Medium | M | move/renameのハンドル解放順序（F108のレース）にテストなし。削除フローは novel_delete_order_test.dart:75-91 で固定済みという非対称が「削除だけ直った」原因 | 削除側のorder-testパターンをmove/renameに移植 |
| F132 | 型・契約 | lib/features/llm_summary/data/llm_summary_pipeline.dart:169-187 | Medium | S | `decoded[key] as String`がtry内: LLMが`{"summary": null}`等を返すとcast失敗が握られ、**生JSON文字列が要約として永続化**される（fact_cacheにも） | `is String`を明示検証、不一致時はリトライ/エラーの定義済み挙動に |
| F133 | アーキテクチャ | lib/features/llm_summary/data/llm_summary_pipeline.dart:22-48 + テスト14本 | Medium | M | `generate()`は本番で死にコード（serviceはextractFileFacts/summarizeFromFactsのみ使用）。14本のテストが死路をピン留めし、死んでいることを覆い隠す | generate()削除、固有のassertはsummarizeFromFactsへ移植 |
| F134 | セキュリティ | lib/features/app_update/data/installer_updater.dart:70-75（+ release_info.dart:50-54, installer_downloader.dart:59） | Medium | M | DLしたexeをSHA256照合のみでサイレント実行。`.sha256`はexeと同一オリジン取得で完全性のみ・真正性はTLS頼み。Authenticode検証なし | WinVerifyTrustか発行者サムプリント固定で検証。最低限TLSが信頼アンカーである旨を文書化 |
| F135 | パフォーマンス | lib/features/settings/presentation/sections/llm_settings_section.dart:72（onChanged :145-172） | Medium | M | base-URL/APIキー/モデル欄の**毎キーストローク**で`ref.invalidate(settingsRepositoryProvider)`。全設定Notifierがこれをwatchしており、1打鍵ごとにlocale/theme/font/TTS状態が再構築されsecure storage再読込も発生 | LLM設定も他と同じNotifierパターンに移行し、永続化はdebounce |
| F136 | パフォーマンス | lib/main.dart:35-48 | Medium | M | 初回描画が完全逐次のawaitチェーン（移行→ライブラリdir→prefs→secure storage移行→`novelDatabase.database`（v4→v5移行込み）→PackageInfo）にブロックされる | 独立awaitを`Future.wait`化、DB解決は既存FutureProvider消費者へ遅延 |
| F137 | アーキテクチャ | lib/features/llm_summary/data/llm_summary_service.dart:217-247 + presentation/analysis_runner.dart:191-247 + data/folder_file_lister.dart:6-12 | Medium | M | 「実効エピソード=数値プレフィクスなければ辞書順位」の不変条件が3箇所に独立実装され、警告コメント（"All three MUST agree…"）だけで束ねられている。ドリフトすると読書位置を超えたネタバレが漏れる | 単一の`EpisodeResolver`を抽出し3者が消費 |
| F138 | アーキテクチャ | lib/features/llm_summary/providers/llm_summary_providers.dart:56-76 + analysis_runner.dart:103-113 | Medium | M | serviceProviderが3つのFutureProviderロード中nullを返すsync provider。呼び出し側が3行の事前await儀式を忘れると分析が無言でno-op | FutureProvider化して呼び出し側は`await ref.read(...future)`1回に |
| F139 | エラー処理 | lib/app/startup_migrations.dart:11 + lib/features/settings/data/settings_repository.dart:169 | Medium | S | APIキー移行失敗が`debugPrint`のみ＝releaseビルドではファイルログに残らない。キーが平文prefsに残留したユーザを診断できない | `Logger('startup').warning(...)`でAppLoggerパイプラインへ（lib内のdebugPrintはこの2件のみ） |
| F140 | エラー処理 | lib/features/app_update/data/installer_downloader.dart:76（同類: distribution_detector.dart:31, installer_updater.dart:83, installer_verifier.dart:20, registry_reader.dart:23, update_dialog.dart:84） | Medium | S | update経路に文字通り空の`catch (_) {}`が6箇所。update_dialog.dart:69-74は実際の例外文言（UpdateResult.message）も捨てる。フィールドでの更新失敗が診断不能 | 各箇所に`Logger('app_update.*').warning(...)`を追加 |
| F141 | 一貫性 | lib/ 全域 | Medium | M | catchが4流派併存: 型付き18×、`catch (e, stack)`15×、裸`catch (e)`36×、無言`catch (_)`16×。汎用`throw Exception('…')`10×がカスタム例外8クラスと併存。規約文書なし | .claude/CLAUDE.mdに5行の規約（型付きcatch+stack付きログ、ユーザ向け失敗はカスタム例外）を明記 |
| F142 | i18n | lib/features/text_download/providers/text_download_providers.dart:67,149,158,170 / tts_model_download_providers.dart:100-104 / piper_model_download_providers.dart:104-108 / tts_export_providers.dart:56,78 / tts_model_size.dart:2-3 | Medium | S | UI層は233キー完全パリティなのに、provider層のユーザ可視文字列が日本語ハードコード（`'サポートされていないサイトです'`等）。EN/ZHユーザにはエラーだけ日本語で出る。2つのモデルDL providerはエラー分類も相互コピー | 🟡 一部対応(fix-download-silent-failures): download_dialog.dartの`_failedSuffix`手書きswitchを`download_failedSuffix`(.arb 3言語)へ移行。残り（provider層の日本語ハードコード、file_browser_panel.dart:674-682の重複switch、モデルDL provider）は未対応 |
| F143 | テスト | lib/features/llm_summary/data/ollama_client.dart, openai_compatible_client.dart, lib/features/text_download/providers/text_download_providers.dart, lib/features/tts/data/tts_playback_controller.dart, lib/features/app_update/data/installer_downloader.dart ほか計47ファイル | Medium | L | 非l10nのlibファイルの25%（47/185）に対応テストなし。特にネットワークパーサ2本（LLMクライアント）とDL状態機械、installer_downloader（stream-to-disk/タイムアウト/部分ファイル掃除）が無防備 | LLMクライアント2本とtext_download_providersを最優先に追加 |
| F144 | 並行性 | lib/features/tts/data/tts_session.dart:89-115 + tts_isolate.dart:86-107 | Medium | M | `synthesize()`にタイムアウトなし、`Isolate.spawn`に`addErrorListener`なし。workerがDart例外で死ぬとcompleterが永遠に未解決→streamingが「waiting」のまま無限ハング | onError/onExitリスナーでcompleterをエラー解決 |
| F145 | 一貫性 | lib/features/tts/data/piper_native_bindings.dart（abortシンボル不在）+ tts_isolate.dart:269-272,290 | Medium | M | abort/resetAbortはqwen3専用でPiper合成中の`abort()`は無言のno-op。stopはセグメント完了待ちかdisposeの2秒タイムアウト後`kill`頼み（FFIブロック中はkillも効かずnativeリーク） | piper側にabortフラグAPIを追加、最低限no-opであることを明示 |
| F146 | アーキテクチャ | lib/features/tts/data/tts_stored_player_controller.dart:13-123 | Medium | S | クラス全体が死にコード（lib内生成ゼロ、openspecアーカイブでも「既に死んでいる」と認知済み）。324行のテストも維持コスト | クラスとテストを削除しspecを更新 |
| F147 | 並行性 | lib/features/tts/presentation/tts_edit_dialog.dart:380-383 | Medium | S | 「すべて再生」が再生中も有効（isGeneratingのみで無効化）。二度押しで2つのplayAllループが単一スロットの`_activePlayCompleter`（segment_player.dart:46,63）を奪い合う | isPlaying中は無効化、またはcontrollerに再入ガード |
| F148 | リソース | lib/features/tts/presentation/tts_edit_dialog.dart:66-120 vs :131-141 | Medium | S | `_initialize`の`_controller = controller`（:109）到達前にStateがdisposeされると（await中にダイアログを閉じた場合）、生成済みTtsIsolate/JustAudioPlayerが永遠にdisposeされない | 生成直後に代入し、init末尾でmountedチェック後にdispose |
| F149 | リソース | lib/features/tts/data/tts_streaming_controller.dart:328,331-339 | Medium | S | `stop()`末尾の`_cleanupFiles()`がtry外。Windowsでプレイヤーがwavを握っているとdelete例外がunawaitedなonPressed（tts_controls_bar.dart:387）までunhandledで伝搬。stored版だけPathNotFoundExceptionを握る非対称 | 共通cleanupヘルパー化して例外を握る |
| F150 | パフォーマンス | lib/features/tts/data/tts_isolate.dart:293-298 | Medium | S | 「zero-copy transfer」とコメントしつつworker側で`materialize()`してからsend→TransferableTypedDataの意味が消え数MBのFloat32Listがセグメント毎に余分にディープコピー | TransferableTypedDataのまま載せ受信側でmaterialize |
| F151 | 一貫性 | lib/features/text_viewer/presentation/widgets/text_content_renderer.dart:412-437,439-455 vs :460-477,538-561 | Medium | M | 行→ピクセル変換が2モデル併存: TTS自動スクロールと現在行レポートは素朴な`行番号×lineHeight`（ソフトラップとルビ行1.5倍を無視）、検索/ブックマークジャンプは実測TextPainter。ルビ多用文でTTSスクロールがドリフト | 意図的なper-tick節約なら文書化、でなければキャッシュ済みpainterを再利用 |
| F152 | 一貫性 | lib/features/text_viewer/presentation/vertical_text_page.dart:506-513,615-617 + ruby_text_builder.dart:143-158 | Medium | M | TTSハイライトが両モードでルビ語を無言スキップ。縦書きはハイライト所属を計算してから捨てており（computed-then-dropped）、決定ではなく取りこぼしに見える | 両ルビwidgetにTTSハイライト対応を追加、または制限を文書化 |
| F153 | 一貫性 | vertical_text_viewer.dart:92-93 / vertical_text_page.dart:73-74 / vertical_ruby_text_widget.dart:123,129 + ruby比率0.5が4箇所（ruby_text_builder.dart:38, text_content_renderer.dart:134, vertical_text_page.dart:478, vertical_ruby_text_widget.dart:26） | Medium | S | `_kTextHeight=1.1`/`_kDefaultFontSize=14.0`が2ファイルに私的再定義+3つ目に直書き。ルビフォント比0.5も4箇所重複。ページネーション計算とセル描画が暗黙の一致に依存し、強制する仕組みなし | 共有定数ファイル（`kRubyFontRatio`等）に集約 |
| F154 | 一貫性 | text_content_renderer.dart:317-337 vs vertical_text_viewer.dart:166-181 | Medium | S | ワンショット`pendingFileEntryIntentProvider`の消費が2箇所で手書き重複し、セマンティクスも微妙に相違（横はnull時fromStart合成、縦は暗黙の`_currentPage=0`リセット頼み） | consume-onceセマンティクスをnotifier側（`consume()`）へ移動 |
| F155 | アーキテクチャ | tts_controls_bar.dart:117-135,212-217 + text_content_renderer.dart:378-388 + tts_edit_dialog.dart:67-74 | Medium | M | widget層がデータ層オブジェクト（TtsAudioRepository/TtsDictionaryRepository/TtsIsolate/JustAudioPlayer）をvacuum連携込みでインライン組み立て、3箇所コピペ | `ttsAudioRepositoryProvider(folderPath)`等のRiverpod familyへ集約 |
| F156 | アーキテクチャ | lib/features/text_viewer/presentation/vertical_text_viewer.dart:238-434 | Medium | L | build()が約200行のスケジューラと化し、レイアウト中の状態変異（:252,:286,:274-277）+4種のポストフレームsetStateジャンプを振り付け。最高チャーンのロジック（31コミット/6ヶ月）が最もテスト困難な場所に集中し、`_scheduledTargetPage`等のガードは再入バグの後追いパッチ | ページネーション+ページターゲット解決を純関数（コマンド値を返す）へ持ち上げ、効果適用を一箇所に |
| F157 | テスト | lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart:81-192 | Medium | M | 最リスクのロジック—再入ガード(:88)、所有権移転finally(:155-167)、`_stopStreaming`防御クリア(:170-192)—が実レースへの長文コメント付きなのにテストゼロ。テストは(audio×playback)描画マトリクスのみ | セッション所有権の状態機械をテスト可能なcontrollerへ抽出、またはfake streaming controllerでwidgetテスト |
| F158 | テスト | test/features/tts/data/tts_isolate_test.dart:8-157 | Medium | M | isolateテストはDTO getterとspawn/disposeのみ。workerのエンジン分岐・load失敗時disposeEngines・resetAbort・embeddingCacheDir合成（tts_isolate.dart:259-268）はカバレッジゼロ | エンジンファクトリを注入可能にしentrypointロジックを単体テスト |
| F159 | CI | .github/workflows/release.yml:17 | Medium | M | リリース自動化はWindowsのみ（windows-latest）。macOSはREADMEの手動スクリプトで、2つのリリースプロセスがドリフトし得る | macOSジョブ追加、または非対称が意図である旨を文書化 |
| F160 | ドキュメント | README.md:13-21 + .claude/CLAUDE.md:3 | Medium | S | 対応サイトがREADME 3言語のどこにも列挙されず、Hameln/Aozoraは事実上の隠し機能。CLAUDE.mdも「なろう、カクヨム」のままで、ビルド手順から`build_piper_*`が欠落（release.yml:57-59は要求） | 3言語READMEに「対応サイト」節を追加、CLAUDE.mdを同期 |
| F161 | パフォーマンス | lib/features/text_viewer/presentation/vertical_text_page.dart:96,136-139,462-496 | Medium | M | 1文字ごとに`GlobalKey`+`KeyedSubtree`を生成し、`_rebuildHitRegions`が全文字に`findRenderObject`/`localToGlobal`を実行。ルビセルの可変高で数式ヒットテストを断念した経緯があり load-bearing 気味だが、コストは文字数×フレームで効く | 平文字はWrapジオメトリから矩形を計算し、キーはルビentryのみに |
| F162 | パフォーマンス | lib/features/llm_summary/presentation/hover_popup_host.dart:96-101（folder_file_lister.dart:17-31） | Medium | S | ポップアップ表示のたびUIスレッドで同期`Directory.listSync`×3回（3つのresolverが各自リスト）。ホバーは高頻度ジェスチャで大フォルダはジャンク | 表示毎に1回listして3resolverへ渡す、またはディレクトリ単位キャッシュ |
| F163 | 一貫性 | lib/features/llm_summary/providers/llm_summary_providers.dart:22,32（再掲F024系） | Medium | S | LLMクライアントがhttp client未注入→内部で未closeの`http.Client()`を設定変更のたび再生成。正規の`httpClientProvider`（settings_providers.dart:13）は他4機能で使用中。DL系は`client ?? http.Client()`の第3流派（download_service.dart:57） | `ref.watch(httpClientProvider)`を注入し、DI規約を必須注入に統一 |
| F164 | アーキテクチャ | 死にコード一括: vertical_text_layout.dart:68-93（hitTestCharIndex+旧式テスト128-237）, swipe_detection.dart:27-66（detectSwipe）, ruby_text_parser.dart:91-103（buildPlainTextと_concatenatedBaseTextの重複）, text_content_renderer.dart:41-47（computeLineStartOffsets）, download_service.dart:81-84（fetchPage—再利用されると文字化け/403の罠）, llm_config.dart:14（isConfigured）, tts_edit_providers.dart:18-28 / tts_audio_repository.dart:133-140,195-202 / voice_recording_service.dart:40（テストのみ参照のメソッド群） | Low | S | 本番参照ゼロのコード＋それをピン留めする偽カバレッジテスト。特にhitTestCharIndexのテストは廃止済みグリッド幾何をassertし誤った安心感を与える | 一括削除（テストごと）。fetchPageは罠なので優先 |
| F165 | 型・契約 | novel_site.dart:8,58 / narou_site.dart:154 / hameln_site.dart:144,159（再掲F008/F009） | Low | S | パース補助が`dynamic`受けでHTML境界の静的型を放棄。前回Deferredのまま新規アダプタ（hameln）にもコピーされた—「触るとき直す」が効いていない証拠 | `package:html/dom.dart`の`Element`/`Document`を明示 |
| F166 | 堅牢性 | lib/features/novel_metadata_db/data/novel_database.dart:345 | Low | S | 移行のdedupキーに**生NULバイト(0x00)**がソースへ直接埋め込まれている（hexdumpで確認済み）。レビューで不可視、フォーマッタ/gitフィルタ1つで無言のキー衝突に化ける | `'\x00'`エスケープに置換 |
| F167 | 堅牢性 | lib/shared/utils/file_name_utils.dart:21-25 | Low | S | `isValidFolderName`が`.`/`..`、末尾ドット/空白、Windows予約名（CON/NUL）を許容。`'foo.'`はWindowsで`foo`を作り名前不一致、予約名は汎用「不明なエラー」に化ける | 予約名・末尾ドット/空白・`.`/`..`を明示拒否 |
| F168 | エラー処理 | lib/features/file_browser/presentation/file_browser_panel.dart:400-402 | Low | S | `_showMoveDialog`がFileSystemExceptionを裸`return;`で握る—Move押下で何も起きず何も記録されない。兄弟フローは全てsnackbar表示 | ログ＋common_unknownError snackbar |
| F169 | 一貫性 | lib/features/text_download/presentation/download_dialog.dart:25 + text_download_providers.dart:58 vs :137-139 + :118-122 | Low | S | ダイアログが`NovelSiteRegistry()`を直newしproviderと二重管理。`startDownload`に実行中ガードなし（refreshNovelにはある）。エラーは`e.toString()`生文字列でUI表示。:167-172の外側catchは到達不能の死にコード | provider経由に統一、ガード移動、例外→ローカライズ済みメッセージのマッピング層 |
| F170 | アーキテクチャ | lib/features/text_search/data/text_search_service.dart:8-50 vs 52-99（+ :27,72の UTF-8前提、:26-47の逐次読み） | Low | S | `search`と`searchWithContext`が約9割同一の重複。非UTF-8の持ち込み.txtが1つあると検索全体が落ちて生エラーがパネルに出る。ファイル読みは逐次awaitでN+1的 | searchを委譲化、ファイル単位try/catchでスキップ、並列度8程度のFuture.wait |
| F171 | 型・契約 | lib/features/novel_metadata_db/data/novel_repository.dart:9-30 | Low | S | `upsert`が非atomicなSELECT→UPDATE/INSERT。リポジトリ内で3つ目のupsert流儀（replace / ignore+手動dedup / read-then-write）。単一isolateゆえレースは理論上 | `INSERT ... ON CONFLICT DO UPDATE`に（uniqueインデックスは既存） |
| F172 | パフォーマンス | lib/features/file_browser/providers/file_browser_providers.dart:68,84-98 | Low | S | `directoryContentsProvider`が`allNovelsProvider`のinvalidate毎（タイトル変更・削除・更新完了）にTTSステータス全クエリを再実行 | TTSステータスをディレクトリキーの独立providerに分離 |
| F173 | 一貫性 | lib/features/novel_metadata_db/data/novel_database.dart:94-95 | Low | S | DBパス解決がラッパー内でOS分岐（Windowsはexe隣、他はsqfliteの`getDatabasesPath()`）。POSIX側の実際の解決先はテストでもピンされていない | main.dart（既にNovelDatabaseを構築している）から解決済みdirを注入 |
| F174 | リソース | lib/features/llm_summary/providers/hover_popup_cache_provider.dart:10-15 | Low | S | 非autoDisposeの`FutureProvider.family`—ホバーした(folder, word)ごとに1エントリがアプリ生存期間中保持され、削除済み語のエントリはstaleに | autoDispose化（再分析invalidationは継続して機能する） |
| F175 | エラー処理 | lib/features/tts/presentation/voice_recording_dialog.dart:154-175 + lib/features/tts/data/piper_model_download_service.dart:115-137 | Low | S | 3つのcatchが完全同一処理のコピペ＋エラー時に`_showSaveDialog()`を再帰呼び出し。piper側は外部`tar`プロセス依存で、失敗時にtar.gzとパーシャル展開が残置 | catch統合＋ループ化。finallyでtar.gz削除、`package:archive`検討 |
| F176 | 一貫性 | lib/features/app_update/presentation/update_dialog.dart:35-36 + sections/about_and_update_section.dart:27-28 + domain/update_constants.dart:18-25 / settings_repository.dart:13-30 vs update_preferences.dart:8-10 | Low | S | タグ正規化が3実装（buildメタデータの扱いが相違し`v1.2.3+4`でUIラベルとスヌーズ同一性が食い違い得る）。prefsキーも裸キーと名前空間キーの2規約併存 | `normalizeReleaseVersion`に一本化。新設定は名前空間キーで統一と文書化 |
| F177 | エラー処理 | lib/shared/logging/app_logger.dart:43-46 | Low | S | releaseでファイルシンク生成失敗を`catch (_)`で握り、全ログが誰も見ないdebugPrintへ無言降格—ログ系自体がfail-closedで痕跡なし | 失敗理由をbest-effortで1行stderr/レコード出力 |
| F178 | テスト | test/helpers/localized_material_app.dart + test/test_utils/flutter_secure_storage_mock.dart | Low | S | テストヘルパーが2ディレクトリに1ファイルずつ。次のヘルパーの置き場規約なし | test/helpers/に統合 |
| F179 | 依存・設定 | pubspec.yaml:2,39,60,63 | Low | S/M | description が「A new Flutter project.」のまま（installerのWindowsファイルメタデータに流れる）。`cupertino_icons`は参照ゼロの初期生成残骸。`win32_registry` 2.1.0と`package_info_plus` 9.0.1はメジャー1つ遅れで、どちらも自動更新機能が触る場所 | description修正・cupertino_icons削除はS。メジャーバンプ2件は更新機能のテストと併せてM |
| F180 | 死に荷重 | memo/backlogs.md, memo/first_proposal.md / docs/plans/2026-02-28-*.md（4本）/ .agents/skills/spec-to-readable-html/（.claude/skills/とバイト同一）/ android/（22ファイル）+ ios/（40+ファイル） | Low | S | 個人スクラッチ・出荷済み修正の設計メモ・スキルの二重トラック・出荷予定のないモバイルscaffoldingがgit管理下に。実害は薄いが新規参加者とエージェントのノイズ | memo/docs/plansは削除かアーカイブ、スキルは片方削除、モバイルは削除またはREADMEで非対応を明記 |
| F181 | ドキュメント | README.md:11 + scripts/build_*_macos.sh vs build_*_windows.bat | Low | M | 「Linux(未確認)」を掲げるがTTS/LAME/PiperのLinuxビルドスクリプトが存在せず、看板機能のTTSは出荷状態で動作不能（再掲F035系）。3組の.sh/.batビルドペアは独立進化しCIで検証されるのはWindows側のみ | Linux表記を「TTS非対応」に修正か削除。ビルドペアは共有設定ファイル（pin済みバージョン）を両者が読む形に |
| F182 | 型・契約 | lib/features/text_viewer/presentation/vertical_text_viewer.dart:726-731,817-825 + vertical_text_page.dart:25-26,44-45 | Low | S | 最複雑関数が無名位置レコード`(List<List<TextSegment>>, List<int>, List<Set<int>>)`と6位置引数コンストラクタを返す。`selectionStart/End`パラメータはテストのみが供給する本番APIのテスト残渣 | 名前付きレコード/名前付き引数化。selectionパラメータはジェスチャ駆動テストに置換して削除 |
| F183 | ドキュメント | lib/features/text_viewer/data/vertical_char_map.dart:44,105 + settings_repository.dart:152-154 + analysis_runner.dart:189-190 | Low | S | コメントが実装と矛盾: 回転は「RotatedBoxによる物理回転」と書くが実装は意図的にTransform.rotate（RotatedBoxはセルが縮むため—理由は別ファイルに記載）。settings_repositoryの「propagateしない」契約は呼び出し側のcatchで辛うじて真。resolveUpperBoundForCurrentのnull禁止docは実呼び出しと矛盾 | 3箇所ともコメントを実装に合わせて修正 |
| F184 | アーキテクチャ | lib/features/tts/data/tts_isolate.dart:189-229 + tts_edit_controller.dart:98-107,222-225,360-365,386-396 | Low | M | worker内にnullableエンジン2フィールド+activeEngineTypeの三重switch（両エンジンは既に結果/例外型を共有済みで共通IF 1本で消せる）。「辞書取得→適用」パターンも6箇所に複製されそれぞれDB再クエリ | NativeTtsEngine抽象の導入＋repositoryに`applyTo(String)`ヘルパー |

## Top 5 — これだけは直す

### 1. F101 + F112: TTS失敗の「completed」化を止める（Critical）✅ 対応済み（change: fix-tts-silent-failure）

合成が1セグメントも成功していなくても、ユーザには成功と同じUIが見える。これはTTS機能の信頼性そのものを毀損する。

```dart
// tts_streaming_controller.dart — 概略
var failed = false;
for (final segment in segments) {
  final result = await _session.synthesize(...);
  if (result == null) { failed = true; break; }  // break だけで終わらせない
  ...
}
// 終了処理で分岐
final status = _stopped
    ? TtsEpisodeStatus.partial
    : failed
        ? TtsEpisodeStatus.error      // ← 新ステータス。UIはスナックバー+リトライ導線
        : TtsEpisodeStatus.completed;
```

同時に `tts_session.dart:52-56,98-106` で捨てているnativeエラー文字列を `_log.warning` に流す（F112、2行の修正）。これでフィールドの失敗が初めて診断可能になる。

### 2. ダウンロードの「静かな失敗」三点セット（F102 / F105 / F103）✅ 対応済み（change: fix-download-silent-failures）

3つとも `download_service.dart` 内で完結し、互いに独立して小さい:

- :205-207 の `catch (_) { break; }` → 例外を `indexTruncated = true` として `DownloadResult` に載せ、UIで「目次の取得が途中で失敗」を表示。✅ WARNINGログも追加、ページ上限到達は truncated=false。
- :323-333 で `parseEpisode` が空文字を返したら **保存もキャッシュ登録もせず** failedCount++。これで次回更新時に再試行される。✅ 空判定は download_service 側に集約しアダプタ契約は不変。
- 全 `_client.get` に `.timeout(const Duration(seconds: 30))`。✅ あわせて `CancellationToken` を新設し、ダウンロードのユーザ中断（`DownloadStatus.cancelled`）を実装。

先に現挙動を固定する失敗系テスト（F122）を書いてから直す（TDD原則どおり）。✅ 失敗系・キャンセル系テストとサニタイズ済みフィクスチャを追加（empty_parse / request_timeout / index_truncated / download_cancellation / cancellation_token / provider_state / dialog）。コードレビューで判明したキャンセル中断時の例外誤分類（in-flight `ClientException` の `error` 誤判定、failedCount水増し、二重start、短編キャンセル未対応）も修正済み。

### 3. 小説アイデンティティの整合性（F106 / F107 / F127）✅ 対応済み（change: fix-novel-identity-consistency）／ F128 は後続change

3つは同じ根を持つ: 「小説を一意に識別する方法」が機能ごとにバラバラ。修正は1つの共有関数に収斂する:

```dart
// shared/utils/novel_id_resolver.dart（新規）
/// ライブラリルートからパスを下り、登録済み小説フォルダ名を返す。
/// 整理フォルダ内のネストにも対応（selectedNovelTitleProviderと同じ走査）。
String? resolveNovelId(String libraryRoot, String filePath, Set<String> registeredFolders) { ... }
```

`bookmark_providers.dart:12-22` と `reading_progress_providers.dart:61` をこれに差し替え、`novel_delete_service.dart:44-49` のカスケードに bookmarks を追加して4テーブル削除を `db.transaction` で包む（F127も同時に解消）。絶対パス→相対パスのマイグレーション（F128）は同じOpenSpec changeの後続タスクにする。

### 4. push/PRのCIを追加する（F114）

最小の `test.yml` で即日入る:

```yaml
name: test
on:
  push: { branches: [main] }
  pull_request:
jobs:
  test:
    runs-on: windows-latest   # Windows-onlyテストが7件あるためubuntuではなくwindows
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

単体テストにVulkan/TTS DLLは不要（release.ymlのネイティブビルドステップは持ち込まない）。3.9万行のテスト資産がタグ時しか走らない現状は、TDDで開発しているこのリポジトリにとって一番もったいない欠落。

### 5. 縦書きビューアのメモ化（F115 / F116 / F117） — ✅ 解決済み(memoize-vertical-text-viewer)

順序が重要: まずF117（`computeMarkedEntries`削除でマーク照合を半減、S効果）、次にF115（`_paginateLines`の結果を `(segmentsのidentity, constraints, style, columnSpacing)` キーでメモ化—横書き側 text_content_renderer.dart:192-200 に手本がある）、最後にF116（vertical_text_page側のマップ類のメモ化＋hit-region再構築の条件化）。F156（god build分解）はこの3つの後にやる方が安全。

**結果**: 推奨順（F117→F115→F116）通りにTDDで実装・アーカイブ済み。F115は重い層（pages/pageStarts/charOffset/lineStartColumns）と軽い層（targetPage/bookmarkPages/firstLinePerPage）を分離し、bookmark/target変化で重い層を無効化しない設計に。F116はTTSハイライトのメモ化キーに entries identity と pageStartTextOffset も必要（range単独では不足）と判明。各フェーズで回数スパイ＋同値テストを追加し、`vertical-text-display` スペックに3要件（Pagination memoization / Single mark computation per build / Memoized page-level recomputation）を反映。F156（god build分解）が次の安全な着手先。

## Quick wins（Low effort × Medium+ severity のチェックリスト）

- [x] F103: 全HTTPリクエストに `.timeout()` 追加（＋キャンセルトークン）
- [x] F102: ページネーション `catch (_) { break; }` を打ち切りフラグ（indexTruncated）に変更
- [x] F107: 削除カスケードに bookmarks 追加（change: fix-novel-identity-consistency）
- [x] F127: 削除の4連DELETEを `db.transaction` で包む（change: fix-novel-identity-consistency、bookmarks含む5テーブル）
- [ ] F109: 編集ダイアログの `sampleRate: 24000` をengine configから取得
- [ ] F110: `tts_edit_controller.dispose()` に `_segmentPlayer.dispose()` 追加
- [x] F112: tts_sessionでnativeエラー文字列をログへ
- [ ] F113: LLMクライアントを `utf8.decode(response.bodyBytes)` に変更＋`choices`/`models` の形状ガード
- [x] F114: `test.yml`（push/PR CI）追加
- [ ] F126: `folderDbKey` を各family provider本体で適用
- [ ] F139: 移行系の `debugPrint` 2件を `Logger` へ
- [ ] F140: update経路の空catch 6箇所にロギング追加
- [ ] F132: LLM応答の `is String` 検証（生JSON永続化の防止）
- [ ] F146: `TtsStoredPlayerController` とテスト324行を削除
- [ ] F164: 死にコード一括削除（特に `fetchPage` は罠）
- [ ] F168: `_showMoveDialog` の例外握り潰しにsnackbar
- [x] F117: `computeMarkedEntries` を `computeMarkedRanges` 由来に統合（change: memoize-vertical-text-viewer）
- [ ] F162: ホバーポップアップの `listSync` ×3 を1回に
- [ ] F166: 生NULバイトを `'\x00'` に置換
- [ ] F179(一部): pubspec description修正＋`cupertino_icons`削除

## 一見問題だが実は健全なもの（Things that look bad but are actually fine）

- **`segment_player.dart:6-22` の「順序がload-bearing」コメント群** — setFilePath→listenの順序、pause() vs stop()、500msドレイン遅延は、すべて実バグ（WASAPI尻切れ、BehaviorSubject replay）への対処でテスト固定済み。簡素化したくなるが触らないのが正解。
- **`vertical_text_viewer.dart:252,286` のbuild内フィールド代入** — 古典的なsmellだが、キー/ホイールハンドラが現在のページネーションを同期的に必要とし、ページネーションはbuildでしか得られないconstraintsに依存する。問題は周囲のgod build（F156）であって代入自体ではない。
- **`novel_metadata.db` がWindowsでexe隣に置かれる** — Program Files書き込みバグに見えるが、インストーラはper-user（`{userpf}`、UAC不要）でアンインストーラのホワイトリストも意図的にDBを保護している（installer/novel_viewer.iss:35,38,63-67）。
- **マイグレーションの過剰防衛（`IF NOT EXISTS`・再DROP・半端行DELETE、novel_database.dart:206-228,269-302）** — sqfliteはversion callbackをトランザクション内で実行するため部分適用は実際には残らない。死んだベルト＆サスペンダーだが無害（コメントのメンタルモデルだけ少し誤り）。
- **`update_check_service.dart:74` がフェッチ前に `lastCheckAt` を記録** — 逆に見えるが、オフライン起動ループがGitHubの無認証レート制限を食い潰すのを防ぐ意図的な順序でコメント済み。
- **`installer_updater.dart:34` の `_onExit` デフォルトが生 `exit`** — 怖く見えるが注入可能で、テストは挙動（実装ではなく）をassertしている（installer_updater_test.dart:84-173）。
- **設定の `secure storage write失敗時に平文キーを残す`（settings_repository.dart:155-173）** — 次回起動リトライのための意図的設計で、no-clobberチェック（:164-167）も正しい。
- **テスト内の `skip:` 7件** — すべて `!Platform.isWindows ? 'Windows-only test' : null` のプラットフォームガードで、無効化されたテストではない。
- **`hover_popup_widget.dart`（400行）** — god fileではない。`_Card`/`_SnapshotSelector` 等にきれいに分解済みで、長文コメント（:300-314）は実在するFlutterのteardown罠の文書化。
- **fact cacheの無効化モデル**（sentinel-hash + content-hash + prompt-version、fact_cache_entry.dart:41-51）— 一見複雑だが正しく、専用テストで固定済み。再分析=全再抽出は文書化された意図。
- **`tts_controls_bar.dart:81-167` の再入ガードと `identical()` チェック** — double-tapとstop競合への意図的防御（ただしテストがない点はF157として指摘）。
- **Kakuyomuの Apollo state 走査が `Map`/`as String?` だらけ** — 外部JSON境界として妥当で、全分岐に説明的throwがあり実は4アダプタ中もっとも防御的。
- **`Episode.updatedAt` がサイト毎に異質なフォーマットの `String?`** — `_shouldDownload` は不等価比較しかしない「不透明な変更トークン」設計で健全。契約のコメント明文化だけ推奨。
- **per-DL毎に `DownloadService`（とhttp.Client）を使い捨てるfactory provider** — Windowsのファイルロック/ライフサイクル管理として理にかなう。
- **flutter_0*.log と installer exe がリポジトリルートに散乱** — gitignore済みの未トラックファイルで、scripts/clean.sh が掃除用に存在する。ディスクの散らかりであってgit債務ではない。

## Open questions for the maintainer

1. **ネストされた小説のID（F106）**: 〜~「ブックマーク/進捗はライブラリ直下第1セグメントをキーにする」は意図した仕様か、`currentNovelIdProvider` がフォルダ管理機能より古いだけか。`selectedNovelTitleProvider` と定義が矛盾しているため、どちらかが仕様上の正になる必要がある。~〜 ✅ 決着(fix-novel-identity-consistency): **葉名(folder_name)を正**とし、第1セグメント派を共有`resolveNovelId`へ統一。`selectedNovelTitleProvider`も同関数へ委譲。第1セグメント導出は仕様外と確定。
2. **provider層の日本語エラー文字列（F142）**: 主要ユーザは日本語という意図的判断か、見落としか。答えによってMediumかWon't-fixかが決まる。
3. **編集ダイアログの `sampleRate: 24000`（F109）**: 「エクスポートはqwen3専用」という暗黙の前提だったのか。Piperエピソードのエクスポートが仕様内なら即修正対象。
4. **Hamelnの目次ページネーション**: `nextPageUrl` 対応はNarouのみ。syosetu.orgが超長編で目次を分割する場合、2ページ目以降が黙って欠落する。実サイトでの分割有無の確認が必要。
5. **ゼロ埋め桁繰り上がり（F104）**: 99→100話で全話再DL＋旧ファイル残留は既知・許容済みの挙動か。修正するなら既存ライブラリの移行処理も必要。
6. **`qwen3_tts_abort` は解放済みctxに対して安全か**（third_party側は未監査）: 安全でなければF111はCritical相当に格上げ。
7. **novel_metadata.db のmacOS/Linuxでの置き場（F173)**: sqflite_common_ffiの `getDatabasesPath()` は `.dart_tool/...` 風のパスに解決される。意図した場所か、Windowsが主戦場ゆえ誰も踏んでいないだけか。
8. **Windows専用リリースCI（F159）**: macOSリリースは手動が意図か、未整備なだけか。
9. **fact cacheのキーがフォルダbasenameのみ（llm_summary_service.dart:121)**: 複数ライブラリルートの計画はあるか。あるなら同名小説間でキャッシュが汚染し合う。
10. **手動更新チェックが自動チェックの24hスロットルを消費する**（update_check_service.dart:74）: 意図か。
11. **`TECH_DEBT_AUDIT_RESOLUTION.md` の削除が未コミットのまま作業ツリーに残っている**: 本監査に先立つ意図的な掃除と推測するが、コミットするか復元するかの判断はメンテナに委ねる（本ファイルの旧版削除は本書が置き換えた）。

## 前回監査（2026-04-29）との対応

- **Resolved 37件**: 全件、今回の調査で再燃なしを確認。特にSprint 5の `text_viewer_panel.dart` 分解（900→49行）、Sprint 2のDTO化、Sprint 4の設定ダイアログ分割、AppLogger導入、APIキーのsecure storage移行は定着している。
- **Deferred 20件のうち今回再浮上**: F008/F009（dynamic境界→F165: 新アダプタにコピーされ悪化）、F024（HTTPクライアントDI→F163: LLM側で未close Clientの再生成という実害に発展）、F035（Linux表記→F181）、F049（CLAUDE.md/piperスクリプト→F160）。「触るとき直す」運用はdynamic境界とDI規約については機能しておらず、規約化（F141/F163）を推奨。
- **残りのDeferred**: 触るとき直す方針のまま据え置きで問題ないと判断（F023のlinear scan、F043のパネル幅等）。
