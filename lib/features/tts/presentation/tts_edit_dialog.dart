import 'package:flutter/material.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/tts_adapters.dart';
import '../data/tts_audio_database.dart';
import '../data/tts_audio_repository.dart';
import '../data/tts_dictionary_database.dart';
import '../data/tts_dictionary_repository.dart';
import 'dictionary_context_menu.dart';
import '../data/tts_edit_controller.dart';
import '../data/tts_edit_segment.dart';
import '../data/tts_engine_type.dart';
import '../data/tts_isolate.dart';
import '../providers/tts_edit_providers.dart';
import '../providers/tts_settings_providers.dart';
import 'tts_dictionary_dialog.dart';

class TtsEditDialog extends ConsumerStatefulWidget {
  const TtsEditDialog({
    super.key,
    required this.folderPath,
    required this.fileName,
    required this.content,
  });

  final String folderPath;
  final String fileName;
  final String content;

  static Future<void> show(
    BuildContext context, {
    required String folderPath,
    required String fileName,
    required String content,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TtsEditDialog(
        folderPath: folderPath,
        fileName: fileName,
        content: content,
      ),
    );
  }

  @override
  ConsumerState<TtsEditDialog> createState() => _TtsEditDialogState();
}

class _TtsEditDialogState extends ConsumerState<TtsEditDialog> {
  TtsEditController? _controller;
  TtsAudioDatabase? _db;
  TtsDictionaryDatabase? _dictDb;
  TtsDictionaryRepository? _dictRepository;
  bool _loading = true;
  List<String> _voiceFiles = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final db = TtsAudioDatabase(widget.folderPath);
    final repo = TtsAudioRepository(db);
    final dictDb = TtsDictionaryDatabase(widget.folderPath);
    final dictRepo = TtsDictionaryRepository(dictDb);
    final tempDir = await getTemporaryDirectory();

    final controller = TtsEditController(
      ttsIsolate: TtsIsolate(),
      audioPlayer: JustAudioPlayer(),
      repository: repo,
      tempDirPath: tempDir.path,
      dictionaryRepository: dictRepo,
    );

    controller.onSegmentGenerated = (index) {
      if (!mounted) return;
      final segments = controller.segments;
      ref.read(ttsEditSegmentsProvider.notifier).set(List.of(segments));
      ref.read(ttsEditGeneratingIndexProvider.notifier).set(null);
    };

    controller.onError = (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    };

    await controller.loadSegments(
      text: widget.content,
      fileName: widget.fileName,
      sampleRate: 24000,
    );

    await _loadVoiceFiles();

    _db = db;
    _dictDb = dictDb;
    _dictRepository = dictRepo;
    _controller = controller;

    if (!mounted) return;

    ref.read(ttsEditSegmentsProvider.notifier).set(List.of(controller.segments));
    ref.read(ttsEditGenerationStateProvider.notifier)
        .set(TtsEditGenerationState.idle);
    ref.read(ttsEditGeneratingIndexProvider.notifier).set(null);
    ref.read(ttsEditPlaybackIndexProvider.notifier).set(null);

