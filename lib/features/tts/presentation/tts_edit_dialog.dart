import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/tts_adapters.dart';
import '../data/tts_audio_database.dart';
import '../data/tts_audio_repository.dart';
import '../data/tts_edit_controller.dart';
import '../data/tts_edit_segment.dart';
import '../data/tts_isolate.dart';
import '../providers/tts_edit_providers.dart';
import '../providers/tts_settings_providers.dart';

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
    final tempDir = await getTemporaryDirectory();

    final controller = TtsEditController(
      ttsIsolate: TtsIsolate(),
      audioPlayer: JustAudioPlayer(),
      repository: repo,
      tempDirPath: tempDir.path,
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

    final modelDir = ref.read(ttsModelDirProvider);
    if (modelDir.isEmpty) return;

    final segment = controller.segments[index];
    final refWavPath = _resolveRefWavPath(segment.refWavPath);

    ref
        .read(ttsEditGenerationStateProvider.notifier)
        .set(TtsEditGenerationState.generating);
    ref.read(ttsEditGeneratingIndexProvider.notifier).set(index);

    final instruct = ref.read(ttsInstructProvider);
    await controller.generateSegment(
      segmentIndex: index,
      modelDir: modelDir,
      refWavPath: refWavPath,
      instruct: instruct.isEmpty ? null : instruct,
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

    final modelDir = ref.read(ttsModelDirProvider);
    if (modelDir.isEmpty) return;

    final globalRefFileName = ref.read(ttsRefWavPathProvider);
    final voiceService = ref.read(voiceReferenceServiceProvider);
    final globalRefWavPath =
        globalRefFileName.isNotEmpty && voiceService != null
            ? voiceService.resolveVoiceFilePath(globalRefFileName)
            : null;

    ref
        .read(ttsEditGenerationStateProvider.notifier)
        .set(TtsEditGenerationState.generating);

    final instruct = ref.read(ttsInstructProvider);
    await controller.generateAllUngenerated(
      modelDir: modelDir,
      globalRefWavPath: globalRefWavPath,
      instruct: instruct.isEmpty ? null : instruct,
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
      title: const Text('読み上げ編集'),
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
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  Widget _buildToolbar(bool isGenerating, bool isPlaying) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: isGenerating ? null : _playAll,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('全再生'),
        ),
        if (isPlaying)
          TextButton.icon(
            onPressed: _stopPlayback,
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('停止'),
          ),
        const SizedBox(width: 8),
        if (isGenerating)
          TextButton.icon(
            onPressed: _cancelGeneration,
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('中断'),
          )
        else
          TextButton.icon(
            onPressed: _generateAll,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('全生成'),
          ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: isGenerating
              ? null
              : () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('全消去'),
                      content:
                          const Text('すべてのセグメントを初期状態に戻しますか？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('キャンセル'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('消去'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _resetAll();
                  }
                },
          icon: const Icon(Icons.delete_sweep, size: 18),
          label: const Text('全消去'),
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
  });

  final TtsEditSegment segment;
  final bool isGenerating;
  final bool isPlaying;
  final List<String> voiceFiles;
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
    if (widget.isGenerating) return '生成中';
    if (widget.isPlaying) return '再生中';
    if (widget.segment.hasAudio) return '生成済み';
    return '未生成';
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
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('設定値', style: TextStyle(fontSize: 12)),
                ),
                const DropdownMenuItem<String?>(
                  value: '',
                  child: Text('なし', style: TextStyle(fontSize: 12)),
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
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: OutlineInputBorder(),
                hintText: 'メモ',
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
            tooltip: '再生',
            onPressed:
                widget.segment.hasAudio && widget.enabled ? widget.onPlay : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '再生成',
            onPressed: widget.enabled ? widget.onGenerate : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt, size: 20),
            tooltip: 'リセット',
            onPressed: widget.enabled ? widget.onReset : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
