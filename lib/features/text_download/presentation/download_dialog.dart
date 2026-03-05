import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class DownloadDialog extends ConsumerStatefulWidget {
  const DownloadDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DownloadDialog(),
    );
  }

  @override
  ConsumerState<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends ConsumerState<DownloadDialog> {
  final _urlController = TextEditingController();
  final _registry = NovelSiteRegistry();
  String? _urlError;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _validateUrl(String value) {
    setState(() {
      if (value.isEmpty) {
        _urlError = null;
        return;
      }
      final uri = Uri.tryParse(value);
      if (uri == null || !uri.hasScheme) {
        _urlError = AppLocalizations.of(context)!.download_invalidUrlError;
        return;
      }
      if (_registry.findSite(uri) == null) {
        _urlError = AppLocalizations.of(context)!.download_unsupportedSiteError;
        return;
      }
      _urlError = null;
    });
  }

  bool get _canStartDownload {
    final url = _urlController.text;
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final outputPath = ref.read(libraryPathProvider);
    if (outputPath == null) return false;
    return _registry.findSite(uri) != null;
  }

  void _startDownload() {
    final uri = Uri.parse(_urlController.text);
    final outputPath = ref.read(libraryPathProvider)!;
    ref.read(downloadProvider.notifier).startDownload(
          url: uri,
          outputPath: outputPath,
        );
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadProvider);

    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.download_title),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://ncode.syosetu.com/... or https://novel18.syosetu.com/...',
                errorText: _urlError,
                enabled: downloadState.status != DownloadStatus.downloading,
              ),
              onChanged: _validateUrl,
            ),
            const SizedBox(height: 16),
            _buildStatusArea(downloadState),
          ],
        ),
      ),
      actions: _buildActions(downloadState),
    );
  }

  String _skipSuffix(BuildContext context, int skipped) =>
      skipped > 0 ? ' ${AppLocalizations.of(context)!.download_skippedSuffix(skipped)}' : '';

  Widget _buildStatusArea(DownloadState state) {
    switch (state.status) {
      case DownloadStatus.idle:
        return const SizedBox.shrink();
      case DownloadStatus.downloading:
        final progress = state.totalEpisodes > 0
            ? state.currentEpisode / state.totalEpisodes
            : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.download_progressFormat(state.currentEpisode, state.totalEpisodes, _skipSuffix(context, state.skippedEpisodes)),
            ),
          ],
        );
      case DownloadStatus.completed:
        return Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.download_completedFormat(state.totalEpisodes, _skipSuffix(context, state.skippedEpisodes)),
            ),
          ],
        );
      case DownloadStatus.error:
        return Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.download_errorFormat(state.errorMessage ?? AppLocalizations.of(context)!.common_unknownError),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
    }
  }

  List<Widget> _buildActions(DownloadState state) {
    if (state.status == DownloadStatus.downloading) {
      return [
        TextButton(
          onPressed: null,
          child: Text(AppLocalizations.of(context)!.download_downloadingButton),
        ),
      ];
    }

    if (state.status == DownloadStatus.completed) {
      return [
        TextButton(
          onPressed: () {
            ref.invalidate(directoryContentsProvider);
            ref.read(downloadProvider.notifier).reset();
            Navigator.of(context).pop();
          },
          child: Text(AppLocalizations.of(context)!.common_closeButton),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () {
          ref.read(downloadProvider.notifier).reset();
          Navigator.of(context).pop();
        },
        child: Text(AppLocalizations.of(context)!.common_cancelButton),
      ),
      ElevatedButton(
        onPressed: _canStartDownload ? _startDownload : null,
        child: Text(AppLocalizations.of(context)!.download_startButton),
      ),
    ];
  }
}
