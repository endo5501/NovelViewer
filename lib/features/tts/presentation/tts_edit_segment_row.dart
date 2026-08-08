import 'package:flutter/material.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

import '../data/tts_dictionary_repository.dart';
import '../data/tts_edit_segment.dart';
import 'dictionary_context_menu.dart';
import 'tts_dictionary_dialog.dart';

/// One segment of the TTS edit dialog: status, editable text, reference audio,
/// memo, and the per-segment actions.
///
/// The text and memo fields are [Expanded], so this must be given a parent with
/// a bounded width.
class TtsEditSegmentRow extends StatefulWidget {
  const TtsEditSegmentRow({
    super.key,
    required this.segment,
    required this.isGenerating,
    required this.isPlaying,
    required this.isCursor,
    required this.voiceFiles,
    required this.onTextEditComplete,
    required this.onRefWavPathChanged,
    required this.onMemoEditComplete,
    required this.onPlay,
    required this.onGenerate,
    required this.onReset,
    required this.onCursorRequested,
    required this.onSkipToggled,
    required this.enabled,
    this.dictRepository,
  });

  final TtsEditSegment segment;
  final bool isGenerating;
  final bool isPlaying;

  /// Whether the playhead sits on this segment — the one the next playback
  /// starts from. Independent of [isPlaying]: a stopped playhead still shows.
  final bool isCursor;

  final List<String> voiceFiles;
  final TtsDictionaryRepository? dictRepository;
  final void Function(String text) onTextEditComplete;
  final void Function(String? value) onRefWavPathChanged;
  final void Function(String? memo) onMemoEditComplete;
  final VoidCallback onPlay;
  final VoidCallback onGenerate;
  final VoidCallback onReset;

  /// Fired when a pointer goes down anywhere in this row, asking for the
  /// playhead. Only a request: the list decides whether to honour it.
  final VoidCallback onCursorRequested;

  /// Fired when the status icon is pressed, asking to flip this segment
  /// between "read aloud" and "skipped".
  final VoidCallback onSkipToggled;

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
    // Ahead of hasAudio: skipping keeps any recording, so a skipped row that
    // still holds audio must not read as "generated".
    if (widget.segment.skip) {
      return const Icon(Icons.block, size: 20, color: Colors.orange);
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
    final state = widget.segment.skip
        ? l10n.ttsEdit_skippedStatus
        : widget.segment.hasAudio
            ? l10n.ttsEdit_generatedStatus
            : l10n.ttsEdit_ungeneratedStatus;
    // The toggle is not otherwise discoverable — the icon looks like a
    // status readout, not a control.
    return widget.enabled ? '$state\n${l10n.ttsEdit_skipToggleHint}' : state;
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

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status icon. Doubles as the skip toggle: the row is already full
          // (status, text, reference audio, memo, three buttons), and skip is
          // a fourth state of what this icon already reports.
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 8),
            child: Tooltip(
              message: _buildStatusTooltip(),
              child: InkWell(
                onTap: widget.enabled ? widget.onSkipToggled : null,
                customBorder: const CircleBorder(),
                child: _buildStatusIcon(),
              ),
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
              // A multiline field otherwise defaults to TextInputAction.newline,
              // which turns Enter into a line break and stops onSubmitted from
              // firing. The memo is a one-line caption, so Enter must keep
              // committing it the way it did before the field could wrap.
              textInputAction: TextInputAction.done,
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
              color: widget.segment.hasAudio && !widget.segment.skip
                  ? null
                  : Colors.grey,
            ),
            tooltip: AppLocalizations.of(context)!.ttsEdit_playTooltip,
            onPressed:
                widget.segment.hasAudio && !widget.segment.skip && widget.enabled
                    ? widget.onPlay
                    : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: AppLocalizations.of(context)!.ttsEdit_regenerateTooltip,
            // "Do not generate" and "generate now" cannot both hold: the user
            // un-skips first, via the status icon.
            onPressed: widget.enabled && !widget.segment.skip
                ? widget.onGenerate
                : null,
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

    // A Listener rather than a tap gesture: it observes the pointer without
    // consuming it, so the text fields, the selector and the buttons keep
    // behaving exactly as before. Opaque so the gaps between them count as
    // part of the row too.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => widget.onCursorRequested(),
      child: ColoredBox(
        color: widget.isCursor
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        child: content,
      ),
    );
  }
}
