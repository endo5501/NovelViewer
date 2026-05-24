import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

abstract class AnalysisRunner {
  Future<void> run({
    required BuildContext context,
    required String word,
    required SummaryType type,
  });
}

class DefaultAnalysisRunner implements AnalysisRunner {
  DefaultAnalysisRunner(this._ref);
  final Ref _ref;

  @override
  Future<void> run({
    required BuildContext context,
    required String word,
    required SummaryType type,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final directory = _ref.read(currentDirectoryProvider);
    if (directory == null) {
      _snack(context, l10n.llmAnalysis_noFolderOpen);
      return;
    }

    // Wait for the on-demand secure-storage API key fetch to settle before
    // we read the service — otherwise a cold-start hover-trigger would
    // silently no-op while the future was still in flight.
    await _ref.read(llmClientProvider.future);
    final service = _ref.read(llmSummaryServiceProvider);
    if (!context.mounted) return;
    if (service == null) {
      _snack(context, l10n.llmAnalysis_noLlmConfigured);
      return;
    }

    final folderName = p.basename(directory);
    final selectedFile = _ref.read(selectedFileProvider);

    if (!context.mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AnalysisModal(),
    ));

    String? errorMessage;
    try {
      await service.generateSummary(
        directoryPath: directory,
        folderName: folderName,
        word: word,
        summaryType: type,
        currentFileName: selectedFile?.name,
      );
      _ref.invalidate(llmSummaryHistoryProvider);
      _ref.invalidate(
          hoverPopupCacheProvider((folder: folderName, word: word)));
    } catch (e) {
      errorMessage = e.toString();
    }

    navigator.pop();

    final message = errorMessage != null
        ? l10n.llmAnalysis_failed(errorMessage)
        : l10n.llmAnalysis_savedSummary(word);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _AnalysisModal extends StatelessWidget {
  const _AnalysisModal();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('analysis_modal'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(l10n.llmAnalysis_inProgress),
          ],
        ),
      ),
    );
  }
}

final analysisRunnerProvider = Provider<AnalysisRunner>(
  DefaultAnalysisRunner.new,
);
