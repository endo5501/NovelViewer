import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/shared/episode/episode_resolver.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// The scope a context-menu / popup analysis trigger expresses. The runner
/// resolves a `scope` into a concrete `coveredUpToEpisode` using the current
/// directory and file. Persistence is keyed by the resolved integer; the
/// scope itself is never written to disk.
enum AnalysisScope { upToCurrent, upToAll }

abstract class AnalysisRunner {
  Future<void> run({
    required BuildContext context,
    required String word,
    required int coveredUpToEpisode,
    String? sourceFileName,
  });

  /// Convenience entry-point for context menus and the hover popup re-analyze
  /// button. Resolves `scope` against the active directory + selected file,
  /// then forwards to [run]. Bails with a snackbar when [AnalysisScope.upToCurrent]
  /// is requested but no file is currently selected (instead of silently
  /// fabricating a `coveredUpToEpisode=1` snapshot).
  Future<void> runWithScope({
    required BuildContext context,
    required String word,
    required AnalysisScope scope,
  });
}

class DefaultAnalysisRunner implements AnalysisRunner {
  DefaultAnalysisRunner(this._ref);
  final Ref _ref;

  @override
  Future<void> runWithScope({
    required BuildContext context,
    required String word,
    required AnalysisScope scope,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final directory = _ref.read(currentDirectoryProvider);
    if (directory == null) {
      _snack(context, l10n.llmAnalysis_noFolderOpen);
      return;
    }
    final selectedFile = _ref.read(selectedFileProvider);
    final int episode;
    final String? sourceFile;
    switch (scope) {
      case AnalysisScope.upToCurrent:
        // Refuse to fabricate a phantom episode-1 snapshot for a state where
        // the user hasn't opened any file — the resulting snapshot would
        // silently collide with any real episode-1 snapshot via the unique
        // index and have a misleading "1ファイル時点" label.
        if (selectedFile == null) {
          _snack(context, l10n.llmAnalysis_noFolderOpen);
          return;
        }
        episode = resolveUpperBoundForCurrent(
          directoryPath: directory,
          currentFile: selectedFile,
        );
        sourceFile = selectedFile.name;
      case AnalysisScope.upToAll:
        episode = resolveUpperBoundForAll(directory);
        sourceFile = resolveSourceFileForAll(directory);
    }
    await run(
      context: context,
      word: word,
      coveredUpToEpisode: episode,
      sourceFileName: sourceFile,
    );
  }

  @override
  Future<void> run({
    required BuildContext context,
    required String word,
    required int coveredUpToEpisode,
    String? sourceFileName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final directory = _ref.read(currentDirectoryProvider);
    if (directory == null) {
      _snack(context, l10n.llmAnalysis_noFolderOpen);
      return;
    }

    // Wait for the async dependencies of `llmSummaryServiceProvider` to settle
    // before reading it. The service is a *synchronous* provider that returns
    // null while any of these FutureProviders is still loading, so reading it
    // eagerly would yield null and make analysis silently bail. The client
    // future covers the on-demand secure-storage API key fetch; the repository
    // futures must be awaited too — nothing else pre-resolves
    // `factCacheRepositoryProvider`, so without this the first analysis after
    // launch would no-op.
    await _ref.read(llmClientProvider.future);
    await _ref.read(llmSummaryRepositoryProvider(directory).future);
    await _ref.read(factCacheRepositoryProvider(directory).future);
    final service = _ref.read(llmSummaryServiceProvider(directory));
    if (!context.mounted) return;
    if (service == null) {
      _snack(context, l10n.llmAnalysis_noLlmConfigured);
      return;
    }

    final selectedFile = _ref.read(selectedFileProvider);
    final resolvedSourceFile = sourceFileName ?? selectedFile?.name;

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
        word: word,
        coveredUpToEpisode: coveredUpToEpisode,
        sourceFileName: resolvedSourceFile,
        onProgress: (event) {
          if (progressDisposed) return;
          progress.value = event;
        },
      );
      _ref.invalidate(llmSummaryHistoryProvider);
      _ref.invalidate(
          hoverPopupCacheProvider((folderPath: directory, word: word)));
      // The popup's manual activeEpisode override may now point at a
      // snapshot that no longer exists post-overwrite — reset it so the
      // widget falls back to the default-selection rule against the fresh
      // snapshot list instead of silently swapping content under the user.
      final hoverState = _ref.read(hoverPopupProvider);
      if (hoverState.word == word) {
        _ref.read(hoverPopupProvider.notifier).setActiveEpisode(null);
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      if (modalRoute.isActive) {
        navigator.removeRoute(modalRoute);
      }
      progressDisposed = true;
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

/// Resolve "解析開始(ネタバレなし)" → the inclusive upper bound corresponding
/// to the currently-viewed file. Returns the numeric prefix when present;
/// otherwise the file's lexical rank within the folder. Returns 1 as a
/// pessimistic fallback when the directory cannot be listed (callers SHOULD
/// already have ensured `currentFile != null` before invoking).
int resolveUpperBoundForCurrent({
  required String directoryPath,
  required FileEntry? currentFile,
}) {
  if (currentFile == null) return 1;
  return resolveCurrentFileEpisode(
    fileName: currentFile.name,
    folderFiles: () => listSortedTextFileNames(directoryPath),
  );
}

/// Resolve "解析開始(ネタバレあり)" → the inclusive upper bound that captures
/// every file in the folder. Computed as `max(highestNumericPrefix,
/// totalFileCount)` so that a folder mixing numbered files (e.g.
/// `001_ch.txt`..`040_ch.txt`) with prefix-less files (e.g. `prologue.txt`,
/// `afterword.txt`) still includes the prefix-less files via the
/// length-based upper bound — without this `max`, prefix-less files in a
/// mixed folder would silently be excluded from the "全話" scope.
///
/// Returns 1 when the directory has no text files.
int resolveUpperBoundForAll(String directoryPath) =>
    resolveUpperBoundForAllFiles(listSortedTextFileNames(directoryPath));

/// Resolve the file the spoiler-mode snapshot should be linked back to (for
/// jump support). Prefers the highest-prefix file when any prefix exists,
/// otherwise the last lexical file. Returns `null` when the folder is empty.
String? resolveSourceFileForAll(String directoryPath) =>
    resolveSourceFileForAllFiles(listSortedTextFileNames(directoryPath));

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