    setState(() => _loading = false);
  }

  Future<void> _loadVoiceFiles() async {
    final service = ref.read(voiceReferenceServiceProvider);
    if (service == null) return;
    final files = await service.listVoiceFiles();
    if (mounted) {
      setState(() => _voiceFiles = files);
    }
  }

  Future<void> _dispose() async {
    await _controller?.dispose();
    _controller = null;
    await _db?.close();
    _db = null;
    await _dictDb?.close();
    _dictDb = null;
    _dictRepository = null;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  String? _resolveRefWavPath(String? segmentRefWavPath) {
    final voiceService = ref.read(voiceReferenceServiceProvider);
    if (voiceService == null) return null;

    if (segmentRefWavPath != null) {
      if (segmentRefWavPath.isEmpty) return null; // "なし" - no reference audio
      return voiceService.resolveVoiceFilePath(segmentRefWavPath);
    }

    final globalRef = ref.read(ttsRefWavPathProvider);
    if (globalRef.isNotEmpty) {
      return voiceService.resolveVoiceFilePath(globalRef);
    }

    return null;
  }

  Future<void> _generateSegment(int index) async {
    final controller = _controller;
    if (controller == null) return;

    final engineType = ref.read(ttsEngineTypeProvider);
    final String modelDir;
    final String? refWavPath;
    final int languageId;
    final String? dicDir;
    final double? lengthScale;
    final double? noiseScale;
    final double? noiseW;

    if (engineType == TtsEngineType.piper) {
      final piperDir = ref.read(piperModelDirProvider);
      final modelName = ref.read(piperModelNameProvider);
      modelDir = '$piperDir/$modelName.onnx';
      dicDir = ref.read(piperDicDirProvider);
      lengthScale = ref.read(piperLengthScaleProvider);
      noiseScale = ref.read(piperNoiseScaleProvider);
      noiseW = ref.read(piperNoiseWProvider);
      refWavPath = null;
      languageId = 0;
    } else {
      modelDir = ref.read(ttsModelDirProvider);
      final segment = controller.segments[index];
      refWavPath = _resolveRefWavPath(segment.refWavPath);
      languageId = ref.read(ttsLanguageProvider).languageId;
      dicDir = null;
      lengthScale = null;
      noiseScale = null;
      noiseW = null;
    }
    if (modelDir.isEmpty) return;

    ref
        .read(ttsEditGenerationStateProvider.notifier)
        .set(TtsEditGenerationState.generating);
    ref.read(ttsEditGeneratingIndexProvider.notifier).set(index);

    await controller.generateSegment(
      segmentIndex: index,
      modelDir: modelDir,
      engineType: engineType,
      refWavPath: refWavPath,
      languageId: languageId,
      dicDir: dicDir,
      lengthScale: lengthScale,
      noiseScale: noiseScale,
      noiseW: noiseW,
    );

    if (!mounted) return;
    ref
        .read(ttsEditGenerationStateProvider.notifier)
        .set(TtsEditGenerationState.idle);
    ref.read(ttsEditGeneratingIndexProvider.notifier).set(null);
  }

  Future<void> _generateAll() async {
    final controller = _controller;
    if (controller == null) return;

    final engineType = ref.read(ttsEngineTypeProvider);
    final String modelDir;
    final String? globalRefWavPath;
    final int languageId;
    final String? dicDir;
    final double? lengthScale;
    final double? noiseScale;
    final double? noiseW;

    final voiceService = ref.read(voiceReferenceServiceProvider);

    if (engineType == TtsEngineType.piper) {
      final piperDir = ref.read(piperModelDirProvider);
      final modelName = ref.read(piperModelNameProvider);
      modelDir = '$piperDir/$modelName.onnx';
      dicDir = ref.read(piperDicDirProvider);
      lengthScale = ref.read(piperLengthScaleProvider);
      noiseScale = ref.read(piperNoiseScaleProvider);
      noiseW = ref.read(piperNoiseWProvider);
      globalRefWavPath = null;
      languageId = 0;
    } else {
      modelDir = ref.read(ttsModelDirProvider);
      final globalRefFileName = ref.read(ttsRefWavPathProvider);
      globalRefWavPath =
          globalRefFileName.isNotEmpty && voiceService != null
              ? voiceService.resolveVoiceFilePath(globalRefFileName)
              : null;
      languageId = ref.read(ttsLanguageProvider).languageId;
      dicDir = null;
      lengthScale = null;
      noiseScale = null;
      noiseW = null;
    }
    if (modelDir.isEmpty) return;

    ref
        .read(ttsEditGenerationStateProvider.notifier)
        .set(TtsEditGenerationState.generating);

    await controller.generateAllUngenerated(
      modelDir: modelDir,
      engineType: engineType,
      globalRefWavPath: globalRefWavPath,
      languageId: languageId,
      resolveRefWavPath: voiceService?.resolveVoiceFilePath,
      dicDir: dicDir,
      lengthScale: lengthScale,
      noiseScale: noiseScale,
      noiseW: noiseW,
      onSegmentStart: (index) {
        if (mounted) {
          ref.read(ttsEditGeneratingIndexProvider.notifier).set(index);
        }
      },
    );

    if (!mounted) return;
    ref.read(ttsEditSegmentsProvider.notifier).set(List.of(controller.segments));
    ref
        .read(ttsEditGenerationStateProvider.notifier)
        .set(TtsEditGenerationState.idle);
    ref.read(ttsEditGeneratingIndexProvider.notifier).set(null);
  }

  Future<void> _playSegment(int index) async {
    final controller = _controller;
    if (controller == null) return;

    ref.read(ttsEditPlaybackIndexProvider.notifier).set(index);
    await controller.playSegment(index);
    if (!mounted) return;
    ref.read(ttsEditPlaybackIndexProvider.notifier).set(null);
  }

  Future<void> _playAll() async {
    final controller = _controller;
    if (controller == null) return;

    await controller.playAll(onSegmentStart: (i) {
      if (mounted) {
        ref.read(ttsEditPlaybackIndexProvider.notifier).set(i);
      }
    });
    if (!mounted) return;
    ref.read(ttsEditPlaybackIndexProvider.notifier).set(null);
  }

  Future<void> _cancelGeneration() async {
    await _controller?.cancel();
    if (!mounted) return;
    ref.read(ttsEditGenerationStateProvider.notifier).set(TtsEditGenerationState.idle);
    ref.read(ttsEditGeneratingIndexProvider.notifier).set(null);
    ref.read(ttsEditSegmentsProvider.notifier).set(List.of(_controller?.segments ?? []));
  }

  Future<void> _stopPlayback() async {
    await _controller?.stopPlayback();
    if (!mounted) return;
    ref.read(ttsEditPlaybackIndexProvider.notifier).set(null);
  }

  Future<void> _resetSegment(int index) async {
    final controller = _controller;
    if (controller == null) return;

    await controller.resetSegment(index);
    if (!mounted) return;
    ref.read(ttsEditSegmentsProvider.notifier).set(List.of(controller.segments));
  }

  Future<void> _resetAll() async {
    final controller = _controller;
    if (controller == null) return;

    await controller.resetAll();
    if (!mounted) return;
    ref.read(ttsEditSegmentsProvider.notifier).set(List.of(controller.segments));
  }

  Future<void> _onTextEditComplete(int index, String newText) async {
    final controller = _controller;
    if (controller == null) return;

    final segment = controller.segments[index];
    if (newText == segment.text) return;

    await controller.updateSegmentText(index, newText);
    if (!mounted) return;
    ref.read(ttsEditSegmentsProvider.notifier).set(List.of(controller.segments));
  }

  Future<void> _onRefWavPathChanged(int index, String? value) async {
    final controller = _controller;
    if (controller == null) return;

    await controller.updateSegmentRefWavPath(index, value);
    if (!mounted) return;
    ref.read(ttsEditSegmentsProvider.notifier).set(List.of(controller.segments));
  }

  Future<void> _onMemoEditComplete(int index, String? memo) async {
    final controller = _controller;
    if (controller == null) return;

    final effectiveMemo = (memo != null && memo.isEmpty) ? null : memo;
    await controller.updateSegmentMemo(index, effectiveMemo);
    if (!mounted) return;
    ref.read(ttsEditSegmentsProvider.notifier).set(List.of(controller.segments));
  }

  @override
  Widget build(BuildContext context) {
    final segments = ref.watch(ttsEditSegmentsProvider);
    final generationState = ref.watch(ttsEditGenerationStateProvider);
    final generatingIndex = ref.watch(ttsEditGeneratingIndexProvider);
    final playbackIndex = ref.watch(ttsEditPlaybackIndexProvider);
    final isGenerating = generationState == TtsEditGenerationState.generating;

    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.ttsEdit_title),
      content: SizedBox(
        width: 800,
        height: 600,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildToolbar(isGenerating, playbackIndex != null),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: segments.length,
                      itemBuilder: (context, index) {
                        return _TtsEditSegmentRow(
                          segment: segments[index],
                          isGenerating:
                              isGenerating && generatingIndex == index,
                          isPlaying: playbackIndex == index,
                          voiceFiles: _voiceFiles,
                          onTextEditComplete: (text) =>
                              _onTextEditComplete(index, text),
                          onRefWavPathChanged: (value) =>
                              _onRefWavPathChanged(index, value),
                          onMemoEditComplete: (memo) =>
                              _onMemoEditComplete(index, memo),
                          onPlay: () => _playSegment(index),
                          onGenerate: () => _generateSegment(index),
                          onReset: () => _resetSegment(index),
                          enabled: !isGenerating,
                          dictRepository: _dictRepository,
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await _stopPlayback();
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: Text(AppLocalizations.of(context)!.common_closeButton),
        ),
      ],
    );
  }

  Widget _buildToolbar(bool isGenerating, bool isPlaying) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: () {
            final repo = _dictRepository;
            if (repo == null) return;
            TtsDictionaryDialog.show(context, repository: repo);
          },
          icon: const Icon(Icons.book_outlined, size: 18),
          label: Text(AppLocalizations.of(context)!.ttsEdit_dictionaryButton),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: isGenerating ? null : _playAll,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: Text(AppLocalizations.of(context)!.ttsEdit_playAllButton),
        ),
        if (isPlaying)
          TextButton.icon(
            onPressed: _stopPlayback,
            icon: const Icon(Icons.stop, size: 18),
            label: Text(AppLocalizations.of(context)!.ttsEdit_stopButton),
          ),
        const SizedBox(width: 8),
        if (isGenerating)
          TextButton.icon(
            onPressed: _cancelGeneration,
            icon: const Icon(Icons.stop, size: 18),
            label: Text(AppLocalizations.of(context)!.ttsEdit_cancelButton),
          )
        else
          TextButton.icon(
            onPressed: _generateAll,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: Text(AppLocalizations.of(context)!.ttsEdit_generateAllButton),
          ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: isGenerating
              ? null
              : () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(AppLocalizations.of(context)!.ttsEdit_resetAllTitle),
                      content:
                          Text(AppLocalizations.of(context)!.ttsEdit_resetAllConfirmation),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(AppLocalizations.of(context)!.common_cancelButton),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(AppLocalizations.of(context)!.ttsEdit_resetButton),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _resetAll();
                  }
                },
          icon: const Icon(Icons.delete_sweep, size: 18),
          label: Text(AppLocalizations.of(context)!.ttsEdit_resetAllButton),
        ),
      ],
    );
  }
}

