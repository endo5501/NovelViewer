// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get common_closeButton => 'Close';

  @override
  String get common_cancelButton => 'Cancel';

  @override
  String get common_changeButton => 'Change';

  @override
  String get common_deleteButton => 'Delete';

  @override
  String common_errorPrefix(String message) {
    return 'Error: $message';
  }

  @override
  String get common_fileDuplicateError =>
      'A file with the same name already exists';

  @override
  String get common_fileNameLabel => 'File name';

  @override
  String get common_unknownError => 'Unknown error';

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_generalTabLabel => 'General';

  @override
  String get settings_ttsTabLabel => 'Text-to-Speech';

  @override
  String get settings_verticalDisplayTitle => 'Vertical writing';

  @override
  String get settings_verticalDisplayVertical => 'Vertical';

  @override
  String get settings_verticalDisplayHorizontal => 'Horizontal';

  @override
  String get settings_darkModeTitle => 'Dark mode';

  @override
  String get settings_darkModeDark => 'Dark';

  @override
  String get settings_darkModeLight => 'Light';

  @override
  String get settings_fontSizeTitle => 'Font size';

  @override
  String get settings_fontFamilyTitle => 'Font family';

  @override
  String get settings_columnSpacingTitle => 'Column spacing';

  @override
  String get settings_llmProviderTitle => 'LLM Provider';

  @override
  String get settings_llmProviderNone => 'Not configured';

  @override
  String get settings_llmProviderOpenai => 'OpenAI-compatible API';

  @override
  String get settings_llmProviderOllama => 'Ollama';

  @override
  String get settings_endpointUrlLabel => 'Endpoint URL';

  @override
  String get settings_apiKeyLabel => 'API Key';

  @override
  String get settings_modelNameLabel => 'Model name';

  @override
  String get settings_modelDataDownload => 'Download model data';

  @override
  String get settings_modelDownloadCompleted => 'Model downloaded';

  @override
  String get settings_retryButton => 'Retry';

  @override
  String get settings_voiceModelTitle => 'Voice model';

  @override
  String get settings_voiceModelSmall => 'Fast (0.6B)';

  @override
  String get settings_voiceModelLarge => 'High quality (1.7B)';

  @override
  String get settings_ttsLanguageLabel => 'TTS language';

  @override
  String get settings_referenceAudioLabel => 'Reference audio file';

  @override
  String get settings_voicesPlacementHint =>
      'Place audio files in the voices folder';

  @override
  String get settings_referenceAudioNone => 'None (default voice)';

  @override
  String get settings_renameFileTooltip => 'Rename file';

  @override
  String get settings_recordVoiceTooltip => 'Record voice';

  @override
  String get settings_refreshFileListTooltip => 'Refresh file list';

  @override
  String get settings_openVoicesFolderTooltip => 'Open voices folder';

  @override
  String get settings_dragAudioFilesHere => 'Drop audio files here';

  @override
  String get settings_selectLibraryFirst => 'Please select a library first';

  @override
  String settings_fileOperationError(String message) {
    return 'File operation error: $message';
  }

  @override
  String get settings_modelListFetching => 'Fetching model list...';

  @override
  String settings_modelListFetchError(String message) {
    return 'Error fetching model list: $message';
  }

  @override
  String get settings_selectModelHint => 'Select a model';

  @override
  String get settings_renameFileTitle => 'Rename file';

  @override
  String get settings_languageTitle => 'Language';

  @override
  String get voiceRecording_title => 'Voice recording';

  @override
  String get voiceRecording_micAccessDenied =>
      'Microphone access is not permitted';

  @override
  String voiceRecording_startRecordingFailed(String message) {
    return 'Failed to start recording: $message';
  }

  @override
  String voiceRecording_stopRecordingFailed(String message) {
    return 'Failed to stop recording: $message';
  }

  @override
  String voiceRecording_saveFailed(String message) {
    return 'Failed to save: $message';
  }

  @override
  String get voiceRecording_discardTitle => 'Discard recording';

  @override
  String get voiceRecording_discardConfirmation =>
      'Recording is in progress. Discard the recording and close the dialog?';

  @override
  String get voiceRecording_discardButton => 'Discard';

  @override
  String get voiceRecording_recording => 'Recording...';

  @override
  String get voiceRecording_startInstructions =>
      'Press the record button to start recording';

  @override
  String get voiceRecording_startButton => 'Start recording';

  @override
  String get voiceRecording_stopButton => 'Stop';

  @override
  String get voiceRecording_invalidCharsError => 'Contains invalid characters';

  @override
  String get voiceRecording_enterFileNameTitle => 'Enter file name';

  @override
  String get voiceRecording_saveButton => 'Save';

  @override
  String get fileBrowser_selectFolderPrompt => 'Please select a folder';

  @override
  String get fileBrowser_goToParentFolder => 'Go to parent folder';

  @override
  String get fileBrowser_noFilesFound => 'No text files found';

  @override
  String get fileBrowser_refreshMenuItem => 'Refresh';

  @override
  String get fileBrowser_renameMenuItem => 'Rename';

  @override
  String get fileBrowser_deleteMenuItem => 'Delete';

  @override
  String get fileBrowser_downloadInProgressWarning =>
      'Download in progress. Please try again later';

  @override
  String fileBrowser_renameFailed(String message) {
    return 'Failed to rename: $message';
  }

  @override
  String get fileBrowser_deleteNovelTitle => 'Delete novel';

  @override
  String fileBrowser_deleteNovelConfirmation(String name) {
    return 'Delete “$name”?\nAll episodes and data will be permanently deleted.';
  }

  @override
  String fileBrowser_deleteFailed(String message) {
    return 'Failed to delete: $message';
  }

  @override
  String fileBrowser_refreshProgressTitle(String title) {
    return 'Updating “$title”';
  }

  @override
  String fileBrowser_skippedEpisodesSuffix(int count) {
    return '($count skipped)';
  }

  @override
  String fileBrowser_episodeCountFormat(int total, String skipped) {
    return '$total episodes$skipped';
  }

  @override
  String fileBrowser_refreshCompleted(String summary) {
    return 'Update completed.$summary';
  }

  @override
  String fileBrowser_refreshError(String message) {
    return 'Error: $message';
  }

  @override
  String get ttsEdit_title => 'TTS Editor';

  @override
  String get ttsEdit_dictionaryButton => 'Dictionary';

  @override
  String get ttsEdit_playAllButton => 'Play all';

  @override
  String get ttsEdit_stopButton => 'Stop';

  @override
  String get ttsEdit_cancelButton => 'Cancel';

  @override
  String get ttsEdit_generateAllButton => 'Generate all';

  @override
  String get ttsEdit_resetAllTitle => 'Reset all';

  @override
  String get ttsEdit_resetAllConfirmation =>
      'Reset all segments to their initial state?';

  @override
  String get ttsEdit_resetButton => 'Reset';

  @override
  String get ttsEdit_resetAllButton => 'Reset all';

  @override
  String get ttsEdit_generatingStatus => 'Generating';

  @override
  String get ttsEdit_playingStatus => 'Playing';

  @override
  String get ttsEdit_generatedStatus => 'Generated';

  @override
  String get ttsEdit_ungeneratedStatus => 'Not generated';

  @override
  String get ttsEdit_referenceSettingValue => 'Setting value';

  @override
  String get ttsEdit_referenceNone => 'None';

  @override
  String get ttsEdit_memoHint => 'Memo';

  @override
  String get ttsEdit_playTooltip => 'Play';

  @override
  String get ttsEdit_regenerateTooltip => 'Regenerate';

  @override
  String get ttsEdit_resetTooltip => 'Reset';

  @override
  String get textViewer_deleteAudioTitle => 'Delete audio data';

  @override
  String get textViewer_deleteAudioConfirmation => 'Delete audio data?';

  @override
  String get textViewer_exportCompleted => 'MP3 export completed';

  @override
  String textViewer_exportError(String message) {
    return 'Export error: $message';
  }

  @override
  String textViewer_generationProgressFormat(int current, int total) {
    return '$current/$total sentences';
  }

  @override
  String get textViewer_editTtsTooltip => 'Edit TTS';

  @override
  String get textViewer_generateTtsTooltip => 'Generate TTS audio';

  @override
  String get textViewer_pauseTooltip => 'Pause';

  @override
  String get textViewer_stopTooltip => 'Stop';

  @override
  String get textViewer_resumeTooltip => 'Resume';

  @override
  String get textViewer_cancelTooltip => 'Cancel';

  @override
  String get textViewer_playTooltip => 'Play';

  @override
  String get textViewer_exportMp3Tooltip => 'Export MP3';

  @override
  String get textViewer_deleteAudioTooltip => 'Delete audio data';

  @override
  String get textViewer_selectFilePrompt => 'Please select a file';

  @override
  String get download_title => 'Download novel';

  @override
  String get download_invalidUrlError => 'Please enter a valid URL';

  @override
  String get download_unsupportedSiteError =>
      'Unsupported site (supports Narou, Narou18, and Kakuyomu)';

  @override
  String download_skippedSuffix(int count) {
    return '(skipped: $count)';
  }

  @override
  String download_progressFormat(int current, int total, String skipped) {
    return 'Downloading: $current/$total episodes$skipped';
  }

  @override
  String download_completedFormat(int total, String skipped) {
    return 'Download complete: $total episodes$skipped';
  }

  @override
  String download_errorFormat(String message) {
    return 'Error: $message';
  }

  @override
  String get download_downloadingButton => 'Downloading...';

  @override
  String get download_startButton => 'Start download';

  @override
  String get ttsDictionary_title => 'TTS Dictionary';

  @override
  String get ttsDictionary_bothFieldsRequired =>
      'Both surface form and reading are required';

  @override
  String get ttsDictionary_duplicateEntry =>
      'An entry with the same surface form already exists';

  @override
  String get ttsDictionary_surfaceLabel => 'Surface form';

  @override
  String get ttsDictionary_surfaceHint => 'Yamada Taro';

  @override
  String get ttsDictionary_readingLabel => 'Reading';

  @override
  String get ttsDictionary_readingHint => 'yamada taro';

  @override
  String get ttsDictionary_addTooltip => 'Add';

  @override
  String get ttsDictionary_emptyMessage =>
      'No dictionary entries\nAdd entries using the form above';

  @override
  String get ttsDictionary_deleteTooltip => 'Delete';

  @override
  String get contextMenu_addToDictionary => 'Add to Dictionary';

  @override
  String get contextMenu_copy => 'Copy';

  @override
  String get llmSummary_noSpoilerTab => 'No spoilers';

  @override
  String get llmSummary_spoilerTab => 'With spoilers';

  @override
  String get llmSummary_selectWordPrompt => 'Please select a word';

  @override
  String get llmSummary_configureLlmPrompt =>
      'Please configure LLM in Settings';

  @override
  String get llmSummary_referencePositionWarning =>
      'Reference position differs. Re-analysis is recommended.';

  @override
  String get llmSummary_analyzeButton => 'Analyze';

  @override
  String get bookmark_selectNovelPrompt => 'Please select a novel folder';

  @override
  String get bookmark_noBookmarks => 'No bookmarks';

  @override
  String get bookmark_deleteMenuItem => 'Delete';

  @override
  String get bookmark_fileNotFound => 'File not found';

  @override
  String get textSearch_hintText => 'Search...';

  @override
  String get textSearch_enterQueryPrompt => 'Please enter a search term';

  @override
  String get textSearch_noResults => 'No search results';

  @override
  String get renameTitle_title => 'Rename';

  @override
  String get renameTitle_newTitleLabel => 'New title';

  @override
  String get renameTitle_changeButton => 'Change';

  @override
  String get homeScreen_removeBookmarkTooltip => 'Remove bookmark';

  @override
  String get homeScreen_addBookmarkTooltip => 'Add bookmark';

  @override
  String get homeScreen_hideRightColumnTooltip => 'Hide right column';

  @override
  String get homeScreen_showRightColumnTooltip => 'Show right column';

  @override
  String get homeScreen_downloadTooltip => 'Download novel';

  @override
  String get leftColumn_filesTab => 'Files';

  @override
  String get leftColumn_bookmarksTab => 'Bookmarks';
}
