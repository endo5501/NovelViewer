import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// No description provided for @common_closeButton.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get common_closeButton;

  /// No description provided for @common_cancelButton.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get common_cancelButton;

  /// No description provided for @common_changeButton.
  ///
  /// In ja, this message translates to:
  /// **'変更'**
  String get common_changeButton;

  /// No description provided for @common_deleteButton.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get common_deleteButton;

  /// No description provided for @common_errorPrefix.
  ///
  /// In ja, this message translates to:
  /// **'エラー: {message}'**
  String common_errorPrefix(String message);

  /// No description provided for @common_fileDuplicateError.
  ///
  /// In ja, this message translates to:
  /// **'同名のファイルが既に存在します'**
  String get common_fileDuplicateError;

  /// No description provided for @common_fileNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'ファイル名'**
  String get common_fileNameLabel;

  /// No description provided for @common_unknownError.
  ///
  /// In ja, this message translates to:
  /// **'不明なエラー'**
  String get common_unknownError;

  /// No description provided for @settings_title.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settings_title;

  /// No description provided for @settings_generalTabLabel.
  ///
  /// In ja, this message translates to:
  /// **'一般'**
  String get settings_generalTabLabel;

  /// No description provided for @settings_ttsTabLabel.
  ///
  /// In ja, this message translates to:
  /// **'読み上げ'**
  String get settings_ttsTabLabel;

  /// No description provided for @settings_verticalDisplayTitle.
  ///
  /// In ja, this message translates to:
  /// **'縦書き表示'**
  String get settings_verticalDisplayTitle;

  /// No description provided for @settings_verticalDisplayVertical.
  ///
  /// In ja, this message translates to:
  /// **'縦書き'**
  String get settings_verticalDisplayVertical;

  /// No description provided for @settings_verticalDisplayHorizontal.
  ///
  /// In ja, this message translates to:
  /// **'横書き'**
  String get settings_verticalDisplayHorizontal;

  /// No description provided for @settings_darkModeTitle.
  ///
  /// In ja, this message translates to:
  /// **'ダークモード'**
  String get settings_darkModeTitle;

  /// No description provided for @settings_darkModeDark.
  ///
  /// In ja, this message translates to:
  /// **'ダーク'**
  String get settings_darkModeDark;

  /// No description provided for @settings_darkModeLight.
  ///
  /// In ja, this message translates to:
  /// **'ライト'**
  String get settings_darkModeLight;

  /// No description provided for @settings_fontSizeTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォントサイズ'**
  String get settings_fontSizeTitle;

  /// No description provided for @settings_fontFamilyTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォント種別'**
  String get settings_fontFamilyTitle;

  /// No description provided for @settings_columnSpacingTitle.
  ///
  /// In ja, this message translates to:
  /// **'列間隔'**
  String get settings_columnSpacingTitle;

  /// No description provided for @settings_llmProviderTitle.
  ///
  /// In ja, this message translates to:
  /// **'LLMプロバイダ'**
  String get settings_llmProviderTitle;

  /// No description provided for @settings_llmProviderNone.
  ///
  /// In ja, this message translates to:
  /// **'未設定'**
  String get settings_llmProviderNone;

  /// No description provided for @settings_llmProviderOpenai.
  ///
  /// In ja, this message translates to:
  /// **'OpenAI互換API'**
  String get settings_llmProviderOpenai;

  /// No description provided for @settings_llmProviderOllama.
  ///
  /// In ja, this message translates to:
  /// **'Ollama'**
  String get settings_llmProviderOllama;

  /// No description provided for @settings_endpointUrlLabel.
  ///
  /// In ja, this message translates to:
  /// **'エンドポイントURL'**
  String get settings_endpointUrlLabel;

  /// No description provided for @settings_apiKeyLabel.
  ///
  /// In ja, this message translates to:
  /// **'APIキー'**
  String get settings_apiKeyLabel;

  /// No description provided for @settings_modelNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'モデル名'**
  String get settings_modelNameLabel;

  /// No description provided for @settings_modelDataDownload.
  ///
  /// In ja, this message translates to:
  /// **'モデルデータダウンロード'**
  String get settings_modelDataDownload;

  /// No description provided for @settings_modelDownloadCompleted.
  ///
  /// In ja, this message translates to:
  /// **'モデルダウンロード済み'**
  String get settings_modelDownloadCompleted;

  /// No description provided for @settings_retryButton.
  ///
  /// In ja, this message translates to:
  /// **'再試行'**
  String get settings_retryButton;

  /// No description provided for @settings_voiceModelTitle.
  ///
  /// In ja, this message translates to:
  /// **'音声モデル'**
  String get settings_voiceModelTitle;

  /// No description provided for @settings_voiceModelSmall.
  ///
  /// In ja, this message translates to:
  /// **'高速 (0.6B)'**
  String get settings_voiceModelSmall;

  /// No description provided for @settings_voiceModelLarge.
  ///
  /// In ja, this message translates to:
  /// **'高精度 (1.7B)'**
  String get settings_voiceModelLarge;

  /// No description provided for @settings_ttsLanguageLabel.
  ///
  /// In ja, this message translates to:
  /// **'読み上げ言語'**
  String get settings_ttsLanguageLabel;

  /// No description provided for @settings_referenceAudioLabel.
  ///
  /// In ja, this message translates to:
  /// **'リファレンス音声ファイル'**
  String get settings_referenceAudioLabel;

  /// No description provided for @settings_voicesPlacementHint.
  ///
  /// In ja, this message translates to:
  /// **'voicesフォルダに音声ファイルを配置してください'**
  String get settings_voicesPlacementHint;

  /// No description provided for @settings_referenceAudioNone.
  ///
  /// In ja, this message translates to:
  /// **'なし（デフォルト音声）'**
  String get settings_referenceAudioNone;

  /// No description provided for @settings_renameFileTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ファイル名を変更'**
  String get settings_renameFileTooltip;

  /// No description provided for @settings_recordVoiceTooltip.
  ///
  /// In ja, this message translates to:
  /// **'音声を録音'**
  String get settings_recordVoiceTooltip;

  /// No description provided for @settings_refreshFileListTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ファイル一覧を更新'**
  String get settings_refreshFileListTooltip;

  /// No description provided for @settings_openVoicesFolderTooltip.
  ///
  /// In ja, this message translates to:
  /// **'voicesフォルダを開く'**
  String get settings_openVoicesFolderTooltip;

  /// No description provided for @settings_dragAudioFilesHere.
  ///
  /// In ja, this message translates to:
  /// **'音声ファイルをここにドロップ'**
  String get settings_dragAudioFilesHere;

  /// No description provided for @settings_selectLibraryFirst.
  ///
  /// In ja, this message translates to:
  /// **'先にライブラリを選択してください'**
  String get settings_selectLibraryFirst;

  /// No description provided for @settings_fileOperationError.
  ///
  /// In ja, this message translates to:
  /// **'ファイル操作エラー: {message}'**
  String settings_fileOperationError(String message);

  /// No description provided for @settings_modelListFetching.
  ///
  /// In ja, this message translates to:
  /// **'モデル一覧を取得中...'**
  String get settings_modelListFetching;

  /// No description provided for @settings_modelListFetchError.
  ///
  /// In ja, this message translates to:
  /// **'モデル一覧の取得エラー: {message}'**
  String settings_modelListFetchError(String message);

  /// No description provided for @settings_selectModelHint.
  ///
  /// In ja, this message translates to:
  /// **'モデルを選択'**
  String get settings_selectModelHint;

  /// No description provided for @settings_renameFileTitle.
  ///
  /// In ja, this message translates to:
  /// **'ファイル名の変更'**
  String get settings_renameFileTitle;

  /// No description provided for @settings_languageTitle.
  ///
  /// In ja, this message translates to:
  /// **'言語'**
  String get settings_languageTitle;

  /// No description provided for @voiceRecording_title.
  ///
  /// In ja, this message translates to:
  /// **'音声録音'**
  String get voiceRecording_title;

  /// No description provided for @voiceRecording_micAccessDenied.
  ///
  /// In ja, this message translates to:
  /// **'マイクへのアクセスが許可されていません'**
  String get voiceRecording_micAccessDenied;

  /// No description provided for @voiceRecording_startRecordingFailed.
  ///
  /// In ja, this message translates to:
  /// **'録音の開始に失敗しました: {message}'**
  String voiceRecording_startRecordingFailed(String message);

  /// No description provided for @voiceRecording_stopRecordingFailed.
  ///
  /// In ja, this message translates to:
  /// **'録音の停止に失敗しました: {message}'**
  String voiceRecording_stopRecordingFailed(String message);

  /// No description provided for @voiceRecording_saveFailed.
  ///
  /// In ja, this message translates to:
  /// **'保存に失敗しました: {message}'**
  String voiceRecording_saveFailed(String message);

  /// No description provided for @voiceRecording_discardTitle.
  ///
  /// In ja, this message translates to:
  /// **'録音の破棄'**
  String get voiceRecording_discardTitle;

  /// No description provided for @voiceRecording_discardConfirmation.
  ///
  /// In ja, this message translates to:
  /// **'録音中です。録音を破棄してダイアログを閉じますか？'**
  String get voiceRecording_discardConfirmation;

  /// No description provided for @voiceRecording_discardButton.
  ///
  /// In ja, this message translates to:
  /// **'破棄'**
  String get voiceRecording_discardButton;

  /// No description provided for @voiceRecording_recording.
  ///
  /// In ja, this message translates to:
  /// **'録音中...'**
  String get voiceRecording_recording;

  /// No description provided for @voiceRecording_startInstructions.
  ///
  /// In ja, this message translates to:
  /// **'録音ボタンを押して録音を開始してください'**
  String get voiceRecording_startInstructions;

  /// No description provided for @voiceRecording_startButton.
  ///
  /// In ja, this message translates to:
  /// **'録音開始'**
  String get voiceRecording_startButton;

  /// No description provided for @voiceRecording_stopButton.
  ///
  /// In ja, this message translates to:
  /// **'停止'**
  String get voiceRecording_stopButton;

  /// No description provided for @voiceRecording_invalidCharsError.
  ///
  /// In ja, this message translates to:
  /// **'使用できない文字が含まれています'**
  String get voiceRecording_invalidCharsError;

  /// No description provided for @voiceRecording_enterFileNameTitle.
  ///
  /// In ja, this message translates to:
  /// **'ファイル名の入力'**
  String get voiceRecording_enterFileNameTitle;

  /// No description provided for @voiceRecording_saveButton.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get voiceRecording_saveButton;

  /// No description provided for @fileBrowser_selectFolderPrompt.
  ///
  /// In ja, this message translates to:
  /// **'フォルダを選択してください'**
  String get fileBrowser_selectFolderPrompt;

  /// No description provided for @fileBrowser_goToParentFolder.
  ///
  /// In ja, this message translates to:
  /// **'親フォルダへ'**
  String get fileBrowser_goToParentFolder;

  /// No description provided for @fileBrowser_noFilesFound.
  ///
  /// In ja, this message translates to:
  /// **'テキストファイルが見つかりません'**
  String get fileBrowser_noFilesFound;

  /// No description provided for @fileBrowser_refreshMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'更新'**
  String get fileBrowser_refreshMenuItem;

  /// No description provided for @fileBrowser_renameMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'タイトル変更'**
  String get fileBrowser_renameMenuItem;

  /// No description provided for @fileBrowser_deleteMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get fileBrowser_deleteMenuItem;

  /// No description provided for @fileBrowser_downloadInProgressWarning.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード中です。完了後に再度お試しください'**
  String get fileBrowser_downloadInProgressWarning;

  /// No description provided for @fileBrowser_renameFailed.
  ///
  /// In ja, this message translates to:
  /// **'タイトル変更に失敗しました: {message}'**
  String fileBrowser_renameFailed(String message);

  /// No description provided for @fileBrowser_deleteNovelTitle.
  ///
  /// In ja, this message translates to:
  /// **'小説を削除'**
  String get fileBrowser_deleteNovelTitle;

  /// No description provided for @fileBrowser_deleteNovelConfirmation.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」を削除しますか？\nすべてのエピソードとデータが完全に削除されます。'**
  String fileBrowser_deleteNovelConfirmation(String name);

  /// No description provided for @fileBrowser_deleteFailed.
  ///
  /// In ja, this message translates to:
  /// **'削除に失敗しました: {message}'**
  String fileBrowser_deleteFailed(String message);

  /// No description provided for @fileBrowser_refreshProgressTitle.
  ///
  /// In ja, this message translates to:
  /// **'「{title}」を更新中'**
  String fileBrowser_refreshProgressTitle(String title);

  /// No description provided for @fileBrowser_skippedEpisodesSuffix.
  ///
  /// In ja, this message translates to:
  /// **'（{count} スキップ）'**
  String fileBrowser_skippedEpisodesSuffix(int count);

  /// No description provided for @fileBrowser_episodeCountFormat.
  ///
  /// In ja, this message translates to:
  /// **'{total} エピソード{skipped}'**
  String fileBrowser_episodeCountFormat(int total, String skipped);

  /// No description provided for @fileBrowser_refreshCompleted.
  ///
  /// In ja, this message translates to:
  /// **'更新が完了しました。{summary}'**
  String fileBrowser_refreshCompleted(String summary);

  /// No description provided for @fileBrowser_refreshError.
  ///
  /// In ja, this message translates to:
  /// **'エラー: {message}'**
  String fileBrowser_refreshError(String message);

  /// No description provided for @ttsEdit_title.
  ///
  /// In ja, this message translates to:
  /// **'読み上げ編集'**
  String get ttsEdit_title;

  /// No description provided for @ttsEdit_dictionaryButton.
  ///
  /// In ja, this message translates to:
  /// **'辞書'**
  String get ttsEdit_dictionaryButton;

  /// No description provided for @ttsEdit_playAllButton.
  ///
  /// In ja, this message translates to:
  /// **'全再生'**
  String get ttsEdit_playAllButton;

  /// No description provided for @ttsEdit_stopButton.
  ///
  /// In ja, this message translates to:
  /// **'停止'**
  String get ttsEdit_stopButton;

  /// No description provided for @ttsEdit_cancelButton.
  ///
  /// In ja, this message translates to:
  /// **'中断'**
  String get ttsEdit_cancelButton;

  /// No description provided for @ttsEdit_generateAllButton.
  ///
  /// In ja, this message translates to:
  /// **'全生成'**
  String get ttsEdit_generateAllButton;

  /// No description provided for @ttsEdit_resetAllTitle.
  ///
  /// In ja, this message translates to:
  /// **'全消去'**
  String get ttsEdit_resetAllTitle;

  /// No description provided for @ttsEdit_resetAllConfirmation.
  ///
  /// In ja, this message translates to:
  /// **'すべてのセグメントを初期状態に戻しますか？'**
  String get ttsEdit_resetAllConfirmation;

  /// No description provided for @ttsEdit_resetButton.
  ///
  /// In ja, this message translates to:
  /// **'消去'**
  String get ttsEdit_resetButton;

  /// No description provided for @ttsEdit_resetAllButton.
  ///
  /// In ja, this message translates to:
  /// **'全消去'**
  String get ttsEdit_resetAllButton;

  /// No description provided for @ttsEdit_generatingStatus.
  ///
  /// In ja, this message translates to:
  /// **'生成中'**
  String get ttsEdit_generatingStatus;

  /// No description provided for @ttsEdit_playingStatus.
  ///
  /// In ja, this message translates to:
  /// **'再生中'**
  String get ttsEdit_playingStatus;

  /// No description provided for @ttsEdit_generatedStatus.
  ///
  /// In ja, this message translates to:
  /// **'生成済み'**
  String get ttsEdit_generatedStatus;

  /// No description provided for @ttsEdit_ungeneratedStatus.
  ///
  /// In ja, this message translates to:
  /// **'未生成'**
  String get ttsEdit_ungeneratedStatus;

  /// No description provided for @ttsEdit_referenceSettingValue.
  ///
  /// In ja, this message translates to:
  /// **'設定値'**
  String get ttsEdit_referenceSettingValue;

  /// No description provided for @ttsEdit_referenceNone.
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get ttsEdit_referenceNone;

  /// No description provided for @ttsEdit_memoHint.
  ///
  /// In ja, this message translates to:
  /// **'メモ'**
  String get ttsEdit_memoHint;

  /// No description provided for @ttsEdit_playTooltip.
  ///
  /// In ja, this message translates to:
  /// **'再生'**
  String get ttsEdit_playTooltip;

  /// No description provided for @ttsEdit_regenerateTooltip.
  ///
  /// In ja, this message translates to:
  /// **'再生成'**
  String get ttsEdit_regenerateTooltip;

  /// No description provided for @ttsEdit_resetTooltip.
  ///
  /// In ja, this message translates to:
  /// **'リセット'**
  String get ttsEdit_resetTooltip;

  /// No description provided for @textViewer_deleteAudioTitle.
  ///
  /// In ja, this message translates to:
  /// **'音声データの削除'**
  String get textViewer_deleteAudioTitle;

  /// No description provided for @textViewer_deleteAudioConfirmation.
  ///
  /// In ja, this message translates to:
  /// **'音声データを削除しますか？'**
  String get textViewer_deleteAudioConfirmation;

  /// No description provided for @textViewer_exportCompleted.
  ///
  /// In ja, this message translates to:
  /// **'MP3ファイルのエクスポートが完了しました'**
  String get textViewer_exportCompleted;

  /// No description provided for @textViewer_exportError.
  ///
  /// In ja, this message translates to:
  /// **'エクスポートエラー: {message}'**
  String textViewer_exportError(String message);

  /// No description provided for @textViewer_generationProgressFormat.
  ///
  /// In ja, this message translates to:
  /// **'{current}/{total}文'**
  String textViewer_generationProgressFormat(int current, int total);

  /// No description provided for @textViewer_editTtsTooltip.
  ///
  /// In ja, this message translates to:
  /// **'読み上げ編集'**
  String get textViewer_editTtsTooltip;

  /// No description provided for @textViewer_generateTtsTooltip.
  ///
  /// In ja, this message translates to:
  /// **'読み上げ音声生成'**
  String get textViewer_generateTtsTooltip;

  /// No description provided for @textViewer_pauseTooltip.
  ///
  /// In ja, this message translates to:
  /// **'一時停止'**
  String get textViewer_pauseTooltip;

  /// No description provided for @textViewer_stopTooltip.
  ///
  /// In ja, this message translates to:
  /// **'停止'**
  String get textViewer_stopTooltip;

  /// No description provided for @textViewer_resumeTooltip.
  ///
  /// In ja, this message translates to:
  /// **'再開'**
  String get textViewer_resumeTooltip;

  /// No description provided for @textViewer_cancelTooltip.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get textViewer_cancelTooltip;

  /// No description provided for @textViewer_playTooltip.
  ///
  /// In ja, this message translates to:
  /// **'再生'**
  String get textViewer_playTooltip;

  /// No description provided for @textViewer_exportMp3Tooltip.
  ///
  /// In ja, this message translates to:
  /// **'MP3エクスポート'**
  String get textViewer_exportMp3Tooltip;

  /// No description provided for @textViewer_deleteAudioTooltip.
  ///
  /// In ja, this message translates to:
  /// **'音声データ削除'**
  String get textViewer_deleteAudioTooltip;

  /// No description provided for @textViewer_selectFilePrompt.
  ///
  /// In ja, this message translates to:
  /// **'ファイルを選択してください'**
  String get textViewer_selectFilePrompt;

  /// No description provided for @download_title.
  ///
  /// In ja, this message translates to:
  /// **'小説ダウンロード'**
  String get download_title;

  /// No description provided for @download_invalidUrlError.
  ///
  /// In ja, this message translates to:
  /// **'有効なURLを入力してください'**
  String get download_invalidUrlError;

  /// No description provided for @download_unsupportedSiteError.
  ///
  /// In ja, this message translates to:
  /// **'サポートされていないサイトです（なろう・なろう18・カクヨムに対応）'**
  String get download_unsupportedSiteError;

  /// No description provided for @download_skippedSuffix.
  ///
  /// In ja, this message translates to:
  /// **'(スキップ: {count}件)'**
  String download_skippedSuffix(int count);

  /// No description provided for @download_progressFormat.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード中: {current}/{total} エピソード{skipped}'**
  String download_progressFormat(int current, int total, String skipped);

  /// No description provided for @download_completedFormat.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード完了: {total} エピソード{skipped}'**
  String download_completedFormat(int total, String skipped);

  /// No description provided for @download_errorFormat.
  ///
  /// In ja, this message translates to:
  /// **'エラー: {message}'**
  String download_errorFormat(String message);

  /// No description provided for @download_downloadingButton.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード中...'**
  String get download_downloadingButton;

  /// No description provided for @download_startButton.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード開始'**
  String get download_startButton;

  /// No description provided for @ttsDictionary_title.
  ///
  /// In ja, this message translates to:
  /// **'読み上げ辞書'**
  String get ttsDictionary_title;

  /// No description provided for @ttsDictionary_bothFieldsRequired.
  ///
  /// In ja, this message translates to:
  /// **'表記と読みの両方を入力してください'**
  String get ttsDictionary_bothFieldsRequired;

  /// No description provided for @ttsDictionary_duplicateEntry.
  ///
  /// In ja, this message translates to:
  /// **'同じ表記が既に登録されています'**
  String get ttsDictionary_duplicateEntry;

  /// No description provided for @ttsDictionary_surfaceLabel.
  ///
  /// In ja, this message translates to:
  /// **'表記'**
  String get ttsDictionary_surfaceLabel;

  /// No description provided for @ttsDictionary_surfaceHint.
  ///
  /// In ja, this message translates to:
  /// **'山田太郎'**
  String get ttsDictionary_surfaceHint;

  /// No description provided for @ttsDictionary_readingLabel.
  ///
  /// In ja, this message translates to:
  /// **'読み'**
  String get ttsDictionary_readingLabel;

  /// No description provided for @ttsDictionary_readingHint.
  ///
  /// In ja, this message translates to:
  /// **'やまだたろう'**
  String get ttsDictionary_readingHint;

  /// No description provided for @ttsDictionary_addTooltip.
  ///
  /// In ja, this message translates to:
  /// **'追加'**
  String get ttsDictionary_addTooltip;

  /// No description provided for @ttsDictionary_emptyMessage.
  ///
  /// In ja, this message translates to:
  /// **'辞書にエントリがありません\n上のフォームから追加してください'**
  String get ttsDictionary_emptyMessage;

  /// No description provided for @ttsDictionary_deleteTooltip.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get ttsDictionary_deleteTooltip;

  /// No description provided for @llmSummary_noSpoilerTab.
  ///
  /// In ja, this message translates to:
  /// **'ネタバレなし'**
  String get llmSummary_noSpoilerTab;

  /// No description provided for @llmSummary_spoilerTab.
  ///
  /// In ja, this message translates to:
  /// **'ネタバレあり'**
  String get llmSummary_spoilerTab;

  /// No description provided for @llmSummary_selectWordPrompt.
  ///
  /// In ja, this message translates to:
  /// **'単語を選択してください'**
  String get llmSummary_selectWordPrompt;

  /// No description provided for @llmSummary_configureLlmPrompt.
  ///
  /// In ja, this message translates to:
  /// **'設定画面でLLMを設定してください'**
  String get llmSummary_configureLlmPrompt;

  /// No description provided for @llmSummary_referencePositionWarning.
  ///
  /// In ja, this message translates to:
  /// **'基準位置が異なります。再解析をお勧めします。'**
  String get llmSummary_referencePositionWarning;

  /// No description provided for @llmSummary_analyzeButton.
  ///
  /// In ja, this message translates to:
  /// **'解析開始'**
  String get llmSummary_analyzeButton;

  /// No description provided for @bookmark_selectNovelPrompt.
  ///
  /// In ja, this message translates to:
  /// **'作品フォルダを選択してください'**
  String get bookmark_selectNovelPrompt;

  /// No description provided for @bookmark_noBookmarks.
  ///
  /// In ja, this message translates to:
  /// **'ブックマークがありません'**
  String get bookmark_noBookmarks;

  /// No description provided for @bookmark_deleteMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get bookmark_deleteMenuItem;

  /// No description provided for @bookmark_fileNotFound.
  ///
  /// In ja, this message translates to:
  /// **'ファイルが見つかりません'**
  String get bookmark_fileNotFound;

  /// No description provided for @textSearch_hintText.
  ///
  /// In ja, this message translates to:
  /// **'検索...'**
  String get textSearch_hintText;

  /// No description provided for @textSearch_enterQueryPrompt.
  ///
  /// In ja, this message translates to:
  /// **'検索語を入力してください'**
  String get textSearch_enterQueryPrompt;

  /// No description provided for @textSearch_noResults.
  ///
  /// In ja, this message translates to:
  /// **'検索結果がありません'**
  String get textSearch_noResults;

  /// No description provided for @renameTitle_title.
  ///
  /// In ja, this message translates to:
  /// **'タイトル変更'**
  String get renameTitle_title;

  /// No description provided for @renameTitle_newTitleLabel.
  ///
  /// In ja, this message translates to:
  /// **'新しいタイトル'**
  String get renameTitle_newTitleLabel;

  /// No description provided for @renameTitle_changeButton.
  ///
  /// In ja, this message translates to:
  /// **'変更'**
  String get renameTitle_changeButton;

  /// No description provided for @homeScreen_removeBookmarkTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク解除'**
  String get homeScreen_removeBookmarkTooltip;

  /// No description provided for @homeScreen_addBookmarkTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク登録'**
  String get homeScreen_addBookmarkTooltip;

  /// No description provided for @homeScreen_hideRightColumnTooltip.
  ///
  /// In ja, this message translates to:
  /// **'右カラムを非表示'**
  String get homeScreen_hideRightColumnTooltip;

  /// No description provided for @homeScreen_showRightColumnTooltip.
  ///
  /// In ja, this message translates to:
  /// **'右カラムを表示'**
  String get homeScreen_showRightColumnTooltip;

  /// No description provided for @homeScreen_downloadTooltip.
  ///
  /// In ja, this message translates to:
  /// **'小説ダウンロード'**
  String get homeScreen_downloadTooltip;

  /// No description provided for @leftColumn_filesTab.
  ///
  /// In ja, this message translates to:
  /// **'ファイル'**
  String get leftColumn_filesTab;

  /// No description provided for @leftColumn_bookmarksTab.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク'**
  String get leftColumn_bookmarksTab;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
