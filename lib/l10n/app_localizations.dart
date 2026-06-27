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

  /// No description provided for @settings_ttsEngine.
  ///
  /// In ja, this message translates to:
  /// **'TTSエンジン'**
  String get settings_ttsEngine;

  /// No description provided for @settings_modelLabel.
  ///
  /// In ja, this message translates to:
  /// **'モデル'**
  String get settings_modelLabel;

  /// No description provided for @settings_piperDownloaded.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード済み'**
  String get settings_piperDownloaded;

  /// No description provided for @settings_piperLengthScale.
  ///
  /// In ja, this message translates to:
  /// **'速度 (lengthScale)'**
  String get settings_piperLengthScale;

  /// No description provided for @settings_piperNoiseScale.
  ///
  /// In ja, this message translates to:
  /// **'抑揚 (noiseScale)'**
  String get settings_piperNoiseScale;

  /// No description provided for @settings_piperNoiseW.
  ///
  /// In ja, this message translates to:
  /// **'ノイズ (noiseW)'**
  String get settings_piperNoiseW;

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

  /// No description provided for @fileBrowser_moveMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'移動'**
  String get fileBrowser_moveMenuItem;

  /// No description provided for @fileBrowser_renameFolderMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'フォルダ名変更'**
  String get fileBrowser_renameFolderMenuItem;

  /// No description provided for @fileBrowser_newFolderTooltip.
  ///
  /// In ja, this message translates to:
  /// **'新規フォルダ'**
  String get fileBrowser_newFolderTooltip;

  /// No description provided for @fileBrowser_newFolderTitle.
  ///
  /// In ja, this message translates to:
  /// **'新規フォルダ'**
  String get fileBrowser_newFolderTitle;

  /// No description provided for @fileBrowser_folderNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'フォルダ名'**
  String get fileBrowser_folderNameLabel;

  /// No description provided for @fileBrowser_createButton.
  ///
  /// In ja, this message translates to:
  /// **'作成'**
  String get fileBrowser_createButton;

  /// No description provided for @fileBrowser_renameFolderTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォルダ名を変更'**
  String get fileBrowser_renameFolderTitle;

  /// No description provided for @fileBrowser_moveDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'移動先を選択'**
  String get fileBrowser_moveDialogTitle;

  /// No description provided for @fileBrowser_moveLibraryRoot.
  ///
  /// In ja, this message translates to:
  /// **'ライブラリ（最上位）'**
  String get fileBrowser_moveLibraryRoot;

  /// No description provided for @fileBrowser_deleteFolderTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォルダを削除'**
  String get fileBrowser_deleteFolderTitle;

  /// No description provided for @fileBrowser_deleteFolderConfirmation.
  ///
  /// In ja, this message translates to:
  /// **'フォルダ「{name}」を削除しますか？'**
  String fileBrowser_deleteFolderConfirmation(String name);

  /// No description provided for @fileBrowser_errorInvalidName.
  ///
  /// In ja, this message translates to:
  /// **'フォルダ名に使用できない文字が含まれています'**
  String get fileBrowser_errorInvalidName;

  /// No description provided for @fileBrowser_errorNameCollision.
  ///
  /// In ja, this message translates to:
  /// **'同名のフォルダが既に存在します'**
  String get fileBrowser_errorNameCollision;

  /// No description provided for @fileBrowser_errorFolderNotEmpty.
  ///
  /// In ja, this message translates to:
  /// **'フォルダが空ではないため削除できません'**
  String get fileBrowser_errorFolderNotEmpty;

  /// No description provided for @fileBrowser_errorMoveIntoSelf.
  ///
  /// In ja, this message translates to:
  /// **'フォルダを自分自身またはその中へは移動できません'**
  String get fileBrowser_errorMoveIntoSelf;

  /// No description provided for @fileBrowser_createFolderFailed.
  ///
  /// In ja, this message translates to:
  /// **'フォルダの作成に失敗しました: {message}'**
  String fileBrowser_createFolderFailed(String message);

  /// No description provided for @fileBrowser_renameFolderFailed.
  ///
  /// In ja, this message translates to:
  /// **'フォルダ名の変更に失敗しました: {message}'**
  String fileBrowser_renameFolderFailed(String message);

  /// No description provided for @fileBrowser_moveFailed.
  ///
  /// In ja, this message translates to:
  /// **'移動に失敗しました: {message}'**
  String fileBrowser_moveFailed(String message);

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

  /// No description provided for @textViewer_ttsGenerationFailed.
  ///
  /// In ja, this message translates to:
  /// **'音声の生成に失敗しました'**
  String get textViewer_ttsGenerationFailed;

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
  /// **'サポートされていないサイトです（なろう・なろう18・カクヨム・青空文庫・ハーメルンに対応）'**
  String get download_unsupportedSiteError;

  /// No description provided for @download_skippedSuffix.
  ///
  /// In ja, this message translates to:
  /// **'(スキップ: {count}件)'**
  String download_skippedSuffix(int count);

  /// No description provided for @download_failedSuffix.
  ///
  /// In ja, this message translates to:
  /// **'(失敗: {count}件)'**
  String download_failedSuffix(int count);

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

  /// No description provided for @download_indexTruncatedWarning.
  ///
  /// In ja, this message translates to:
  /// **'目次の取得が途中で失敗しました（一部のエピソードが取得できていない可能性があります）'**
  String get download_indexTruncatedWarning;

  /// No description provided for @download_cancelledMessage.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロードを中断しました'**
  String get download_cancelledMessage;

  /// No description provided for @download_destinationLabel.
  ///
  /// In ja, this message translates to:
  /// **'保存先フォルダ'**
  String get download_destinationLabel;

  /// No description provided for @download_destinationRoot.
  ///
  /// In ja, this message translates to:
  /// **'ライブラリルート（既定）'**
  String get download_destinationRoot;

  /// No description provided for @download_collectionTargetLabel.
  ///
  /// In ja, this message translates to:
  /// **'取り込み先'**
  String get download_collectionTargetLabel;

  /// No description provided for @download_collectionNew.
  ///
  /// In ja, this message translates to:
  /// **'新規コレクション'**
  String get download_collectionNew;

  /// No description provided for @download_collectionExisting.
  ///
  /// In ja, this message translates to:
  /// **'既存コレクションに追加'**
  String get download_collectionExisting;

  /// No description provided for @download_collectionNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'コレクション名'**
  String get download_collectionNameLabel;

  /// No description provided for @download_collectionNameHint.
  ///
  /// In ja, this message translates to:
  /// **'空欄なら記事タイトルを使用'**
  String get download_collectionNameHint;

  /// No description provided for @download_collectionSelectLabel.
  ///
  /// In ja, this message translates to:
  /// **'コレクションを選択'**
  String get download_collectionSelectLabel;

  /// No description provided for @download_collectionNoneExisting.
  ///
  /// In ja, this message translates to:
  /// **'既存のコレクションがありません'**
  String get download_collectionNoneExisting;

  /// No description provided for @download_createCollectionTitle.
  ///
  /// In ja, this message translates to:
  /// **'新規コレクションを作成'**
  String get download_createCollectionTitle;

  /// No description provided for @download_createCollectionHint.
  ///
  /// In ja, this message translates to:
  /// **'コレクション名'**
  String get download_createCollectionHint;

  /// No description provided for @download_createCollectionButton.
  ///
  /// In ja, this message translates to:
  /// **'作成'**
  String get download_createCollectionButton;

  /// No description provided for @fileBrowser_newCollection.
  ///
  /// In ja, this message translates to:
  /// **'新規コレクション'**
  String get fileBrowser_newCollection;

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

  /// No description provided for @contextMenu_addToDictionary.
  ///
  /// In ja, this message translates to:
  /// **'辞書追加'**
  String get contextMenu_addToDictionary;

  /// No description provided for @contextMenu_copy.
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get contextMenu_copy;

  /// No description provided for @contextMenu_analyzeNoSpoiler.
  ///
  /// In ja, this message translates to:
  /// **'解析開始(ネタバレなし)'**
  String get contextMenu_analyzeNoSpoiler;

  /// No description provided for @contextMenu_analyzeSpoiler.
  ///
  /// In ja, this message translates to:
  /// **'解析開始(ネタバレあり)'**
  String get contextMenu_analyzeSpoiler;

  /// No description provided for @contextMenu_copySubmenu.
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get contextMenu_copySubmenu;

  /// No description provided for @contextMenu_copySnapshotByEpisode.
  ///
  /// In ja, this message translates to:
  /// **'{episode}ファイル時点の要約をコピー'**
  String contextMenu_copySnapshotByEpisode(int episode);

  /// No description provided for @contextMenu_copiedToClipboard.
  ///
  /// In ja, this message translates to:
  /// **'クリップボードにコピーしました'**
  String get contextMenu_copiedToClipboard;

  /// No description provided for @llmAnalysis_inProgress.
  ///
  /// In ja, this message translates to:
  /// **'解析中…'**
  String get llmAnalysis_inProgress;

  /// No description provided for @llmAnalysis_extractingFacts.
  ///
  /// In ja, this message translates to:
  /// **'情報を抽出中 ({current} / {total})'**
  String llmAnalysis_extractingFacts(int current, int total);

  /// No description provided for @llmAnalysis_refiningRound.
  ///
  /// In ja, this message translates to:
  /// **'絞り込み {round} 周目 ({current} / {total})'**
  String llmAnalysis_refiningRound(int round, int current, int total);

  /// No description provided for @llmAnalysis_generatingFinal.
  ///
  /// In ja, this message translates to:
  /// **'最終要約を生成中…'**
  String get llmAnalysis_generatingFinal;

  /// No description provided for @llmAnalysis_noFolderOpen.
  ///
  /// In ja, this message translates to:
  /// **'小説フォルダを開いてください'**
  String get llmAnalysis_noFolderOpen;

  /// No description provided for @llmAnalysis_noLlmConfigured.
  ///
  /// In ja, this message translates to:
  /// **'設定画面でLLMを設定してください'**
  String get llmAnalysis_noLlmConfigured;

  /// No description provided for @llmAnalysis_failed.
  ///
  /// In ja, this message translates to:
  /// **'解析失敗: {error}'**
  String llmAnalysis_failed(String error);

  /// No description provided for @llmAnalysis_savedSummary.
  ///
  /// In ja, this message translates to:
  /// **'「{word}」の要約を保存しました'**
  String llmAnalysis_savedSummary(String word);

  /// No description provided for @hoverPopup_snapshotLabel.
  ///
  /// In ja, this message translates to:
  /// **'{episode}ファイル時点の要約'**
  String hoverPopup_snapshotLabel(int episode);

  /// No description provided for @hoverPopup_futureSnapshotWarning.
  ///
  /// In ja, this message translates to:
  /// **'現在より先の解析です'**
  String get hoverPopup_futureSnapshotWarning;

  /// No description provided for @hoverPopup_reanalyzeButton.
  ///
  /// In ja, this message translates to:
  /// **'再解析'**
  String get hoverPopup_reanalyzeButton;

  /// No description provided for @hoverPopup_reanalyzeUpToCurrent.
  ///
  /// In ja, this message translates to:
  /// **'現在ページまで ({episode}ファイル時点)'**
  String hoverPopup_reanalyzeUpToCurrent(int episode);

  /// No description provided for @hoverPopup_reanalyzeUpToAll.
  ///
  /// In ja, this message translates to:
  /// **'全話まで ({episode}ファイル時点)'**
  String hoverPopup_reanalyzeUpToAll(int episode);

  /// No description provided for @hoverPopup_reanalyzeOverwriteSuffix.
  ///
  /// In ja, this message translates to:
  /// **' (上書き)'**
  String get hoverPopup_reanalyzeOverwriteSuffix;

  /// No description provided for @hoverPopup_snapshotNavPrev.
  ///
  /// In ja, this message translates to:
  /// **'前のスナップショット'**
  String get hoverPopup_snapshotNavPrev;

  /// No description provided for @hoverPopup_snapshotNavNext.
  ///
  /// In ja, this message translates to:
  /// **'次のスナップショット'**
  String get hoverPopup_snapshotNavNext;

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

  /// No description provided for @leftColumn_historyTab.
  ///
  /// In ja, this message translates to:
  /// **'解析履歴'**
  String get leftColumn_historyTab;

  /// No description provided for @llmHistory_noEntries.
  ///
  /// In ja, this message translates to:
  /// **'解析履歴がありません'**
  String get llmHistory_noEntries;

  /// No description provided for @llmHistory_snapshotsBadge.
  ///
  /// In ja, this message translates to:
  /// **'{count}スナップショット'**
  String llmHistory_snapshotsBadge(int count);

  /// No description provided for @llmHistory_untrackedBadge.
  ///
  /// In ja, this message translates to:
  /// **'未追跡'**
  String get llmHistory_untrackedBadge;

  /// No description provided for @contextMenu_viewDetails.
  ///
  /// In ja, this message translates to:
  /// **'詳細を表示'**
  String get contextMenu_viewDetails;

  /// No description provided for @historyDetail_dialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'「{word}」の詳細'**
  String historyDetail_dialogTitle(String word);

  /// No description provided for @historyDetail_factsTab.
  ///
  /// In ja, this message translates to:
  /// **'事実'**
  String get historyDetail_factsTab;

  /// No description provided for @historyDetail_resultTab.
  ///
  /// In ja, this message translates to:
  /// **'解析結果'**
  String get historyDetail_resultTab;

  /// No description provided for @historyDetail_invalidBadge.
  ///
  /// In ja, this message translates to:
  /// **'無効'**
  String get historyDetail_invalidBadge;

  /// No description provided for @historyDetail_noFacts.
  ///
  /// In ja, this message translates to:
  /// **'事実がありません'**
  String get historyDetail_noFacts;

  /// No description provided for @historyDetail_noResults.
  ///
  /// In ja, this message translates to:
  /// **'解析結果がありません'**
  String get historyDetail_noResults;

  /// No description provided for @verticalText_nextEpisodePrompt.
  ///
  /// In ja, this message translates to:
  /// **'▶ 次話「{name}」へ（もう一度）'**
  String verticalText_nextEpisodePrompt(String name);

  /// No description provided for @verticalText_prevEpisodePrompt.
  ///
  /// In ja, this message translates to:
  /// **'◀ 前話「{name}」へ（もう一度）'**
  String verticalText_prevEpisodePrompt(String name);

  /// No description provided for @update_badgeTooltip.
  ///
  /// In ja, this message translates to:
  /// **'更新があります'**
  String get update_badgeTooltip;

  /// No description provided for @update_dialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'新しいバージョンが利用可能です'**
  String get update_dialogTitle;

  /// No description provided for @update_versionTransition.
  ///
  /// In ja, this message translates to:
  /// **'{current} → {newVersion}'**
  String update_versionTransition(String current, String newVersion);

  /// No description provided for @update_releaseNotesLabel.
  ///
  /// In ja, this message translates to:
  /// **'リリースノート'**
  String get update_releaseNotesLabel;

  /// No description provided for @update_noReleaseNotes.
  ///
  /// In ja, this message translates to:
  /// **'リリースノートはありません'**
  String get update_noReleaseNotes;

  /// No description provided for @update_updateButton.
  ///
  /// In ja, this message translates to:
  /// **'更新する'**
  String get update_updateButton;

  /// No description provided for @update_openReleasePageButton.
  ///
  /// In ja, this message translates to:
  /// **'リリースページを開く'**
  String get update_openReleasePageButton;

  /// No description provided for @update_laterButton.
  ///
  /// In ja, this message translates to:
  /// **'後で'**
  String get update_laterButton;

  /// No description provided for @update_downloadingLabel.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード中...'**
  String get update_downloadingLabel;

  /// No description provided for @update_failedMessage.
  ///
  /// In ja, this message translates to:
  /// **'アップデートに失敗しました'**
  String get update_failedMessage;

  /// No description provided for @update_failedChecksumMessage.
  ///
  /// In ja, this message translates to:
  /// **'アップデートに失敗しました（チェックサム不一致）'**
  String get update_failedChecksumMessage;

  /// No description provided for @update_missingAssetMessage.
  ///
  /// In ja, this message translates to:
  /// **'インストーラが見つかりませんでした'**
  String get update_missingAssetMessage;

  /// No description provided for @update_retryButton.
  ///
  /// In ja, this message translates to:
  /// **'再試行'**
  String get update_retryButton;

  /// No description provided for @settings_aboutUpdateTab.
  ///
  /// In ja, this message translates to:
  /// **'アプリ情報 / 更新'**
  String get settings_aboutUpdateTab;

  /// No description provided for @settings_currentVersionLabel.
  ///
  /// In ja, this message translates to:
  /// **'現在のバージョン'**
  String get settings_currentVersionLabel;

  /// No description provided for @settings_buildNumberLabel.
  ///
  /// In ja, this message translates to:
  /// **'ビルド番号'**
  String get settings_buildNumberLabel;

  /// No description provided for @settings_distributionLabel.
  ///
  /// In ja, this message translates to:
  /// **'配布形態'**
  String get settings_distributionLabel;

  /// No description provided for @settings_distributionInstaller.
  ///
  /// In ja, this message translates to:
  /// **'インストーラ版'**
  String get settings_distributionInstaller;

  /// No description provided for @settings_distributionPortable.
  ///
  /// In ja, this message translates to:
  /// **'ポータブル版 (ZIP)'**
  String get settings_distributionPortable;

  /// No description provided for @settings_lastCheckedLabel.
  ///
  /// In ja, this message translates to:
  /// **'最終確認'**
  String get settings_lastCheckedLabel;

  /// No description provided for @settings_lastCheckedNever.
  ///
  /// In ja, this message translates to:
  /// **'未確認'**
  String get settings_lastCheckedNever;

  /// No description provided for @settings_checkForUpdatesButton.
  ///
  /// In ja, this message translates to:
  /// **'更新を確認'**
  String get settings_checkForUpdatesButton;

  /// No description provided for @settings_autoCheckLabel.
  ///
  /// In ja, this message translates to:
  /// **'自動チェック'**
  String get settings_autoCheckLabel;

  /// No description provided for @settings_checkingMessage.
  ///
  /// In ja, this message translates to:
  /// **'確認中...'**
  String get settings_checkingMessage;

  /// No description provided for @settings_upToDateMessage.
  ///
  /// In ja, this message translates to:
  /// **'最新です'**
  String get settings_upToDateMessage;

  /// No description provided for @settings_updateAvailableMessage.
  ///
  /// In ja, this message translates to:
  /// **'{version} が利用可能'**
  String settings_updateAvailableMessage(String version);

  /// No description provided for @settings_checkFailedMessage.
  ///
  /// In ja, this message translates to:
  /// **'更新の確認に失敗しました'**
  String get settings_checkFailedMessage;

  /// No description provided for @settings_shortcutsSection.
  ///
  /// In ja, this message translates to:
  /// **'キーボードショートカット'**
  String get settings_shortcutsSection;

  /// No description provided for @settings_shortcutReassign.
  ///
  /// In ja, this message translates to:
  /// **'変更'**
  String get settings_shortcutReassign;

  /// No description provided for @settings_shortcutResetDefaults.
  ///
  /// In ja, this message translates to:
  /// **'既定に戻す'**
  String get settings_shortcutResetDefaults;

  /// No description provided for @settings_shortcutPressKeys.
  ///
  /// In ja, this message translates to:
  /// **'新しいキーの組み合わせを押してください…'**
  String get settings_shortcutPressKeys;

  /// No description provided for @settings_shortcutDuplicate.
  ///
  /// In ja, this message translates to:
  /// **'そのキーは既に他の操作に割り当てられています'**
  String get settings_shortcutDuplicate;

  /// No description provided for @settings_shortcutNeedsModifier.
  ///
  /// In ja, this message translates to:
  /// **'ショートカットには修飾キー（Ctrl/Cmd/Alt）が必要です'**
  String get settings_shortcutNeedsModifier;

  /// No description provided for @shortcutAction_search.
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get shortcutAction_search;

  /// No description provided for @shortcutAction_bookmark.
  ///
  /// In ja, this message translates to:
  /// **'しおり'**
  String get shortcutAction_bookmark;

  /// No description provided for @shortcutAction_ttsToggle.
  ///
  /// In ja, this message translates to:
  /// **'読み上げ 再生/一時停止'**
  String get shortcutAction_ttsToggle;

  /// No description provided for @shortcutAction_switchPane.
  ///
  /// In ja, this message translates to:
  /// **'ペイン切替'**
  String get shortcutAction_switchPane;
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
