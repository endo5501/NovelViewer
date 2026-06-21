import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';
import 'package:novel_viewer/features/llm_summary/presentation/analysis_runner.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

// Dummy stand-ins for the dependencies of LlmSummaryService.
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

class _DummyFactCache implements FactCacheRepository {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}


class _StubService extends LlmSummaryService {
  _StubService(this._behavior)
      : super(
          llmClient: _DummyClient(),
          repository: _DummyRepo(),
          factCacheRepository: _DummyFactCache(),
          searchService: _DummySearch(),
        );
  final Future<String> Function({
    required String word,
    required int coveredUpToEpisode,
    String? sourceFileName,
  }) _behavior;

  int callCount = 0;
  int? lastCoveredUpToEpisode;
  String? lastSourceFileName;
  String? lastLanguage;
  void Function(AnalysisProgress)? lastOnProgress;

  @override
  Future<String> generateSummary({
    required String directoryPath,
    required String word,
    required int coveredUpToEpisode,
    String? sourceFileName,
    String language = 'ja',
    void Function(AnalysisProgress)? onProgress,
  }) async {
    callCount++;
    lastCoveredUpToEpisode = coveredUpToEpisode;
    lastSourceFileName = sourceFileName;
    lastLanguage = language;
    lastOnProgress = onProgress;
    return _behavior(
      word: word,
      coveredUpToEpisode: coveredUpToEpisode,
      sourceFileName: sourceFileName,
    );
  }
}

class _MockSelectedFile extends SelectedFileNotifier {
  _MockSelectedFile(this._initial);
  final FileEntry? _initial;
  @override
  FileEntry? build() => _initial;
}

class _StubLocale extends LocaleNotifier {
  _StubLocale(this._language);
  final String _language;
  @override
  Locale build() => Locale(_language);
}