class _TtsEditSegmentRow extends StatefulWidget {
  const _TtsEditSegmentRow({
    required this.segment,
    required this.isGenerating,
    required this.isPlaying,
    required this.voiceFiles,
    required this.onTextEditComplete,
    required this.onRefWavPathChanged,
    required this.onMemoEditComplete,
    required this.onPlay,
    required this.onGenerate,
    required this.onReset,
    required this.enabled,
    this.dictRepository,
  });

  final TtsEditSegment segment;
  final bool isGenerating;
  final bool isPlaying;
  final List<String> voiceFiles;
  final TtsDictionaryRepository? dictRepository;
  final void Function(String text) onTextEditComplete;
  final void Function(String? value) onRefWavPathChanged;
  final void Function(String? memo) onMemoEditComplete;
  final VoidCallback onPlay;
  final VoidCallback onGenerate;
  final VoidCallback onReset;
  final bool enabled;

  @override
  State<_TtsEditSegmentRow> createState() => _TtsEditSegmentRowState();
}

class _TtsEditSegmentRowState extends State<_TtsEditSegmentRow> {
  late TextEditingController _textController;
  late TextEditingController _memoController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.segment.text);
    _memoController = TextEditingController(text: widget.segment.memo ?? '');
  }

  @override
  void didUpdateWidget(_TtsEditSegmentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_textController.text != widget.segment.text) {
      _textController.text = widget.segment.text;
    }
    final newMemo = widget.segment.memo ?? '';
    if (_memoController.text != newMemo) {
      _memoController.text = newMemo;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Widget _buildStatusIcon() {
    if (widget.isGenerating) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (widget.isPlaying) {
      return const Icon(Icons.volume_up, size: 20, color: Colors.blue);
    }
    if (widget.segment.hasAudio) {
      return const Icon(Icons.check_circle, size: 20, color: Colors.green);
    }
    return const Icon(Icons.circle_outlined, size: 20, color: Colors.grey);
  }

  String _buildStatusTooltip() {
    final l10n = AppLocalizations.of(context)!;
    if (widget.isGenerating) return l10n.ttsEdit_generatingStatus;
    if (widget.isPlaying) return l10n.ttsEdit_playingStatus;
    if (widget.segment.hasAudio) return l10n.ttsEdit_generatedStatus;
    return l10n.ttsEdit_ungeneratedStatus;
  }

  @override
  Widget build(BuildContext context) {
    final refWavPath = widget.segment.refWavPath;
    // Map ref_wav_path to dropdown value:
    //   null → null (設定値), '' → '' (なし), known file → file, missing file → '' (なし)
    final effectiveRefValue = refWavPath == null
        ? null
        : refWavPath.isEmpty
            ? ''
            : widget.voiceFiles.contains(refWavPath)
                ? refWavPath
                : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status icon
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 8),
            child: Tooltip(
              message: _buildStatusTooltip(),
              child: _buildStatusIcon(),
            ),
          ),
          // Text field
          Expanded(
            flex: 4,
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: const OutlineInputBorder(),
                hintText: widget.segment.originalText,
              ),
              maxLines: null,
              style: const TextStyle(fontSize: 13),
              onSubmitted: widget.onTextEditComplete,
              onTapOutside: (_) {
                widget.onTextEditComplete(_textController.text);
              },
              contextMenuBuilder: widget.dictRepository == null
                  ? null
                  : (menuContext, editableTextState) {
                      return buildDictionaryContextMenu(
                        context,
                        editableTextState,
                        onAddToDictionary: (selectedText) {
                          TtsDictionaryDialog.show(
                            context,
                            repository: widget.dictRepository!,
                            initialSurface: selectedText,
                          );
                        },
                      );
                    },
            ),
          ),
          const SizedBox(width: 8),
          // Reference audio dropdown
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<String?>(
              // ignore: deprecated_member_use
              value: effectiveRefValue,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(AppLocalizations.of(context)!.ttsEdit_referenceSettingValue, style: const TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem<String?>(
                  value: '',
                  child: Text(AppLocalizations.of(context)!.ttsEdit_referenceNone, style: const TextStyle(fontSize: 12)),
                ),
                ...widget.voiceFiles.map(
                  (file) => DropdownMenuItem<String?>(
                    value: file,
                    child: Text(file,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: widget.enabled
                  ? (value) => widget.onRefWavPathChanged(value)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          // Memo field
          SizedBox(
            width: 100,
            child: TextField(
              controller: _memoController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: const OutlineInputBorder(),
                hintText: AppLocalizations.of(context)!.ttsEdit_memoHint,
              ),
              style: const TextStyle(fontSize: 12),
              onSubmitted: (value) =>
                  widget.onMemoEditComplete(value.isEmpty ? null : value),
              onTapOutside: (_) {
                final value = _memoController.text;
                widget.onMemoEditComplete(value.isEmpty ? null : value);
              },
            ),
          ),
          const SizedBox(width: 4),
          // Action buttons
          IconButton(
            icon: Icon(
              Icons.play_arrow,
              size: 20,
              color: widget.segment.hasAudio ? null : Colors.grey,
            ),
            tooltip: AppLocalizations.of(context)!.ttsEdit_playTooltip,
            onPressed:
                widget.segment.hasAudio && widget.enabled ? widget.onPlay : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: AppLocalizations.of(context)!.ttsEdit_regenerateTooltip,
            onPressed: widget.enabled ? widget.onGenerate : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt, size: 20),
            tooltip: AppLocalizations.of(context)!.ttsEdit_resetTooltip,
            onPressed: widget.enabled ? widget.onReset : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
