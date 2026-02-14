import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';

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
        _urlError = '有効なURLを入力してください';
        return;
      }
      if (_registry.findSite(uri) == null) {
        _urlError = 'サポートされていないサイトです（なろう、カクヨムに対応）';
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
    final outputPath = ref.read(currentDirectoryProvider);
    if (outputPath == null) return false;
    return _registry.findSite(uri) != null;
  }

  void _startDownload() {
    final uri = Uri.parse(_urlController.text);
    final outputPath = ref.read(currentDirectoryProvider)!;
    ref.read(downloadProvider.notifier).startDownload(
          url: uri,
          outputPath: outputPath,
        );
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadProvider);

    return AlertDialog(
      title: const Text('小説ダウンロード'),
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
                hintText: 'https://ncode.syosetu.com/...',
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

  String _skipSuffix(int skipped) =>
      skipped > 0 ? ' (スキップ: $skipped件)' : '';

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
              'ダウンロード中: ${state.currentEpisode}/${state.totalEpisodes} エピソード${_skipSuffix(state.skippedEpisodes)}',
            ),
          ],
        );
      case DownloadStatus.completed:
        return Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'ダウンロード完了: ${state.totalEpisodes} エピソード${_skipSuffix(state.skippedEpisodes)}',
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
                'エラー: ${state.errorMessage ?? "不明なエラー"}',
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
        const TextButton(
          onPressed: null,
          child: Text('ダウンロード中...'),
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
          child: const Text('閉じる'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () {
          ref.read(downloadProvider.notifier).reset();
          Navigator.of(context).pop();
        },
        child: const Text('キャンセル'),
      ),
      ElevatedButton(
        onPressed: _canStartDownload ? _startDownload : null,
        child: const Text('ダウンロード開始'),
      ),
    ];
  }
}
