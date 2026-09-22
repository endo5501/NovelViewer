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
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config_problem.dart';
import 'package:novel_viewer/features/llm_summary/providers/on_device_llm_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/failure/failure_report.dart';
import 'package:novel_viewer/shared/failure/failure_snackbar.dart';

/// The scope a context-menu / popup analysis trigger expresses. The runner
/// resolves a `scope` into a concrete `coveredUpToEpisode` using the current
/// directory and file. Persistence is keyed by the resolved integer; the
/// scope itself is never written to disk.
///
/// [firstOccurrence] is the "簡易解析" scope. It needs no representation of its
/// own beyond a bound: the service keeps only files at or below the bound that
/// contain the word, and no file below the word's first occurrence contains
/// it, so a bound of that episode leaves exactly its files as evidence.
enum AnalysisScope { firstOccurrence, upToCurrent, upToAll }

abstract class AnalysisRunner {
  /// Runs an analysis of [word] bounded by [coveredUpToEpisode].
  ///
  /// [novelFolderPath] is the novel the request was made against, for a caller
  /// that already resolved one and may have awaited something since. Omitting
  /// it resolves the novel here, which is correct only for a caller that
  /// reaches this synchronously from the reader's action.
  Future<void> run({
    required BuildContext context,
    required String word,
    required int coveredUpToEpisode,
    String? sourceFileName,
    String? novelFolderPath,
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

  /// Whether an analysis is already under way.
  ///
  /// Nothing is on screen between the request and the modal: [_run] pushes it
  /// only once the client and repository futures settle, and the
  /// first-occurrence scope searches the folder before that. A reader who
  /// reads that silence as "nothing happened" and asks again would otherwise
  /// start a second analysis — twice the LLM calls, and two runs racing each
  /// other's snapshot and fact-cache writes for the same word.
  ///
  /// Both entry points take the flag, so a refused request does not even pay
  /// for the folder search, and both release it in a `finally`: a run that
  /// fails must not leave the runner shut for the rest of the session.
  ///
  /// Refusing is silent. The second request asked for the analysis that is
  /// already starting, so there is nothing to tell the reader that the modal
  /// is not about to say.
  bool _analysisInFlight = false;

  @override
  Future<void> runWithScope({
    required BuildContext context,
    required String word,
    required AnalysisScope scope,
  }) async {
    if (!_supported) return;
    if (_analysisInFlight) return;
    _analysisInFlight = true;
    try {
      await _runWithScope(context: context, word: word, scope: scope);
    } finally {
      _analysisInFlight = false;
    }
  }

  Future<void> _runWithScope({
    required BuildContext context,
    required String word,
    required AnalysisScope scope,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    // The same folder [run] will use. Reading the browser's directory here
    // instead would leave a second notion of "which folder" in the one method
    // that decides the episode numbers, which is where a mismatch does its
    // damage — and it would list a folder that [run] is about to refuse.
    final directory = _ref.read(summaryNovelFolderProvider);
    if (directory == null) {
      _snack(context, l10n.llmAnalysis_noFolderOpen);
      return;
    }
    final selectedFile = _ref.read(selectedFileProvider);
    final int episode;
    final String? sourceFile;
    switch (scope) {
      case AnalysisScope.firstOccurrence:
        // A selection came from a page on screen, so without one there is no
        // reading position to keep the bound at or below — refuse rather than
        // fabricate a snapshot, as the no-spoiler scope does.
        if (selectedFile == null) {
          _snack(context, l10n.llmAnalysis_noFolderOpen);
          return;
        }
        final currentEpisode = resolveUpperBoundForCurrent(
          directoryPath: directory,
          currentFile: selectedFile,
        );
        final ({int episode, String fileName})? first;
        try {
          first = await resolveFirstOccurrence(
            directoryPath: directory,
            searchService: _ref.read(textSearchServiceProvider),
            word: word,
          );
        } catch (e, st) {
          // Report it and stop. Treating a broken search as "the word occurs
          // nowhere" would fall through to the reading-position bound below
          // and run the scope this mode exists to avoid — one extraction per
          // hit file instead of one — and save the result as though it were a
          // simple analysis. The bound is named as unresolved because it never
          // was.
          if (!context.mounted) return;
          showFailureSnackBar(
            context,
            FailureReport(
              headline: l10n.llmAnalysis_failed,
              cause: e.toString(),
              stackTrace: st,
              diagnostics: _diagnostics(
                word: word,
                coveredUpToEpisode: null,
                sourceFileName: selectedFile.name,
              ),
            ),
          );
          return;
        }
        // A word that occurs nowhere is different: every bound leaves the same
        // empty evidence, so fall back to the reading position, which is
        // defined and spoiler-free. The run then fails with the existing "no
        // facts" notification, exactly as the no-spoiler scope would for it.
        episode = first?.episode ?? currentEpisode;
        sourceFile = first?.fileName ?? selectedFile.name;
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
    // Resolving the first occurrence searches the folder, so the widget may
    // have gone by the time we get here.
    if (!context.mounted) return;
    // The inner one: this method already holds the flag.
    await _run(
      context: context,
      word: word,
      coveredUpToEpisode: episode,
      sourceFileName: sourceFile,
      novelFolderPath: directory,
    );
  }

  @override
  Future<void> run({
    required BuildContext context,
    required String word,
    required int coveredUpToEpisode,
    String? sourceFileName,
    String? novelFolderPath,
  }) async {
    if (!_supported) return;
    if (_analysisInFlight) return;
    _analysisInFlight = true;
    try {
      await _run(
        context: context,
        word: word,
        coveredUpToEpisode: coveredUpToEpisode,
        sourceFileName: sourceFileName,
        novelFolderPath: novelFolderPath,
      );
    } finally {
      _analysisInFlight = false;
    }
  }

  Future<void> _run({
    required BuildContext context,
    required String word,
    required int coveredUpToEpisode,
    String? sourceFileName,
    String? novelFolderPath,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    // One folder does both jobs: the summaries are written to its
    // `novel_data.db`, and the text to analyse — along with the episode number
    // the snapshot is keyed by and the `source_file` it records — is read from
    // the same place. [summaryNovelFolderProvider] is null wherever those
    // would not be the same folder, and refusing there is what keeps a
    // `novel_data.db` from being created outside a novel, since opening one
    // creates the file.
    //
    // Read once, synchronously, and captured: this method spans awaits, and a
    // reader who moves on mid-request must not have one novel's text written
    // to another novel's database.
    //
    // A caller that already resolved the novel passes it in rather than
    // letting it be read again here. [runWithScope] does, because resolving a
    // first-occurrence bound searches the folder and that search is awaited:
    // by the time this runs the reader may be in another novel, and reading
    // the provider again would key one novel's word, bound and source file
    // into another novel's database. The captured path is still checked rather
    // than trusted — the novel may have been deleted or unregistered while the
    // search ran, and opening a repository creates `novel_data.db` wherever it
    // points.
    final String? novelFolder;
    if (novelFolderPath == null) {
      novelFolder = _ref.read(summaryNovelFolderProvider);
    } else {
      novelFolder =
          isRegisteredNovelFolder(
            folderPath: novelFolderPath,
            libraryPath: _ref.read(libraryPathProvider),
            novels: _ref.read(allNovelsProvider).value,
          )
          ? novelFolderPath
          : null;
    }
    if (novelFolder == null) {
      _snack(context, l10n.llmAnalysis_noFolderOpen);
      return;
    }
    // Captured with the folder, for the same reason: the file a snapshot is
    // recorded against has to be the one that was open when the analysis was
    // asked for, not whatever the reader moved to while it was starting up.
    final openFileName = _ref.read(selectedFileProvider)?.name;

    // Wait for the async dependencies of `llmSummaryServiceProvider` to settle
    // before reading it. The service is a *synchronous* provider that returns
    // null while any of these FutureProviders is still loading, so reading it
    // eagerly would yield null and make analysis silently bail. The client
    // future covers the on-demand secure-storage API key fetch; the repository
    // futures must be awaited too — nothing else pre-resolves
    // `factCacheRepositoryProvider`, so without this the first analysis after
    // launch would no-op.
    await _ref.read(llmClientProvider.future);
    await _ref.read(llmSummaryRepositoryProvider(novelFolder).future);
    await _ref.read(factCacheRepositoryProvider(novelFolder).future);
    final service = _ref.read(llmSummaryServiceProvider(novelFolder));
    if (service == null) {
      final message = await _noServiceMessage(l10n);
      if (!context.mounted) return;
      _snack(context, message);
      return;
    }
    if (!context.mounted) return;

    final resolvedSourceFile = sourceFileName ?? openFileName;

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
        directoryPath: novelFolder,
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
        hoverPopupCacheProvider((folderPath: novelFolder, word: word)),
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
      // The cause is appended to the headline on screen, so a typed failure
      // contributes only what the localized sentence does not already say:
      // the underlying error for a partial run, nothing at all for a run that
      // found no facts. Spelling out the Dart class name there would tell the
      // reader nothing and read as a defect. The detail dialog still carries
      // the full picture through the diagnostics and the stack trace.
      final (headline, cause) = switch (e) {
        LlmAnalysisPartialFailure(:final failedFileCount, :final firstError) =>
          (
            l10n.llmAnalysis_partialFailure(failedFileCount),
            firstError.toString(),
          ),
        LlmAnalysisNoFactsFailure() => (l10n.llmAnalysis_noFacts(word), null),
        _ => (l10n.llmAnalysis_failed, e.toString()),
      };
      failure = FailureReport(
        headline: headline,
        cause: cause,
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
  ///
  /// [coveredUpToEpisode] is null when the run failed before a bound could be
  /// resolved, which simple analysis can: it has to search the folder first.
  Map<String, String?> _diagnostics({
    required String word,
    required int? coveredUpToEpisode,
    required String? sourceFileName,
  }) {
    final config = _ref.read(llmConfigProvider);
    return {
      'time': DateTime.now().toUtc().toIso8601String(),
      'app version': _ref.read(appVersionLabelProvider),
      'provider': config.provider.name,
      'model': config.model,
      'word': word,
      'covered up to': coveredUpToEpisode == null
          ? '(unresolved)'
          : '$coveredUpToEpisode',
      'file': sourceFileName,
    };
  }

  /// What to say when no client could be built.
  ///
  /// The generic message tells the reader to go and configure an LLM. That is
  /// only right when they have chosen no provider. With one chosen it sends
  /// them somewhere they have already been: what stopped the run is a single
  /// field left blank, or the on-device model being unusable right now.
  /// Naming either points them at something they can act on.
  ///
  /// The reason comes from `llmConfigProblemProvider`, the same decision that
  /// stopped the client from being built, so the sentence cannot describe a
  /// different failure than the one that happened.
  Future<String> _noServiceMessage(AppLocalizations l10n) async {
    // A null problem means the configuration itself is complete, so whatever
    // stopped the run was something else and the checks below take over.
    final problem = await _ref.read(llmConfigProblemProvider.future);
    switch (problem) {
      case LlmConfigProblem.noProvider:
        return l10n.llmAnalysis_noLlmConfigured;
      case LlmConfigProblem.missingEndpoint:
        return l10n.llmAnalysis_missingEndpoint;
      case LlmConfigProblem.missingModel:
        return l10n.llmAnalysis_missingModel;
      case LlmConfigProblem.missingApiKey:
        return l10n.llmAnalysis_missingApiKey;
      case null:
        break;
    }
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

/// Resolve "解析開始(簡易)" → the episode of [word]'s first occurrence in
/// [directoryPath] and the file it was read from, or `null` when the word
/// occurs in none of the folder's text files.
///
/// The occurrences are found with the same search the pipeline uses to collect
/// evidence, rather than a cheaper lookup of its own. A second implementation
/// of the match rule could disagree with the first, and then the bound would
/// name a file the run finds nothing in — failing with "no facts" on a word
/// the reader can see on the page. One full folder read is noise beside the
/// two LLM calls this mode costs, and consistency is structural instead of
/// maintained.
Future<({int episode, String fileName})?> resolveFirstOccurrence({
  required String directoryPath,
  required TextSearchService searchService,
  required String word,
}) async {
  final results = await searchService.searchWithContext(directoryPath, word);
  return resolveFirstOccurrenceEpisode(
    matchedFileNames: results.map((r) => r.fileName).toList(),
    folderFiles: listSortedTextFileNames(directoryPath),
  );
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
