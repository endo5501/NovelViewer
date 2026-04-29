// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get common_closeButton => '关闭';

  @override
  String get common_cancelButton => '取消';

  @override
  String get common_changeButton => '更改';

  @override
  String get common_deleteButton => '删除';

  @override
  String common_errorPrefix(String message) {
    return '错误：$message';
  }

  @override
  String get common_fileDuplicateError => '已存在同名文件';

  @override
  String get common_fileNameLabel => '文件名';

  @override
  String get common_unknownError => '未知错误';

  @override
  String get settings_title => '设置';

  @override
  String get settings_generalTabLabel => '通用';

  @override
  String get settings_ttsTabLabel => '语音朗读';

  @override
  String get settings_verticalDisplayTitle => '竖排显示';

  @override
  String get settings_verticalDisplayVertical => '竖排';

  @override
  String get settings_verticalDisplayHorizontal => '横排';

  @override
  String get settings_darkModeTitle => '深色模式';

  @override
  String get settings_darkModeDark => '深色';

  @override
  String get settings_darkModeLight => '浅色';

  @override
  String get settings_fontSizeTitle => '字体大小';

  @override
  String get settings_fontFamilyTitle => '字体类型';

  @override
  String get settings_columnSpacingTitle => '列间距';

  @override
  String get settings_llmProviderTitle => 'LLM提供商';

  @override
  String get settings_llmProviderNone => '未设置';

  @override
  String get settings_llmProviderOpenai => 'OpenAI兼容API';

  @override
  String get settings_llmProviderOllama => 'Ollama';

  @override
  String get settings_endpointUrlLabel => '端点URL';

  @override
  String get settings_apiKeyLabel => 'API密钥';

  @override
  String get settings_modelNameLabel => '模型名称';

  @override
  String get settings_modelDataDownload => '下载模型数据';

  @override
  String get settings_modelDownloadCompleted => '模型已下载';

  @override
  String get settings_retryButton => '重试';

  @override
  String get settings_ttsEngine => 'TTS 引擎';

  @override
  String get settings_modelLabel => '模型';

  @override
  String get settings_piperDownloaded => '已下载';

  @override
  String get settings_piperLengthScale => '速度 (lengthScale)';

  @override
  String get settings_piperNoiseScale => '抑扬 (noiseScale)';

  @override
  String get settings_piperNoiseW => '噪声 (noiseW)';

  @override
  String get settings_voiceModelTitle => '语音模型';

  @override
  String get settings_voiceModelSmall => '快速 (0.6B)';

  @override
  String get settings_voiceModelLarge => '高精度 (1.7B)';

  @override
  String get settings_ttsLanguageLabel => '朗读语言';

  @override
  String get settings_referenceAudioLabel => '参考音频文件';

  @override
  String get settings_voicesPlacementHint => '请将音频文件放入voices文件夹';

  @override
  String get settings_referenceAudioNone => '无（默认语音）';

  @override
  String get settings_renameFileTooltip => '重命名文件';

  @override
  String get settings_recordVoiceTooltip => '录制语音';

  @override
  String get settings_refreshFileListTooltip => '刷新文件列表';

  @override
  String get settings_openVoicesFolderTooltip => '打开voices文件夹';

  @override
  String get settings_dragAudioFilesHere => '将音频文件拖放到此处';

  @override
  String get settings_selectLibraryFirst => '请先选择书库';

  @override
  String settings_fileOperationError(String message) {
    return '文件操作错误：$message';
  }

  @override
  String get settings_modelListFetching => '正在获取模型列表...';

  @override
  String settings_modelListFetchError(String message) {
    return '获取模型列表出错：$message';
  }

  @override
  String get settings_selectModelHint => '选择模型';

  @override
  String get settings_renameFileTitle => '重命名文件';

  @override
  String get settings_languageTitle => '语言';

  @override
  String get voiceRecording_title => '录音';

  @override
  String get voiceRecording_micAccessDenied => '未授权访问麦克风';

  @override
  String voiceRecording_startRecordingFailed(String message) {
    return '开始录音失败：$message';
  }

  @override
  String voiceRecording_stopRecordingFailed(String message) {
    return '停止录音失败：$message';
  }

  @override
  String voiceRecording_saveFailed(String message) {
    return '保存失败：$message';
  }

  @override
  String get voiceRecording_discardTitle => '丢弃录音';

  @override
  String get voiceRecording_discardConfirmation => '正在录音中。是否丢弃录音并关闭对话框？';

  @override
  String get voiceRecording_discardButton => '丢弃';

  @override
  String get voiceRecording_recording => '录音中...';

  @override
  String get voiceRecording_startInstructions => '请按录音按钮开始录音';

  @override
  String get voiceRecording_startButton => '开始录音';

  @override
  String get voiceRecording_stopButton => '停止';

  @override
  String get voiceRecording_invalidCharsError => '包含无效字符';

  @override
  String get voiceRecording_enterFileNameTitle => '输入文件名';

  @override
  String get voiceRecording_saveButton => '保存';

  @override
  String get fileBrowser_selectFolderPrompt => '请选择文件夹';

  @override
  String get fileBrowser_goToParentFolder => '返回上级文件夹';

  @override
  String get fileBrowser_noFilesFound => '未找到文本文件';

  @override
  String get fileBrowser_refreshMenuItem => '刷新';

  @override
  String get fileBrowser_renameMenuItem => '重命名';

  @override
  String get fileBrowser_deleteMenuItem => '删除';

  @override
  String get fileBrowser_downloadInProgressWarning => '正在下载中，请稍后再试';

  @override
  String fileBrowser_renameFailed(String message) {
    return '重命名失败：$message';
  }

  @override
  String get fileBrowser_deleteNovelTitle => '删除小说';

  @override
  String fileBrowser_deleteNovelConfirmation(String name) {
    return '确定删除“$name”吗？\n所有章节和数据将被永久删除。';
  }

  @override
  String fileBrowser_deleteFailed(String message) {
    return '删除失败：$message';
  }

  @override
  String fileBrowser_refreshProgressTitle(String title) {
    return '正在更新“$title”';
  }

  @override
  String fileBrowser_skippedEpisodesSuffix(int count) {
    return '（跳过$count章）';
  }

  @override
  String fileBrowser_episodeCountFormat(int total, String skipped) {
    return '$total 章节$skipped';
  }

  @override
  String fileBrowser_refreshCompleted(String summary) {
    return '更新完成。$summary';
  }

  @override
  String fileBrowser_refreshError(String message) {
    return '错误：$message';
  }

  @override
  String get ttsEdit_title => '朗读编辑';

  @override
  String get ttsEdit_dictionaryButton => '词典';

  @override
  String get ttsEdit_playAllButton => '全部播放';

  @override
  String get ttsEdit_stopButton => '停止';

  @override
  String get ttsEdit_cancelButton => '中断';

  @override
  String get ttsEdit_generateAllButton => '全部生成';

  @override
  String get ttsEdit_resetAllTitle => '全部清除';

  @override
  String get ttsEdit_resetAllConfirmation => '确定将所有片段恢复到初始状态吗？';

  @override
  String get ttsEdit_resetButton => '清除';

  @override
  String get ttsEdit_resetAllButton => '全部清除';

  @override
  String get ttsEdit_generatingStatus => '生成中';

  @override
  String get ttsEdit_playingStatus => '播放中';

  @override
  String get ttsEdit_generatedStatus => '已生成';

  @override
  String get ttsEdit_ungeneratedStatus => '未生成';

  @override
  String get ttsEdit_referenceSettingValue => '设置值';

  @override
  String get ttsEdit_referenceNone => '无';

  @override
  String get ttsEdit_memoHint => '备注';

  @override
  String get ttsEdit_playTooltip => '播放';

  @override
  String get ttsEdit_regenerateTooltip => '重新生成';

  @override
  String get ttsEdit_resetTooltip => '重置';

  @override
  String get textViewer_deleteAudioTitle => '删除音频数据';

  @override
  String get textViewer_deleteAudioConfirmation => '确定删除音频数据吗？';

  @override
  String get textViewer_exportCompleted => 'MP3导出完成';

  @override
  String textViewer_exportError(String message) {
    return '导出错误：$message';
  }

  @override
  String textViewer_generationProgressFormat(int current, int total) {
    return '$current/$total句';
  }

  @override
  String get textViewer_editTtsTooltip => '编辑朗读';

  @override
  String get textViewer_generateTtsTooltip => '生成朗读音频';

  @override
  String get textViewer_pauseTooltip => '暂停';

  @override
  String get textViewer_stopTooltip => '停止';

  @override
  String get textViewer_resumeTooltip => '继续';

  @override
  String get textViewer_cancelTooltip => '取消';

  @override
  String get textViewer_playTooltip => '播放';

  @override
  String get textViewer_exportMp3Tooltip => '导出MP3';

  @override
  String get textViewer_deleteAudioTooltip => '删除音频数据';

  @override
  String get textViewer_selectFilePrompt => '请选择文件';

  @override
  String get download_title => '下载小说';

  @override
  String get download_invalidUrlError => '请输入有效的URL';

  @override
  String get download_unsupportedSiteError =>
      '不支持的网站（支持Narou、Narou18、Kakuyomu和青空文库）';

  @override
  String download_skippedSuffix(int count) {
    return '（跳过：$count个）';
  }

  @override
  String download_progressFormat(int current, int total, String skipped) {
    return '下载中：$current/$total 章节$skipped';
  }

  @override
  String download_completedFormat(int total, String skipped) {
    return '下载完成：$total 章节$skipped';
  }

  @override
  String download_errorFormat(String message) {
    return '错误：$message';
  }

  @override
  String get download_downloadingButton => '下载中...';

  @override
  String get download_startButton => '开始下载';

  @override
  String get ttsDictionary_title => '朗读词典';

  @override
  String get ttsDictionary_bothFieldsRequired => '请同时输入表记和读音';

  @override
  String get ttsDictionary_duplicateEntry => '已存在相同表记的条目';

  @override
  String get ttsDictionary_surfaceLabel => '表记';

  @override
  String get ttsDictionary_surfaceHint => '张三';

  @override
  String get ttsDictionary_readingLabel => '读音';

  @override
  String get ttsDictionary_readingHint => 'zhāngsān';

  @override
  String get ttsDictionary_addTooltip => '添加';

  @override
  String get ttsDictionary_emptyMessage => '词典中没有条目\n请使用上方的表单添加';

  @override
  String get ttsDictionary_deleteTooltip => '删除';

  @override
  String get contextMenu_addToDictionary => '添加到词典';

  @override
  String get contextMenu_copy => '复制';

  @override
  String get llmSummary_noSpoilerTab => '无剧透';

  @override
  String get llmSummary_spoilerTab => '有剧透';

  @override
  String get llmSummary_selectWordPrompt => '请选择一个词语';

  @override
  String get llmSummary_configureLlmPrompt => '请在设置中配置LLM';

  @override
  String get llmSummary_referencePositionWarning => '参考位置不同，建议重新分析。';

  @override
  String get llmSummary_analyzeButton => '开始分析';

  @override
  String get bookmark_selectNovelPrompt => '请选择作品文件夹';

  @override
  String get bookmark_noBookmarks => '没有书签';

  @override
  String get bookmark_deleteMenuItem => '删除';

  @override
  String get bookmark_fileNotFound => '未找到文件';

  @override
  String get textSearch_hintText => '搜索...';

  @override
  String get textSearch_enterQueryPrompt => '请输入搜索词';

  @override
  String get textSearch_noResults => '没有搜索结果';

  @override
  String get renameTitle_title => '更改标题';

  @override
  String get renameTitle_newTitleLabel => '新标题';

  @override
  String get renameTitle_changeButton => '更改';

  @override
  String get homeScreen_removeBookmarkTooltip => '取消书签';

  @override
  String get homeScreen_addBookmarkTooltip => '添加书签';

  @override
  String get homeScreen_hideRightColumnTooltip => '隐藏右栏';

  @override
  String get homeScreen_showRightColumnTooltip => '显示右栏';

  @override
  String get homeScreen_downloadTooltip => '下载小说';

  @override
  String get leftColumn_filesTab => '文件';

  @override
  String get leftColumn_bookmarksTab => '书签';
}
