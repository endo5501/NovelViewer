import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/tts/data/voice_recording_service.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/shared/utils/temp_directory_utils.dart';
import 'package:record/record.dart';

class VoiceRecordingDialog extends ConsumerStatefulWidget {
  final List<String> existingFiles;

  const VoiceRecordingDialog({
    super.key,
    required this.existingFiles,
  });

  /// Shows the dialog and returns the saved file name, or null if cancelled.
  static Future<String?> show(
    BuildContext context, {
    required List<String> existingFiles,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VoiceRecordingDialog(existingFiles: existingFiles),
    );
  }

  @override
  ConsumerState<VoiceRecordingDialog> createState() =>
      _VoiceRecordingDialogState();
}

enum _RecordingState { idle, recording, recorded }

class _VoiceRecordingDialogState extends ConsumerState<VoiceRecordingDialog> {
  _RecordingState _state = _RecordingState.idle;
  Timer? _timer;
  int _elapsedSeconds = 0;
  double _currentAmplitude = -60.0;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  String? _recordedFilePath;
  late VoiceRecordingService _recordingService;

  @override
  void initState() {
    super.initState();
    _recordingService = VoiceRecordingService(recorder: AudioRecorder());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    _recordingService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recordingService.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.voiceRecording_micAccessDenied)),
          );
        }
        return;
      }

      final tempDir = await ensureTemporaryDirectory();
      await _recordingService.startRecording(tempDir.path);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.voiceRecording_startRecordingFailed(e.toString()))),
        );
      }
      return;
    }

    _amplitudeSubscription = _recordingService
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen((amp) {
      if (mounted) {
        setState(() {
          _currentAmplitude = amp.current;
        });
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });

    setState(() {
      _state = _RecordingState.recording;
      _elapsedSeconds = 0;
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _amplitudeSubscription?.cancel();

    try {
      final path = await _recordingService.stopRecording();

      setState(() {
        _state = _RecordingState.recorded;
        _recordedFilePath = path;
      });

      if (path != null && mounted) {
        _showSaveDialog();
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.voiceRecording_stopRecordingFailed(e.toString()))),
        );
        setState(() {
          _state = _RecordingState.idle;
        });
      }
    }
  }

  Future<void> _showSaveDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _SaveFileNameDialog(
        existingFiles: widget.existingFiles,
      ),
    );

    if (result != null && _recordedFilePath != null) {
      final voiceService = ref.read(voiceReferenceServiceProvider);
      if (voiceService == null) return;

      try {
        await voiceService.moveVoiceFile(_recordedFilePath!, result);
        _recordedFilePath = null; // Prevent cleanup in dispose
        if (mounted) {
          Navigator.of(context).pop(result);
        }
      } on StateError catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.voiceRecording_saveFailed(e.message))),
          );
          _showSaveDialog();
        }
      } on ArgumentError catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.voiceRecording_saveFailed(e.message))),
          );
          _showSaveDialog();
        }
      } on FileSystemException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.voiceRecording_saveFailed(e.message))),
          );
          _showSaveDialog();
        }
      }
    } else {
      // User cancelled save - cleanup and go back to idle
      _recordingService.cleanupTempFile();
      _recordedFilePath = null;
      setState(() {
        _state = _RecordingState.idle;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_state == _RecordingState.recording) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.voiceRecording_discardTitle),
          content: Text(AppLocalizations.of(context)!.voiceRecording_discardConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context)!.common_cancelButton),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppLocalizations.of(context)!.voiceRecording_discardButton),
            ),
          ],
        ),
      );

      if (shouldDiscard == true) {
        _timer?.cancel();
        _amplitudeSubscription?.cancel();
        await _recordingService.cancelRecording();
        _recordedFilePath = null;
        return true;
      }
      return false;
    }

    _recordingService.cleanupTempFile();
    _recordedFilePath = null;
    return true;
  }

  String _formatElapsedTime() {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double _normalizeAmplitude() {
    // dBFS ranges roughly from -60 (silence) to 0 (max)
    const minDb = -60.0;
    const maxDb = 0.0;
    return ((_currentAmplitude - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state != _RecordingState.recording,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final navigator = Navigator.of(context);
          final shouldClose = await _onWillPop();
          if (shouldClose && mounted) {
            navigator.pop();
          }
        }
      },
      child: AlertDialog(
        title: Text(AppLocalizations.of(context)!.voiceRecording_title),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_state == _RecordingState.recording) ...[
                Text(
                  _formatElapsedTime(),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _normalizeAmplitude(),
                ),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context)!.voiceRecording_recording),
              ] else ...[
                Icon(
                  Icons.mic,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.voiceRecording_startInstructions),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final shouldClose = await _onWillPop();
              if (shouldClose && mounted) {
                navigator.pop();
              }
            },
            child: Text(AppLocalizations.of(context)!.common_cancelButton),
          ),
          if (_state == _RecordingState.idle)
            ElevatedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.fiber_manual_record, color: Colors.red),
              label: Text(AppLocalizations.of(context)!.voiceRecording_startButton),
            ),
          if (_state == _RecordingState.recording)
            ElevatedButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop),
              label: Text(AppLocalizations.of(context)!.voiceRecording_stopButton),
            ),
        ],
      ),
    );
  }
}

class _SaveFileNameDialog extends StatefulWidget {
  final List<String> existingFiles;

  const _SaveFileNameDialog({required this.existingFiles});

  @override
  State<_SaveFileNameDialog> createState() => _SaveFileNameDialogState();
}

class _SaveFileNameDialogState extends State<_SaveFileNameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _fileName => '${_controller.text}.wav';

  static final _invalidChars = RegExp(r'[/\\:*?"<>|]');

  String? get _errorText {
    if (_controller.text.isEmpty) return null;
    if (_invalidChars.hasMatch(_controller.text)) {
      return AppLocalizations.of(context)!.voiceRecording_invalidCharsError;
    }
    if (widget.existingFiles.contains(_fileName)) {
      return AppLocalizations.of(context)!.common_fileDuplicateError;
    }
    return null;
  }

  bool get _canSave => _controller.text.isNotEmpty && _errorText == null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.voiceRecording_enterFileNameTitle),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.common_fileNameLabel,
                errorText: _errorText,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 16),
            child: Text(
              '.wav',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.common_cancelButton),
        ),
        TextButton(
          onPressed: _canSave ? () => Navigator.of(context).pop(_fileName) : null,
          child: Text(AppLocalizations.of(context)!.voiceRecording_saveButton),
        ),
      ],
    );
  }
}
