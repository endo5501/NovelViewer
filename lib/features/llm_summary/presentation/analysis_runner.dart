import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';
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
    final progress = ValueNotifier<AnalysisProgress?>(null);
    var progressDisposed = false;
    final modalRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AnalysisModal(progress: progress),
    );
    unawaited(navigator.push(modalRoute));

    String? errorMessage;
    try {
      await service.generateSummary(
        directoryPath: directory,
        folderName: folderName,
        word: word,
        summaryType: type,
        currentFileName: selectedFile?.name,
        // Guard against late callbacks (today the pipeline is fully serial so
        // this can't fire post-dispose, but a future streaming/fire-and-forget
        // LlmClient would otherwise crash with a "used after disposed" error).
        onProgress: (event) {
          if (progressDisposed) return;
          progress.value = event;
        },
      );
      _ref.invalidate(llmSummaryHistoryProvider);
      _ref.invalidate(
          hoverPopupCacheProvider((folder: folderName, word: word)));
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      // Remove the modal explicitly by its own route so we never pop a
      // sibling route the user may have opened during the await window.
      if (modalRoute.isActive) {
        navigator.removeRoute(modalRoute);
      }
      progressDisposed = true;
      // Defer dispose until after the next frame so the modal's element
      // tree has a chance to unmount (and detach its ValueListenableBuilder
      // listener) before the notifier is torn down. Without this, a
      // synchronous-fast-failure path could dispose the notifier before the
      // modal ever built, leading to a "used after disposed" crash when the
      // builder's initState tries to addListener.
      WidgetsBinding.instance.addPostFrameCallback((_) => progress.dispose());
    }

    if (!messenger.mounted) return;
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
  const _AnalysisModal({required this.progress});

  final ValueListenable<AnalysisProgress?> progress;

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
            Flexible(
              child: ValueListenableBuilder<AnalysisProgress?>(
                valueListenable: progress,
                builder: (context, value, _) {
                  return Text(_labelFor(l10n, value));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _labelFor(AppLocalizations l10n, AnalysisProgress? progress) {
    switch (progress) {
      case null:
        return l10n.llmAnalysis_inProgress;
      case AnalysisExtractingFacts(:final round, :final current, :final total):
        if (round <= 1) {
          return l10n.llmAnalysis_extractingFacts(current, total);
        }
        return l10n.llmAnalysis_refiningRound(round, current, total);
      case AnalysisGeneratingFinalSummary():
        return l10n.llmAnalysis_generatingFinal;
    }
  }
}

final analysisRunnerProvider = Provider<AnalysisRunner>(
  DefaultAnalysisRunner.new,
);
