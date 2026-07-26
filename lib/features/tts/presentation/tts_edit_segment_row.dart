import 'package:flutter/material.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

import '../data/tts_dictionary_repository.dart';
import '../data/tts_edit_segment.dart';
import 'dictionary_context_menu.dart';
import 'tts_dictionary_dialog.dart';

class TtsEditSegmentRow extends StatefulWidget {
  const TtsEditSegmentRow({
    super.key,
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
  State<TtsEditSegmentRow> createState() => _TtsEditSegmentRowState();
}

class _TtsEditSegmentRowState extends State<TtsEditSegmentRow> {
  late TextEditingController _textController;
  late TextEditingController _memoController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.segment.text);
    _memoController = TextEditingController(text: widget.segment.memo ?? '');
  }

  @override
  void didUpdateWidget(TtsEditSegmentRow oldWidget) {
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
            flex: 5,
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
                      final value = editableTextState.textEditingValue;
                      final sel = value.selection;
                      final selectedText = sel.isValid && !sel.isCollapsed
                          ? sel.textInside(value.text)
                          : '';
                      return buildDictionaryContextMenu(
                        context,
                        editableTextState,
                        selectedText: selectedText,
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
          // Memo field. Doubles as the Irodori caption, so it holds a short
          // sentence rather than a keyword — it wraps to a second line instead
          // of scrolling the text out of view.
          Expanded(
            flex: 2,
            child: TextField(
              controller: _memoController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: const OutlineInputBorder(),
                hintText: AppLocalizations.of(context)!.ttsEdit_memoHint,
              ),
              // minLines is required for the field to grow from one line: with
              // maxLines alone the height is pinned at two lines, which would
              // make every row taller even when the memo is empty.
              minLines: 1,
              maxLines: 2,
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
