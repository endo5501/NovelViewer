import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/tts/presentation/voice_recording_dialog.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

class VoiceReferenceSection extends ConsumerStatefulWidget {
  const VoiceReferenceSection({super.key});

  @override
  ConsumerState<VoiceReferenceSection> createState() =>
      _VoiceReferenceSectionState();
}

class _VoiceReferenceSectionState extends ConsumerState<VoiceReferenceSection> {
  List<String> _voiceFiles = [];
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _loadVoiceFiles();
  }

  Future<void> _loadVoiceFiles() async {
    final service = ref.read(voiceReferenceServiceProvider);
    if (service == null) return;
    final files = await service.listVoiceFiles();
    if (mounted) {
      setState(() {
        _voiceFiles = files;
      });
    }
  }

  Future<void> _handleFileDrop(DropDoneDetails details) async {
    final service = ref.read(voiceReferenceServiceProvider);
    if (service == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.settings_selectLibraryFirst,
            ),
          ),
        );
      }
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final errors = <String>[];
    for (final xFile in details.files) {
      try {
        await service.addVoiceFile(xFile.path);
      } on ArgumentError catch (e) {
        errors.add('${e.message}');
      } on StateError catch (e) {
        errors.add(e.message);
      } on FileSystemException catch (e) {
        errors.add(
          l10n.settings_fileOperationError(e.osError?.message ?? e.message),
        );
      }
    }

    await _loadVoiceFiles();

    if (errors.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errors.join('\n'))),
      );
    }
  }

  Future<void> _showRecordingDialog() async {
    final savedFileName = await VoiceRecordingDialog.show(
      context,
      existingFiles: _voiceFiles,
    );
    if (savedFileName != null) {
      await _loadVoiceFiles();
      ref.read(ttsRefWavPathProvider.notifier).setTtsRefWavPath(savedFileName);
    }
  }

  Future<void> _showRenameDialog(String currentFileName) async {
    final service = ref.read(voiceReferenceServiceProvider);
    if (service == null) return;

    final ext = p.extension(currentFileName);
    final nameWithoutExt = p.basenameWithoutExtension(currentFileName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(
        initialName: nameWithoutExt,
        extension: ext,
        existingFiles: _voiceFiles,
        currentFileName: currentFileName,
      ),
    );

    if (result != null && result != currentFileName) {
      try {
        await service.renameVoiceFile(currentFileName, result);
        ref.read(ttsRefWavPathProvider.notifier).setTtsRefWavPath(result);
        await _loadVoiceFiles();
      } on StateError catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentFileName = ref.watch(ttsRefWavPathProvider);
    final hasFiles = _voiceFiles.isNotEmpty;

    final effectiveValue =
        _voiceFiles.contains(currentFileName) ? currentFileName : '';

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        await _handleFileDrop(details);
      },
      child: Container(
        decoration: BoxDecoration(
          border: _isDragging
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary, width: 2)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: _isDragging ? const EdgeInsets.all(8) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: effectiveValue,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.settings_referenceAudioLabel,
                      hintText: hasFiles
                          ? null
                          : l10n.settings_voicesPlacementHint,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(l10n.settings_referenceAudioNone),
                      ),
                      ..._voiceFiles.map(
                        (file) =>
                            DropdownMenuItem(value: file, child: Text(file)),
                      ),
                    ],
                    onChanged: (value) {
                      ref
                          .read(ttsRefWavPathProvider.notifier)
                          .setTtsRefWavPath(value ?? '');
                    },
                  ),
                ),
                if (effectiveValue.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: l10n.settings_renameFileTooltip,
                    onPressed: () => _showRenameDialog(effectiveValue),
                  ),
                IconButton(
                  icon: const Icon(Icons.mic),
                  tooltip: l10n.settings_recordVoiceTooltip,
                  onPressed: ref.read(voiceReferenceServiceProvider) != null
                      ? _showRecordingDialog
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.settings_refreshFileListTooltip,
                  onPressed: _loadVoiceFiles,
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: l10n.settings_openVoicesFolderTooltip,
                  onPressed: () {
                    final service = ref.read(voiceReferenceServiceProvider);
                    service?.openVoicesDirectory();
                  },
                ),
              ],
            ),
            if (_isDragging)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.settings_dragAudioFilesHere),
              ),
          ],
        ),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final String initialName;
  final String extension;
  final List<String> existingFiles;
  final String currentFileName;

  const _RenameDialog({
    required this.initialName,
    required this.extension,
    required this.existingFiles,
    required this.currentFileName,
  });

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _newFileName => '${_controller.text}${widget.extension}';

  String? get _errorText {
    if (_controller.text.isEmpty) return null;
    if (_newFileName != widget.currentFileName &&
        widget.existingFiles.contains(_newFileName)) {
      return AppLocalizations.of(context)!.common_fileDuplicateError;
    }
    return null;
  }

  bool get _canConfirm =>
      _controller.text.isNotEmpty &&
      _errorText == null &&
      _newFileName != widget.currentFileName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.settings_renameFileTitle),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.common_fileNameLabel,
                errorText: _errorText,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 16),
            child: Text(
              widget.extension,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancelButton),
        ),
        TextButton(
          onPressed: _canConfirm
              ? () => Navigator.of(context).pop(_newFileName)
              : null,
          child: Text(l10n.common_changeButton),
        ),
      ],
    );
  }
}