ProviderContainer _container(_StubService stub,
    {String directory = '/library/novel_a',
    FileEntry? file,
    String language = 'ja'}) {
  final container = ProviderContainer(overrides: [
    currentDirectoryProvider
        .overrideWith(() => CurrentDirectoryNotifier(directory)),
    selectedFileProvider.overrideWith(() => _MockSelectedFile(file)),
    localeProvider.overrideWith(() => _StubLocale(language)),
    llmSummaryServiceProvider.overrideWith((ref, folderPath) => stub),
    llmClientProvider.overrideWith((_) async => _DummyClient()),
    // run() awaits these FutureProviders before reading the (overridden)
    // service, so they must resolve in tests too. The values are unused here
    // because the service itself is stubbed.
    llmSummaryRepositoryProvider
        .overrideWith((ref, folderPath) async => _DummyRepo()),
    factCacheRepositoryProvider
        .overrideWith((ref, folderPath) async => _DummyFactCache()),
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
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
          ({required word, required coveredUpToEpisode, sourceFileName}) =>
              completer.future);
      final container = _container(stub);
      addTearDown(container.dispose);

      await tester.pumpWidget(_harness(
        container: container,
        onPressed: (ref, context) {
          ref.read(analysisRunnerProvider).run(
                context: context,
                word: 'アリス',
                coveredUpToEpisode: 40,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.byKey(const Key('analysis_modal')), findsOneWidget);
      expect(stub.callCount, 1);
      expect(stub.lastCoveredUpToEpisode, 40);

      completer.complete('mock summary');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('analysis_modal')), findsNothing);
      expect(find.textContaining('「アリス」'), findsOneWidget);
    });

    testWidgets('passes the current display language to the service',
        (tester) async {
      final completer = Completer<String>();
      final stub = _StubService(
          ({required word, required coveredUpToEpisode, sourceFileName}) =>
              completer.future);
      final container = _container(stub, language: 'en');
      addTearDown(container.dispose);

      await tester.pumpWidget(_harness(
        container: container,
        onPressed: (ref, context) {
          ref.read(analysisRunnerProvider).run(
                context: context,
                word: 'アリス',
                coveredUpToEpisode: 40,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(stub.lastLanguage, 'en');

      completer.complete('mock summary');
      await tester.pumpAndSettle();
    });
  });

  group('DefaultAnalysisRunner failure path', () {
    testWidgets('shows error SnackBar and closes modal when service throws',
        (tester) async {
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) async =>
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
                coveredUpToEpisode: 100,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('analysis_modal')), findsNothing);
      expect(find.textContaining('boom'), findsOneWidget);
    });
  });

  group('DefaultAnalysisRunner modal behavior', () {
    testWidgets('modal is barrierDismissible: false (tap outside does nothing)',
        (tester) async {
      final completer = Completer<String>();
      final stub = _StubService(
          ({required word, required coveredUpToEpisode, sourceFileName}) =>
              completer.future);
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
                coveredUpToEpisode: 40,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.byKey(const Key('analysis_modal')), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pump();

      expect(find.byKey(const Key('analysis_modal')), findsOneWidget);
    });
  });

  group('DefaultAnalysisRunner progress display', () {
    testWidgets('initial state shows llmAnalysis_inProgress label',
        (tester) async {
      final completer = Completer<String>();
      final stub = _StubService(
          ({required word, required coveredUpToEpisode, sourceFileName}) =>
              completer.future);
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
                coveredUpToEpisode: 40,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.text('解析中…'), findsOneWidget);
    });

    testWidgets(
        'extracting facts event (round=1) shows "情報を抽出中 (current / total)" label',
        (tester) async {
      final completer = Completer<String>();
      final stub = _StubService(
          ({required word, required coveredUpToEpisode, sourceFileName}) =>
              completer.future);
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
                coveredUpToEpisode: 40,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pump();

      stub.lastOnProgress!(
          const AnalysisExtractingFacts(round: 1, current: 2, total: 5));
      await tester.pump();

      expect(find.text('情報を抽出中 (2 / 5)'), findsOneWidget);
      expect(find.text('解析中…'), findsNothing);
    });

    testWidgets(
        'extracting facts event (round>=2) shows "絞り込み N 周目 (current / total)" label',
        (tester) async {
      final completer = Completer<String>();
      final stub = _StubService(
          ({required word, required coveredUpToEpisode, sourceFileName}) =>
              completer.future);
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
                coveredUpToEpisode: 40,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pump();

      stub.lastOnProgress!(
          const AnalysisExtractingFacts(round: 3, current: 1, total: 2));
      await tester.pump();

      expect(find.text('絞り込み 3 周目 (1 / 2)'), findsOneWidget);
    });

    testWidgets('final summary event shows the localized "最終要約を生成中…" label',
        (tester) async {
      final completer = Completer<String>();
      final stub = _StubService(
          ({required word, required coveredUpToEpisode, sourceFileName}) =>
              completer.future);
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
                coveredUpToEpisode: 40,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pump();

      stub.lastOnProgress!(const AnalysisGeneratingFinalSummary());
      await tester.pump();

      expect(find.text('最終要約を生成中…'), findsOneWidget);
    });

    testWidgets('consecutive progress events keep the same modal route open',
        (tester) async {
      final completer = Completer<String>();
      final stub = _StubService(
          ({required word, required coveredUpToEpisode, sourceFileName}) =>
              completer.future);
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
                coveredUpToEpisode: 40,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pump();

      stub.lastOnProgress!(
          const AnalysisExtractingFacts(round: 1, current: 1, total: 3));
      await tester.pump();
      stub.lastOnProgress!(
          const AnalysisExtractingFacts(round: 1, current: 2, total: 3));
      await tester.pump();
      stub.lastOnProgress!(
          const AnalysisExtractingFacts(round: 1, current: 3, total: 3));
      await tester.pump();
      stub.lastOnProgress!(const AnalysisGeneratingFinalSummary());
      await tester.pump();

      expect(find.byKey(const Key('analysis_modal')), findsOneWidget);
      expect(find.text('最終要約を生成中…'), findsOneWidget);
    });
  });

  group('DefaultAnalysisRunner pre-checks', () {
    testWidgets('shows error SnackBar without opening modal when no directory',
        (tester) async {
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) async =>
            'never',
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
                coveredUpToEpisode: 1,
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('analysis_modal')), findsNothing);
      expect(stub.callCount, 0);
    });
  });

  group('upper bound resolvers', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('runner_resolver_');
    });
    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> touch(String name) async {
      await File('${tempDir.path}/$name').writeAsString('x');
    }

    test('resolveUpperBoundForCurrent returns numeric prefix when present',
        () async {
      await touch('010_a.txt');
      await touch('040_b.txt');
      await touch('100_c.txt');

      final bound = resolveUpperBoundForCurrent(
        directoryPath: tempDir.path,
        currentFile: const FileEntry(name: '040_b.txt', path: ''),
      );
      expect(bound, 40);
    });

    test('resolveUpperBoundForCurrent falls back to lexical rank', () async {
      await touch('intro.txt');
      await touch('part1.txt');
      await touch('part2.txt');

      final bound = resolveUpperBoundForCurrent(
        directoryPath: tempDir.path,
        currentFile: const FileEntry(name: 'part2.txt', path: ''),
      );
      expect(bound, 3);
    });

    test('resolveUpperBoundForAll returns highest numeric prefix', () async {
      await touch('010_a.txt');
      await touch('040_b.txt');
      await touch('100_c.txt');

      expect(resolveUpperBoundForAll(tempDir.path), 100);
    });

    test('resolveUpperBoundForAll falls back to file count when no prefix',
        () async {
      await touch('intro.txt');
      await touch('part1.txt');
      await touch('part2.txt');

      expect(resolveUpperBoundForAll(tempDir.path), 3);
    });

    test('resolveSourceFileForAll picks the highest-prefix file', () async {
      await touch('010_a.txt');
      await touch('040_b.txt');
      await touch('100_c.txt');

      expect(resolveSourceFileForAll(tempDir.path), '100_c.txt');
    });

    test('resolveSourceFileForAll falls back to the last lexical file',
        () async {
      await touch('intro.txt');
      await touch('part1.txt');
      await touch('part2.txt');

      expect(resolveSourceFileForAll(tempDir.path), 'part2.txt');
    });
  });

  group('DefaultAnalysisRunner provider resolution (regression)', () {
    testWidgets(
        'waits for factCacheRepositoryProvider before reading the service '
        '(otherwise analysis silently bails on a null service)',
        (tester) async {
      final completer = Completer<String>();
      final stub = _StubService(
          ({required word, required coveredUpToEpisode, sourceFileName}) =>
              completer.future);
      addTearDown(() {
        if (!completer.isCompleted) completer.complete('done');
      });

      // Reproduce the production wiring: llmSummaryServiceProvider is null
      // until factCacheRepositoryProvider (a FutureProvider that nothing
      // pre-resolves) finishes loading. The stub stands in for the real
      // service so the test stays free of real file/DB I/O.
      final container = ProviderContainer(overrides: [
        currentDirectoryProvider
            .overrideWith(() => CurrentDirectoryNotifier('/library/novel_a')),
        selectedFileProvider.overrideWith(() => _MockSelectedFile(
            const FileEntry(name: '001.txt', path: '/library/novel_a/001.txt'))),
        localeProvider.overrideWith(() => _StubLocale('ja')),
        llmClientProvider.overrideWith((_) async => _DummyClient()),
        llmSummaryRepositoryProvider
            .overrideWith((ref, folderPath) async => _DummyRepo()),
        factCacheRepositoryProvider
            .overrideWith((ref, folderPath) async => _DummyFactCache()),
        llmSummaryServiceProvider.overrideWith((ref, folderPath) {
          // Mirror the real provider: gate on the fact-cache FutureProvider.
          final factCache = ref.watch(factCacheRepositoryProvider(folderPath));
          if (factCache.value == null) return null;
          return stub;
        }),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_harness(
        container: container,
        onPressed: (ref, context) {
          ref.read(analysisRunnerProvider).run(
                context: context,
                word: 'アリス',
                coveredUpToEpisode: 1,
                sourceFileName: '001.txt',
              );
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump();

      // The modal only appears if run() obtained a non-null service, which
      // requires it to await factCacheRepositoryProvider.future first.
      expect(find.byKey(const Key('analysis_modal')), findsOneWidget,
          reason: 'run() must wait for the fact-cache FutureProvider before '
              'reading the (sync) service; otherwise the service is null and '
              'analysis silently bails');
      expect(stub.callCount, 1);
      expect(stub.lastCoveredUpToEpisode, 1);

      completer.complete('mock summary');
      await tester.pumpAndSettle();
    });
  });
}

/// Helper for the no-directory test.
extension on ProviderContainer {
  ProviderContainer copyWithDirectoryOverride(String? directory) {
    dispose();
    return ProviderContainer(overrides: [
      currentDirectoryProvider
          .overrideWith(() => CurrentDirectoryNotifier(directory)),
      selectedFileProvider.overrideWith(() => _MockSelectedFile(null)),
      llmSummaryServiceProvider.overrideWith((ref, folderPath) => _StubService(
            ({required word, required coveredUpToEpisode, sourceFileName})
                async => 'noop',
          )),
      llmClientProvider.overrideWith((_) async => _DummyClient()),
    ]);
  }
}
