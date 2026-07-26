import 'package:flutter/material.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/shared/utils/temp_directory_utils.dart';

import '../data/tts_adapters.dart';
import '../data/tts_audio_repository.dart';
import '../data/tts_dictionary_repository.dart';
import '../data/tts_edit_controller.dart';
import '../data/tts_engine_type.dart';
import '../data/tts_isolate.dart';
import '../domain/tts_engine_config.dart';
import 'tts_edit_segment_row.dart';
import 'tts_failure_snackbar.dart';
import '../providers/text_segmenter_provider.dart';
import '../providers/vacuum_lifecycle_provider.dart';
import '../providers/tts_audio_database_provider.dart';
import '../providers/tts_edit_providers.dart';
import '../providers/tts_model_readiness_provider.dart';
import '../providers/tts_settings_providers.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';
import 'tts_dictionary_dialog.dart';

/// Upper bound for the dialog's content width. Beyond this the row grows so
/// wide that scanning from the text field to the trailing action buttons costs
/// more than the extra room is worth.
const double _kTtsEditDialogMaxContentWidth = 1400;

/// Horizontal padding [AlertDialog] puts around its content by default
/// (`EdgeInsets.fromLTRB(24, 20, 24, 24)`, so 24 on each side). The content
/// [SizedBox] sits inside it, so the dialog's outer width is content + this.
/// Subtracting it keeps the whole dialog within 90% of the window.
const double _kAlertDialogHorizontalPadding = 48;

/// Content width for the TTS edit dialog given the current window width.
///
/// Grows with the window up to [_kTtsEditDialogMaxContentWidth] so wide
/// displays get a roomy memo column, and shrinks below it so the dialog never
/// runs off a narrow window.
double ttsEditDialogContentWidth(double windowWidth) {
  final available = windowWidth * 0.9 - _kAlertDialogHorizontalPadding;
  return available < _kTtsEditDialogMaxContentWidth
      ? available
      : _kTtsEditDialogMaxContentWidth;
}

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
  TtsDictionaryRepository? _dictRepository;
  bool _loading = true;
  List<String> _voiceFiles = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final folderKey = folderDbKey(widget.folderPath);
    final db = ref.read(ttsAudioDatabaseProvider(folderKey));
    final lifecycle = ref.read(vacuumLifecycleProvider);
    final repo = TtsAudioRepository(
      db,
      onEpisodeDeleted: () => lifecycle.markDirty(widget.folderPath),
    );
    final dictDb = ref.read(ttsDictionaryDatabaseProvider(folderKey));
    final dictRepo = TtsDictionaryRepository(dictDb);
    final tempDir = await ensureTemporaryDirectory();

    final controller = TtsEditController(
      ttsIsolate: TtsIsolate(),
      audioPlayer: JustAudioPlayer(),
      repository: repo,
      tempDirPath: tempDir.path,
      dictionaryRepository: dictRepo,
      textSegmenter: ref.read(textSegmenterProvider),
    );

    controller.onSegmentGenerated = (index) {
      if (!mounted) return;
      final segments = controller.segments;
      ref.read(ttsEditSegmentsProvider.notifier).set(List.of(segments));
      ref.read(ttsEditGeneratingIndexProvider.notifier).set(null);
    };

    controller.onSynthesisFailed = (reason) {
      if (!mounted) return;
      showTtsFailureSnackBar(
        context,
        headline: AppLocalizations.of(context)!.ttsEdit_synthesisFailed,
        reason: reason,
      );
    };

    // Resolve the active engine's real sample rate (Qwen3=24000, Piper=22050)
    // instead of hard-coding it, so the episode's sample_rate metadata matches
    // the generated audio and MP3 export does not pitch-shift Piper episodes.
    final engineType = ref.read(ttsEngineTypeProvider);
    final config = TtsEngineConfig.resolveFromRef(ref, engineType);

    await controller.loadSegments(
      text: widget.content,
      fileName: widget.fileName,
      sampleRate: config.sampleRate,
    );

    await _loadVoiceFiles();

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
    _dictRepository = null;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  /// Blocks generation when the engine's models are missing or predate the
  /// current pinned revision — loading such a model succeeds and only fails
  /// later inside the native runner. Returns true when generation may proceed.
  bool _ensureModelsReady(TtsEngineType engineType) {
    if (ref.read(ttsModelReadinessProvider(engineType)) ==
        TtsModelReadiness.ready) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.tts_modelNeedsRedownload),
      ),
    );
    return false;
  }

  Future<void> _generateSegment(int index) async {
    final controller = _controller;
    if (controller == null) return;

    final engineType = ref.read(ttsEngineTypeProvider);
    final config = TtsEngineConfig.resolveFromRef(ref, engineType);
    if (config.modelDir.isEmpty) return;
    if (!_ensureModelsReady(engineType)) return;
    final voiceService = ref.read(voiceReferenceServiceProvider);

    ref
        .read(ttsEditGenerationStateProvider.notifier)
        .set(TtsEditGenerationState.generating);
    ref.read(ttsEditGeneratingIndexProvider.notifier).set(index);

    // The controller resolves the segment's own ref_wav_path (falling back to
    // the global setting), so the engine config needs no per-segment override.
    await controller.generateSegment(
      segmentIndex: index,
      config: config,
      resolveRefWavPath: voiceService?.resolveVoiceFilePath,
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
    final config = TtsEngineConfig.resolveFromRef(ref, engineType);
    if (config.modelDir.isEmpty) return;
    if (!_ensureModelsReady(engineType)) return;
    final voiceService = ref.read(voiceReferenceServiceProvider);

    ref
        .read(ttsEditGenerationStateProvider.notifier)
        .set(TtsEditGenerationState.generating);

    await controller.generateAllUngenerated(
      config: config,
      resolveRefWavPath: voiceService?.resolveVoiceFilePath,
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
        width: ttsEditDialogContentWidth(MediaQuery.sizeOf(context).width),
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
                        return TtsEditSegmentRow(
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
