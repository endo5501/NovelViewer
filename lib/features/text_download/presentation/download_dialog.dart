import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
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

  /// Selected destination folder path. `null` means the library root (the
  /// default), preserving the previous always-save-to-root behavior.
  String? _selectedDestinationPath;

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

  /// Resolves the effective download destination. Mirrors the validity check in
  /// [_buildDestinationSelector]: when the selected folder is no longer among
  /// the current candidates (e.g. it was deleted while the dialog was open),
  /// fall back to the library root so the action matches what the dropdown
  /// displays.
  String _resolveOutputPath(String libraryPath) {
    final selected = _selectedDestinationPath;
    if (selected == null) return libraryPath;
    final destinations =
        ref.read(downloadDestinationFoldersProvider).asData?.value ??
            const <DirectoryEntry>[];
    final isValid = destinations.any((d) => d.path == selected);
    return isValid ? selected : libraryPath;
  }

  void _startDownload() {
    final uri = Uri.parse(_urlController.text);
    final libraryPath = ref.read(libraryPathProvider)!;
    final outputPath = _resolveOutputPath(libraryPath);
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
                hintText: 'https://ncode.syosetu.com/... or https://www.aozora.gr.jp/...',
                errorText: _urlError,
                enabled: downloadState.status != DownloadStatus.downloading,
              ),
              onChanged: _validateUrl,
            ),
            const SizedBox(height: 16),
            _buildDestinationSelector(downloadState),
            const SizedBox(height: 16),
            _buildStatusArea(downloadState),
          ],
        ),
      ),
      actions: _buildActions(downloadState),
    );
  }

  /// Destination folder dropdown. The first option is the library root (the
  /// default); the rest are organizational (non-novel) folders under the
  /// library root, displayed by their path relative to the root. While the
  /// candidate list is loading or fails to load, only the root option is shown.
  Widget _buildDestinationSelector(DownloadState state) {
    final l10n = AppLocalizations.of(context)!;
    final libraryPath = ref.watch(libraryPathProvider);
    if (libraryPath == null) return const SizedBox.shrink();

    final destinations =
        ref.watch(downloadDestinationFoldersProvider).asData?.value ??
            const <DirectoryEntry>[];

    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: libraryPath,
        child: Text(l10n.download_destinationRoot),
      ),
      for (final dir in destinations)
        DropdownMenuItem(value: dir.path, child: Text(dir.displayName)),
    ];

    // Fall back to the root when the previously-selected folder is no longer
    // among the candidates (e.g. it was deleted while the dialog was open).
    final validPaths = items.map((e) => e.value).toSet();
    final current =
        (_selectedDestinationPath != null &&
                validPaths.contains(_selectedDestinationPath))
            ? _selectedDestinationPath!
            : libraryPath;

    final isDownloading = state.status == DownloadStatus.downloading;

    return InputDecorator(
      decoration: InputDecoration(labelText: l10n.download_destinationLabel),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('download_destination_dropdown'),
          value: current,
          isExpanded: true,
          onChanged: isDownloading
              ? null
              : (value) => setState(() => _selectedDestinationPath = value),
          items: items,
        ),
      ),
    );
  }

  String _skipSuffix(BuildContext context, int skipped) =>
      skipped > 0 ? ' ${AppLocalizations.of(context)!.download_skippedSuffix(skipped)}' : '';

  String _failedSuffix(BuildContext context, int failed) => failed > 0
      ? ' ${AppLocalizations.of(context)!.download_failedSuffix(failed)}'
      : '';

  String _summarySuffix(BuildContext context, DownloadState state) =>
      _skipSuffix(context, state.skippedEpisodes) +
      _failedSuffix(context, state.failedEpisodes);

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
              AppLocalizations.of(context)!.download_progressFormat(
                  state.currentEpisode,
                  state.totalEpisodes,
                  _summarySuffix(context, state)),
            ),
          ],
        );
      case DownloadStatus.completed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.download_completedFormat(
                        state.totalEpisodes, _summarySuffix(context, state)),
                  ),
                ),
              ],
            ),
            if (state.indexTruncated) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!
                          .download_indexTruncatedWarning,
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      case DownloadStatus.cancelled:
        return Row(
          children: [
            const Icon(Icons.cancel, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.download_cancelledMessage,
              ),
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
          onPressed: () => ref.read(downloadProvider.notifier).cancel(),
          child: Text(AppLocalizations.of(context)!.common_cancelButton),
        ),
      ];
    }

    if (state.status == DownloadStatus.completed ||
        state.status == DownloadStatus.cancelled) {
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
