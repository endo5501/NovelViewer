// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get common_closeButton => '閉じる';

  @override
  String get common_cancelButton => 'キャンセル';

  @override
  String get common_changeButton => '変更';

  @override
  String get common_deleteButton => '削除';

  @override
  String common_errorPrefix(String message) {
    return 'エラー: $message';
  }

  @override
  String get common_fileDuplicateError => '同名のファイルが既に存在します';

  @override
  String get common_fileNameLabel => 'ファイル名';

  @override
  String get common_unknownError => '不明なエラー';

  @override
  String get settings_title => '設定';

  @override
  String get settings_generalTabLabel => '一般';

  @override
  String get settings_ttsTabLabel => '読み上げ';

  @override
  String get settings_verticalDisplayTitle => '縦書き表示';

  @override
  String get settings_verticalDisplayVertical => '縦書き';

  @override
  String get settings_verticalDisplayHorizontal => '横書き';

  @override
  String get settings_darkModeTitle => 'ダークモード';

  @override
  String get settings_darkModeDark => 'ダーク';

  @override
  String get settings_darkModeLight => 'ライト';

  @override
  String get settings_fontSizeTitle => 'フォントサイズ';

  @override
  String get settings_fontFamilyTitle => 'フォント種別';

  @override
  String get settings_columnSpacingTitle => '列間隔';

  @override
  String get settings_llmProviderTitle => 'LLMプロバイダ';

  @override
  String get settings_llmProviderNone => '未設定';

  @override
  String get settings_llmProviderOpenai => 'OpenAI互換API';

  @override
  String get settings_llmProviderOllama => 'Ollama';

  @override
  String get settings_endpointUrlLabel => 'エンドポイントURL';

  @override
  String get settings_apiKeyLabel => 'APIキー';

  @override
  String get settings_modelNameLabel => 'モデル名';

  @override
  String get settings_modelDataDownload => 'モデルデータダウンロード';

  @override
  String get settings_modelDownloadCompleted => 'モデルダウンロード済み';

  @override
  String get settings_retryButton => '再試行';

  @override
  String get settings_ttsEngine => 'TTSエンジン';

  @override
  String get settings_modelLabel => 'モデル';

  @override
  String get settings_piperDownloaded => 'ダウンロード済み';

  @override
  String get settings_piperLengthScale => '速度 (lengthScale)';

  @override
  String get settings_piperNoiseScale => '抑揚 (noiseScale)';

  @override
  String get settings_piperNoiseW => 'ノイズ (noiseW)';

  @override
  String get settings_voiceModelTitle => '音声モデル';

  @override
  String get settings_voiceModelSmall => '高速 (0.6B)';

  @override
  String get settings_voiceModelLarge => '高精度 (1.7B)';

  @override
  String get settings_ttsLanguageLabel => '読み上げ言語';

  @override
  String get settings_referenceAudioLabel => 'リファレンス音声ファイル';

  @override
  String get settings_voicesPlacementHint => 'voicesフォルダに音声ファイルを配置してください';

  @override
  String get settings_referenceAudioNone => 'なし（デフォルト音声）';

  @override
  String get settings_renameFileTooltip => 'ファイル名を変更';

  @override
  String get settings_recordVoiceTooltip => '音声を録音';

  @override
  String get settings_refreshFileListTooltip => 'ファイル一覧を更新';

  @override
  String get settings_openVoicesFolderTooltip => 'voicesフォルダを開く';

  @override
  String get settings_dragAudioFilesHere => '音声ファイルをここにドロップ';

  @override
  String get settings_selectLibraryFirst => '先にライブラリを選択してください';

  @override
  String settings_fileOperationError(String message) {
    return 'ファイル操作エラー: $message';
  }

  @override
  String get settings_modelListFetching => 'モデル一覧を取得中...';

  @override
  String settings_modelListFetchError(String message) {
    return 'モデル一覧の取得エラー: $message';
  }

  @override
  String get settings_selectModelHint => 'モデルを選択';

  @override
  String get settings_renameFileTitle => 'ファイル名の変更';

  @override
  String get settings_languageTitle => '言語';

  @override
  String get voiceRecording_title => '音声録音';

  @override
  String get voiceRecording_micAccessDenied => 'マイクへのアクセスが許可されていません';

  @override
  String voiceRecording_startRecordingFailed(String message) {
    return '録音の開始に失敗しました: $message';
  }

  @override
  String voiceRecording_stopRecordingFailed(String message) {
    return '録音の停止に失敗しました: $message';
  }

  @override
  String voiceRecording_saveFailed(String message) {
    return '保存に失敗しました: $message';
  }

  @override
  String get voiceRecording_discardTitle => '録音の破棄';

  @override
  String get voiceRecording_discardConfirmation => '録音中です。録音を破棄してダイアログを閉じますか？';

  @override
  String get voiceRecording_discardButton => '破棄';

  @override
  String get voiceRecording_recording => '録音中...';

  @override
  String get voiceRecording_startInstructions => '録音ボタンを押して録音を開始してください';

  @override
  String get voiceRecording_startButton => '録音開始';

  @override
  String get voiceRecording_stopButton => '停止';

  @override
  String get voiceRecording_invalidCharsError => '使用できない文字が含まれています';

  @override
  String get voiceRecording_enterFileNameTitle => 'ファイル名の入力';

  @override
  String get voiceRecording_saveButton => '保存';

  @override
  String get fileBrowser_selectFolderPrompt => 'フォルダを選択してください';

  @override
  String get fileBrowser_goToParentFolder => '親フォルダへ';

  @override
  String get fileBrowser_noFilesFound => 'テキストファイルが見つかりません';

  @override
  String get fileBrowser_refreshMenuItem => '更新';

  @override
  String get fileBrowser_renameMenuItem => 'タイトル変更';

  @override
  String get fileBrowser_deleteMenuItem => '削除';

  @override
  String get fileBrowser_moveMenuItem => '移動';

  @override
  String get fileBrowser_renameFolderMenuItem => 'フォルダ名変更';

  @override
  String get fileBrowser_newFolderTooltip => '新規フォルダ';

  @override
  String get fileBrowser_newFolderTitle => '新規フォルダ';

  @override
  String get fileBrowser_folderNameLabel => 'フォルダ名';

  @override
  String get fileBrowser_createButton => '作成';

  @override
  String get fileBrowser_renameFolderTitle => 'フォルダ名を変更';

  @override
  String get fileBrowser_moveDialogTitle => '移動先を選択';

  @override
  String get fileBrowser_moveLibraryRoot => 'ライブラリ（最上位）';

  @override
  String get fileBrowser_deleteFolderTitle => 'フォルダを削除';

  @override
  String fileBrowser_deleteFolderConfirmation(String name) {
    return 'フォルダ「$name」を削除しますか？';
  }

  @override
  String get fileBrowser_errorInvalidName => 'フォルダ名に使用できない文字が含まれています';

  @override
  String get fileBrowser_errorNameCollision => '同名のフォルダが既に存在します';

  @override
  String get fileBrowser_errorFolderNotEmpty => 'フォルダが空ではないため削除できません';

  @override
  String get fileBrowser_errorMoveIntoSelf => 'フォルダを自分自身またはその中へは移動できません';

  @override
  String fileBrowser_createFolderFailed(String message) {
    return 'フォルダの作成に失敗しました: $message';
  }

  @override
  String fileBrowser_renameFolderFailed(String message) {
    return 'フォルダ名の変更に失敗しました: $message';
  }

  @override
  String fileBrowser_moveFailed(String message) {
    return '移動に失敗しました: $message';
  }

  @override
  String get fileBrowser_downloadInProgressWarning => 'ダウンロード中です。完了後に再度お試しください';

  @override
  String fileBrowser_renameFailed(String message) {
    return 'タイトル変更に失敗しました: $message';
  }

  @override
  String get fileBrowser_deleteNovelTitle => '小説を削除';

  @override
  String fileBrowser_deleteNovelConfirmation(String name) {
    return '「$name」を削除しますか？\nすべてのエピソードとデータが完全に削除されます。';
  }

  @override
  String fileBrowser_deleteFailed(String message) {
    return '削除に失敗しました: $message';
  }

  @override
  String fileBrowser_refreshProgressTitle(String title) {
    return '「$title」を更新中';
  }

  @override
  String fileBrowser_skippedEpisodesSuffix(int count) {
    return '（$count スキップ）';
  }

  @override
  String fileBrowser_episodeCountFormat(int total, String skipped) {
    return '$total エピソード$skipped';
  }

  @override
  String fileBrowser_refreshCompleted(String summary) {
    return '更新が完了しました。$summary';
  }

  @override
  String fileBrowser_refreshError(String message) {
    return 'エラー: $message';
  }

  @override
  String get ttsEdit_title => '読み上げ編集';

  @override
  String get ttsEdit_dictionaryButton => '辞書';

  @override
  String get ttsEdit_playAllButton => '全再生';

  @override
  String get ttsEdit_stopButton => '停止';

  @override
  String get ttsEdit_cancelButton => '中断';

  @override
  String get ttsEdit_generateAllButton => '全生成';

  @override
  String get ttsEdit_resetAllTitle => '全消去';

  @override
  String get ttsEdit_resetAllConfirmation => 'すべてのセグメントを初期状態に戻しますか？';

  @override
  String get ttsEdit_resetButton => '消去';

  @override
  String get ttsEdit_resetAllButton => '全消去';

  @override
  String get ttsEdit_generatingStatus => '生成中';

  @override
  String get ttsEdit_playingStatus => '再生中';

  @override
  String get ttsEdit_generatedStatus => '生成済み';

  @override
  String get ttsEdit_ungeneratedStatus => '未生成';

  @override
  String get ttsEdit_referenceSettingValue => '設定値';

  @override
  String get ttsEdit_referenceNone => 'なし';

  @override
  String get ttsEdit_memoHint => 'メモ';

  @override
  String get ttsEdit_playTooltip => '再生';

  @override
  String get ttsEdit_regenerateTooltip => '再生成';

  @override
  String get ttsEdit_resetTooltip => 'リセット';

  @override
  String get textViewer_deleteAudioTitle => '音声データの削除';

  @override
  String get textViewer_deleteAudioConfirmation => '音声データを削除しますか？';

  @override
  String get textViewer_exportCompleted => 'MP3ファイルのエクスポートが完了しました';

  @override
  String get textViewer_ttsGenerationFailed => '音声の生成に失敗しました';

  @override
  String textViewer_exportError(String message) {
    return 'エクスポートエラー: $message';
  }

  @override
  String textViewer_generationProgressFormat(int current, int total) {
    return '$current/$total文';
  }

  @override
  String get textViewer_editTtsTooltip => '読み上げ編集';

  @override
  String get textViewer_generateTtsTooltip => '読み上げ音声生成';

  @override
  String get textViewer_pauseTooltip => '一時停止';

  @override
  String get textViewer_stopTooltip => '停止';

  @override
  String get textViewer_resumeTooltip => '再開';

  @override
  String get textViewer_cancelTooltip => 'キャンセル';

  @override
  String get textViewer_playTooltip => '再生';

  @override
  String get textViewer_exportMp3Tooltip => 'MP3エクスポート';

  @override
  String get textViewer_deleteAudioTooltip => '音声データ削除';

  @override
  String get textViewer_selectFilePrompt => 'ファイルを選択してください';

  @override
  String get download_title => '小説ダウンロード';

  @override
  String get download_invalidUrlError => '有効なURLを入力してください';

  @override
  String get download_unsupportedSiteError =>
      'サポートされていないサイトです（なろう・なろう18・カクヨム・青空文庫・ハーメルンに対応）';

  @override
  String download_skippedSuffix(int count) {
    return '(スキップ: $count件)';
  }

  @override
  String download_failedSuffix(int count) {
    return '(失敗: $count件)';
  }

  @override
  String download_progressFormat(int current, int total, String skipped) {
    return 'ダウンロード中: $current/$total エピソード$skipped';
  }

  @override
  String download_completedFormat(int total, String skipped) {
    return 'ダウンロード完了: $total エピソード$skipped';
  }

  @override
  String download_errorFormat(String message) {
    return 'エラー: $message';
  }

  @override
  String get download_downloadingButton => 'ダウンロード中...';

  @override
  String get download_startButton => 'ダウンロード開始';

  @override
  String get download_indexTruncatedWarning =>
      '目次の取得が途中で失敗しました（一部のエピソードが取得できていない可能性があります）';

  @override
  String get download_cancelledMessage => 'ダウンロードを中断しました';

  @override
  String get download_destinationLabel => '保存先フォルダ';

  @override
  String get download_destinationRoot => 'ライブラリルート（既定）';

  @override
  String get ttsDictionary_title => '読み上げ辞書';

  @override
  String get ttsDictionary_bothFieldsRequired => '表記と読みの両方を入力してください';

  @override
  String get ttsDictionary_duplicateEntry => '同じ表記が既に登録されています';

  @override
  String get ttsDictionary_surfaceLabel => '表記';

  @override
  String get ttsDictionary_surfaceHint => '山田太郎';

  @override
  String get ttsDictionary_readingLabel => '読み';

  @override
  String get ttsDictionary_readingHint => 'やまだたろう';

  @override
  String get ttsDictionary_addTooltip => '追加';

  @override
  String get ttsDictionary_emptyMessage => '辞書にエントリがありません\n上のフォームから追加してください';

  @override
  String get ttsDictionary_deleteTooltip => '削除';

  @override
  String get contextMenu_addToDictionary => '辞書追加';

  @override
  String get contextMenu_copy => 'コピー';

  @override
  String get contextMenu_analyzeNoSpoiler => '解析開始(ネタバレなし)';

  @override
  String get contextMenu_analyzeSpoiler => '解析開始(ネタバレあり)';

  @override
  String get contextMenu_copySubmenu => 'コピー';

  @override
  String contextMenu_copySnapshotByEpisode(int episode) {
    return '$episodeファイル時点の要約をコピー';
  }

  @override
  String get contextMenu_copiedToClipboard => 'クリップボードにコピーしました';

  @override
  String get llmAnalysis_inProgress => '解析中…';

  @override
  String llmAnalysis_extractingFacts(int current, int total) {
    return '情報を抽出中 ($current / $total)';
  }

  @override
  String llmAnalysis_refiningRound(int round, int current, int total) {
    return '絞り込み $round 周目 ($current / $total)';
  }

  @override
  String get llmAnalysis_generatingFinal => '最終要約を生成中…';

  @override
  String get llmAnalysis_noFolderOpen => '小説フォルダを開いてください';

  @override
  String get llmAnalysis_noLlmConfigured => '設定画面でLLMを設定してください';

  @override
  String llmAnalysis_failed(String error) {
    return '解析失敗: $error';
  }

  @override
  String llmAnalysis_savedSummary(String word) {
    return '「$word」の要約を保存しました';
  }

  @override
  String hoverPopup_snapshotLabel(int episode) {
    return '$episodeファイル時点の要約';
  }

  @override
  String get hoverPopup_futureSnapshotWarning => '現在より先の解析です';

  @override
  String get hoverPopup_reanalyzeButton => '再解析';

  @override
  String hoverPopup_reanalyzeUpToCurrent(int episode) {
    return '現在ページまで ($episodeファイル時点)';
  }

  @override
  String hoverPopup_reanalyzeUpToAll(int episode) {
    return '全話まで ($episodeファイル時点)';
  }

  @override
  String get hoverPopup_reanalyzeOverwriteSuffix => ' (上書き)';

  @override
  String get hoverPopup_snapshotNavPrev => '前のスナップショット';

  @override
  String get hoverPopup_snapshotNavNext => '次のスナップショット';

  @override
  String get bookmark_selectNovelPrompt => '作品フォルダを選択してください';

  @override
  String get bookmark_noBookmarks => 'ブックマークがありません';

  @override
  String get bookmark_deleteMenuItem => '削除';

  @override
  String get bookmark_fileNotFound => 'ファイルが見つかりません';

  @override
  String get textSearch_hintText => '検索...';

  @override
  String get textSearch_enterQueryPrompt => '検索語を入力してください';

  @override
  String get textSearch_noResults => '検索結果がありません';

  @override
  String get renameTitle_title => 'タイトル変更';

  @override
  String get renameTitle_newTitleLabel => '新しいタイトル';

  @override
  String get renameTitle_changeButton => '変更';

  @override
  String get homeScreen_removeBookmarkTooltip => 'ブックマーク解除';

  @override
  String get homeScreen_addBookmarkTooltip => 'ブックマーク登録';

  @override
  String get homeScreen_hideRightColumnTooltip => '右カラムを非表示';

  @override
  String get homeScreen_showRightColumnTooltip => '右カラムを表示';

  @override
  String get homeScreen_downloadTooltip => '小説ダウンロード';

  @override
  String get leftColumn_filesTab => 'ファイル';

  @override
  String get leftColumn_bookmarksTab => 'ブックマーク';

  @override
  String get leftColumn_historyTab => '解析履歴';

  @override
  String get llmHistory_noEntries => '解析履歴がありません';

  @override
  String llmHistory_snapshotsBadge(int count) {
    return '$countスナップショット';
  }

  @override
  String get llmHistory_untrackedBadge => '未追跡';

  @override
  String verticalText_nextEpisodePrompt(String name) {
    return '▶ 次話「$name」へ（もう一度）';
  }

  @override
  String verticalText_prevEpisodePrompt(String name) {
    return '◀ 前話「$name」へ（もう一度）';
  }

  @override
  String get textViewer_nextEpisodeButton => '次話 →';

  @override
  String get textViewer_prevEpisodeButton => '← 前話';

  @override
  String get update_badgeTooltip => '更新があります';

  @override
  String get update_dialogTitle => '新しいバージョンが利用可能です';

  @override
  String update_versionTransition(String current, String newVersion) {
    return '$current → $newVersion';
  }

  @override
  String get update_releaseNotesLabel => 'リリースノート';

  @override
  String get update_noReleaseNotes => 'リリースノートはありません';

  @override
  String get update_updateButton => '更新する';

  @override
  String get update_openReleasePageButton => 'リリースページを開く';

  @override
  String get update_laterButton => '後で';

  @override
  String get update_downloadingLabel => 'ダウンロード中...';

  @override
  String get update_failedMessage => 'アップデートに失敗しました';

  @override
  String get update_failedChecksumMessage => 'アップデートに失敗しました（チェックサム不一致）';

  @override
  String get update_missingAssetMessage => 'インストーラが見つかりませんでした';

  @override
  String get update_retryButton => '再試行';

  @override
  String get settings_aboutUpdateTab => 'アプリ情報 / 更新';

  @override
  String get settings_currentVersionLabel => '現在のバージョン';

  @override
  String get settings_buildNumberLabel => 'ビルド番号';

  @override
  String get settings_distributionLabel => '配布形態';

  @override
  String get settings_distributionInstaller => 'インストーラ版';

  @override
  String get settings_distributionPortable => 'ポータブル版 (ZIP)';

  @override
  String get settings_lastCheckedLabel => '最終確認';

  @override
  String get settings_lastCheckedNever => '未確認';

  @override
  String get settings_checkForUpdatesButton => '更新を確認';

  @override
  String get settings_autoCheckLabel => '自動チェック';

  @override
  String get settings_checkingMessage => '確認中...';

  @override
  String get settings_upToDateMessage => '最新です';

  @override
  String settings_updateAvailableMessage(String version) {
    return '$version が利用可能';
  }

  @override
  String get settings_checkFailedMessage => '更新の確認に失敗しました';

  @override
  String get settings_shortcutsSection => 'キーボードショートカット';

  @override
  String get settings_shortcutReassign => '変更';

  @override
  String get settings_shortcutResetDefaults => '既定に戻す';

  @override
  String get settings_shortcutPressKeys => '新しいキーの組み合わせを押してください…';

  @override
  String get settings_shortcutDuplicate => 'そのキーは既に他の操作に割り当てられています';

  @override
  String get shortcutAction_search => '検索';

  @override
  String get shortcutAction_bookmark => 'しおり';

  @override
  String get shortcutAction_ttsToggle => '読み上げ 再生/一時停止';

  @override
  String get shortcutAction_switchPane => 'ペイン切替';
}
