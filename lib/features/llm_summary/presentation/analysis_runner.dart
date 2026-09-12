import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/shared/episode/episode_resolver.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_analysis_failure.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/llm_summary/providers/on_device_llm_providers.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/failure/failure_report.dart';
import 'package:novel_viewer/shared/failure/failure_snackbar.dart';

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

  /// Whether this platform can reach an LLM server at all.
  ///
  /// Checked before any work in both entry points. The UI already withholds
  /// every control that leads here where analysis is unavailable, so this is
  /// the second layer: a surface added later without a capability check must
  /// still not open a connection. It is silent by design — there is no
  /// user-facing action to explain, because no control was offered.
  bool get _supported => _ref.read(llmSummarySupportedProvider);

  @override
  Future<void> runWithScope({
    required BuildContext context,
    required String word,
    required AnalysisScope scope,
  }) async {
    if (!_supported) return;
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
    if (!_supported) return;
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
    if (service == null) {
      final message = await _noServiceMessage(l10n);
      if (!context.mounted) return;
      _snack(context, message);
      return;
    }
    if (!context.mounted) return;

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

    final language = _ref.read(localeProvider).languageCode;

    FailureReport? failure;
    try {
      await service.generateSummary(
        directoryPath: directory,
        word: word,
        coveredUpToEpisode: coveredUpToEpisode,
        sourceFileName: resolvedSourceFile,
        language: language,
        onProgress: (event) {
          if (progressDisposed) return;
          progress.value = event;
        },
      );
      _ref.invalidate(llmSummaryHistoryProvider);
      _ref.invalidate(
        hoverPopupCacheProvider((folderPath: directory, word: word)),
      );
      // The popup's manual activeEpisode override may now point at a
      // snapshot that no longer exists post-overwrite — reset it so the
      // widget falls back to the default-selection rule against the fresh
      // snapshot list instead of silently swapping content under the user.
      final hoverState = _ref.read(hoverPopupProvider);
      if (hoverState.word == word) {
        _ref.read(hoverPopupProvider.notifier).setActiveEpisode(null);
      }
    } catch (e, st) {
      // The typed analysis failures say something actionable ("2 files could
      // not be analyzed; re-run to retry just those"), so they get their own
      // wording. Anything else — a configuration or storage error raised before
      // extraction — keeps the generic message. None of them embed the error
      // itself: that arrives as the report's cause and is appended once.
      final headline = switch (e) {
        LlmAnalysisPartialFailure(:final failedFileCount) =>
          l10n.llmAnalysis_partialFailure(failedFileCount),
        LlmAnalysisNoFactsFailure() => l10n.llmAnalysis_noFacts(word),
        _ => l10n.llmAnalysis_failed,
      };
      failure = FailureReport(
        headline: headline,
        cause: e.toString(),
        stackTrace: st,
        diagnostics: _diagnostics(
          word: word,
          coveredUpToEpisode: coveredUpToEpisode,
          sourceFileName: resolvedSourceFile,
        ),
      );
    } finally {
      if (modalRoute.isActive) {
        navigator.removeRoute(modalRoute);
      }
      progressDisposed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => progress.dispose());
    }

    if (failure != null) {
      // Routed through the root navigator rather than the captured context:
      // the notification outlives whatever surface triggered the analysis.
      if (!navigator.mounted) return;
      showFailureSnackBar(navigator.context, failure);
      return;
    }

    if (!messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.llmAnalysis_savedSummary(word))),
    );
  }

  /// What a failure report says about the run that produced it.
  ///
  /// Deliberately no endpoint: a self-hosted `baseUrl` carries the reader's
  /// private network address, and this text is meant to be pasted into a bug
  /// report. The provider kind and model still identify the configuration.
  Map<String, String?> _diagnostics({
    required String word,
    required int coveredUpToEpisode,
    required String? sourceFileName,
  }) {
    final config = _ref.read(llmConfigProvider);
    final packageInfo = _ref.read(packageInfoProvider);
    return {
      'time': DateTime.now().toUtc().toIso8601String(),
      'app version': '${packageInfo.version}+${packageInfo.buildNumber}',
      'provider': config.provider.name,
      'model': config.model,
      'word': word,
      'covered up to': '$coveredUpToEpisode',
      'file': sourceFileName,
    };
  }

  /// What to say when no client could be built.
  ///
  /// The generic message tells the reader to go and configure an LLM. With
  /// the on-device provider selected that is wrong: they have configured one,
  /// and what stopped the run is the model being unusable right now. Naming
  /// that sends them somewhere they can act.
  Future<String> _noServiceMessage(AppLocalizations l10n) async {
    if (_ref.read(llmConfigProvider).provider != LlmProvider.appleOnDevice) {
      return l10n.llmAnalysis_noLlmConfigured;
    }
    // Awaited rather than read: nothing else on this path resolves it, and an
    // unresolved answer would fall through to the generic message.
    return switch (await _ref.read(onDeviceModelAvailabilityProvider.future)) {
      OnDeviceModelAvailability.intelligenceNotEnabled =>
        l10n.settings_llmOnDeviceUnavailableIntelligenceOff,
      OnDeviceModelAvailability.modelNotReady =>
        l10n.settings_llmOnDeviceUnavailableModelNotReady,
      OnDeviceModelAvailability.deviceNotEligible ||
      OnDeviceModelAvailability.unsupportedPlatform =>
        l10n.settings_llmOnDeviceUnavailableDeviceNotEligible,
      // The model is fine, so whatever stopped the run was something else
      // and the generic message is the honest one.
      OnDeviceModelAvailability.available ||
      OnDeviceModelAvailability.unknown => l10n.llmAnalysis_noLlmConfigured,
    };
  }

  void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
