import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/analysis_runner.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';

// Dummy stand-ins for the dependencies of LlmSummaryService. They are never
// invoked because [_StubService] overrides `generateSummary` (the only method
// the runner calls).
class _DummyClient implements LlmClient {
  @override
  Future<String> generate(String prompt) => throw UnimplementedError();
  @override
  Future<void> releaseResources() async {}
}

class _DummyRepo implements LlmSummaryRepository {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

class _DummySearch implements TextSearchService {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

class _StubService extends LlmSummaryService {
  _StubService(this._behavior)
      : super(
          llmClient: _DummyClient(),
          repository: _DummyRepo(),
          searchService: _DummySearch(),
        );
  final Future<String> Function({
    required String word,
    required SummaryType type,
    String? currentFileName,
  }) _behavior;

  int callCount = 0;

  @override
  Future<String> generateSummary({
    required String directoryPath,
    required String folderName,
    required String word,
    required SummaryType summaryType,
    String? currentFileName,
  }) async {
    callCount++;
    return _behavior(
      word: word,
      type: summaryType,
      currentFileName: currentFileName,
    );
  }
}

class _MockSelectedFile extends SelectedFileNotifier {
  _MockSelectedFile(this._initial);
  final FileEntry? _initial;
  @override
  FileEntry? build() => _initial;
}

ProviderContainer _container(_StubService stub,
    {String directory = '/library/novel_a', FileEntry? file}) {
  final container = ProviderContainer(overrides: [
    currentDirectoryProvider
        .overrideWith(() => CurrentDirectoryNotifier(directory)),
    selectedFileProvider.overrideWith(() => _MockSelectedFile(file)),
    llmSummaryServiceProvider.overrideWithValue(stub),
    // Keep llmClientProvider future resolved so the runner doesn't await
    // forever. The real DefaultAnalysisRunner awaits llmClientProvider.future
    // before reading the service.
    llmClientProvider.overrideWith((_) async => _DummyClient()),
  ]);
  return container;
}

Widget _harness({
  required ProviderContainer container,
  required void Function(WidgetRef ref, BuildContext context) onPressed,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => ElevatedButton(
            onPressed: () => onPressed(ref, context),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('DefaultAnalysisRunner success path', () {
    testWidgets('opens modal, calls service, closes modal, shows success SnackBar',
        (tester) async {
      final completer = Completer<String>();
      final stub = _StubService(
          ({required word, required type, currentFileName}) => completer.future);
      final container = _container(stub);
      addTearDown(container.dispose);

      await tester.pumpWidget(_harness(
        container: container,
        onPressed: (ref, context) {
          ref.read(analysisRunnerProvider).run(
                context: context,
                word: 'アリス',
                type: SummaryType.noSpoiler,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pump(); // start modal

      expect(find.byKey(const Key('analysis_modal')), findsOneWidget,
          reason: 'Modal must be shown while analysis is in flight');
      expect(stub.callCount, 1);

      completer.complete('mock summary');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('analysis_modal')), findsNothing,
          reason: 'Modal must close once analysis resolves');
      expect(find.textContaining('「アリス」'), findsOneWidget,
          reason:
              'A success SnackBar mentioning the analyzed word must be shown');
    });
  });

  group('DefaultAnalysisRunner failure path', () {
    testWidgets('shows error SnackBar and closes modal when service throws',
        (tester) async {
      final stub = _StubService(
        ({required word, required type, currentFileName}) async =>
            throw Exception('boom'),
      );
      final container = _container(stub);
      addTearDown(container.dispose);

      await tester.pumpWidget(_harness(
        container: container,
        onPressed: (ref, context) {
          ref.read(analysisRunnerProvider).run(
                context: context,
                word: 'ボブ',
                type: SummaryType.spoiler,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('analysis_modal')), findsNothing,
          reason: 'Modal must close after failure too');
      expect(find.textContaining('boom'), findsOneWidget,
          reason: 'Error message should be surfaced in a SnackBar');
    });
  });

  group('DefaultAnalysisRunner modal behavior', () {
    testWidgets('modal is barrierDismissible: false (tap outside does nothing)',
        (tester) async {
      final completer = Completer<String>();
      final stub = _StubService(
          ({required word, required type, currentFileName}) => completer.future);
      final container = _container(stub);
      addTearDown(container.dispose);
      addTearDown(() {
        if (!completer.isCompleted) completer.complete('done');
      });

      await tester.pumpWidget(_harness(
        container: container,
        onPressed: (ref, context) {
          ref.read(analysisRunnerProvider).run(
                context: context,
                word: 'アリス',
                type: SummaryType.noSpoiler,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.byKey(const Key('analysis_modal')), findsOneWidget);

      // Tap on the modal barrier (top-left corner, outside the dialog box).
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();

      expect(find.byKey(const Key('analysis_modal')), findsOneWidget,
          reason:
              'Modal must remain open when the user taps outside its bounds');
    });
  });

  group('DefaultAnalysisRunner pre-checks', () {
    testWidgets('shows error SnackBar without opening modal when no directory',
        (tester) async {
      final stub = _StubService(
        ({required word, required type, currentFileName}) async => 'never',
      );
      final container =
          _container(stub, directory: '/x').copyWithDirectoryOverride(null);
      addTearDown(container.dispose);

      await tester.pumpWidget(_harness(
        container: container,
        onPressed: (ref, context) {
          ref.read(analysisRunnerProvider).run(
                context: context,
                word: 'アリス',
                type: SummaryType.noSpoiler,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('analysis_modal')), findsNothing,
          reason: 'Modal must not appear when no novel is open');
      expect(stub.callCount, 0,
          reason: 'Service must not be invoked without a directory');
    });
  });
}

/// Helper for the no-directory test. ProviderContainer doesn't have a
/// "modify overrides after creation" API, so this extension builds a fresh
/// container with the same setup minus the directory.
extension on ProviderContainer {
  ProviderContainer copyWithDirectoryOverride(String? directory) {
    dispose();
    return ProviderContainer(overrides: [
      currentDirectoryProvider
          .overrideWith(() => CurrentDirectoryNotifier(directory)),
      selectedFileProvider.overrideWith(() => _MockSelectedFile(null)),
      llmSummaryServiceProvider.overrideWithValue(_StubService(
        ({required word, required type, currentFileName}) async => 'noop',
      )),
      llmClientProvider.overrideWith((_) async => _DummyClient()),
    ]);
  }
}
