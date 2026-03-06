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
      'サポートされていないサイトです（なろう・なろう18・カクヨムに対応）';

  @override
  String download_skippedSuffix(int count) {
    return '(スキップ: $count件)';
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
  String get llmSummary_noSpoilerTab => 'ネタバレなし';

  @override
  String get llmSummary_spoilerTab => 'ネタバレあり';

  @override
  String get llmSummary_selectWordPrompt => '単語を選択してください';

  @override
  String get llmSummary_configureLlmPrompt => '設定画面でLLMを設定してください';

  @override
  String get llmSummary_referencePositionWarning => '基準位置が異なります。再解析をお勧めします。';

  @override
  String get llmSummary_analyzeButton => '解析開始';

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
}
