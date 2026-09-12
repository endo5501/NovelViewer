import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';
import 'package:novel_viewer/features/llm_summary/presentation/analysis_runner.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/llm_summary/providers/on_device_llm_providers.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/failure/failure_detail_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Dummy stand-ins for the dependencies of LlmSummaryService.
class _DummyClient implements LlmClient {
  @override
  int get maxChunkSize => 4000;
  @override
  String get modelId => 'test:fake';

  @override
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) =>
      throw UnimplementedError();
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
  })
  _behavior;

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

final _testPackageInfo = PackageInfo(
  appName: 'NovelViewer',
  packageName: 'com.example.novelViewer',
  version: '1.8.2',
  buildNumber: '41',
);

ProviderContainer _container(
  _StubService stub, {
  String directory = '/library/novel_a',
  FileEntry? file,
  String language = 'ja',
  bool llmSupported = true,
  LlmConfig config = const LlmConfig(
    provider: LlmProvider.ollama,
    baseUrl: 'http://192.168.1.20:11434',
    model: 'qwen3:8b',
  ),
}) {
  final container = ProviderContainer(
    overrides: [
      llmSummarySupportedProvider.overrideWithValue(llmSupported),
      llmConfigProvider.overrideWithValue(config),
      packageInfoProvider.overrideWithValue(_testPackageInfo),
      currentDirectoryProvider.overrideWith(
        () => CurrentDirectoryNotifier(directory),
      ),
      selectedFileProvider.overrideWith(() => _MockSelectedFile(file)),
      localeProvider.overrideWith(() => _StubLocale(language)),
      llmSummaryServiceProvider.overrideWith((ref, folderPath) => stub),
      llmClientProvider.overrideWith((_) async => _DummyClient()),
      // run() awaits these FutureProviders before reading the (overridden)
      // service, so they must resolve in tests too. The values are unused here
      // because the service itself is stubbed.
      llmSummaryRepositoryProvider.overrideWith(
        (ref, folderPath) async => _DummyRepo(),
      ),
      factCacheRepositoryProvider.overrideWith(
        (ref, folderPath) async => _DummyFactCache(),
      ),
    ],
  );
  return container;
}

Widget _harness({
  required ProviderContainer container,
  required void Function(WidgetRef ref, BuildContext context) onPressed,
  Locale locale = const Locale('ja'),
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
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
  group('when no client could be built', () {
    /// A container whose service is absent, with the on-device provider
    /// selected and the model reporting [availability].
    ProviderContainer noService(OnDeviceModelAvailability availability) {
      final container = ProviderContainer(
        overrides: [
          llmSummarySupportedProvider.overrideWithValue(true),
          currentDirectoryProvider.overrideWith(
            () => CurrentDirectoryNotifier('/library/novel_a'),
          ),
          selectedFileProvider.overrideWith(() => _MockSelectedFile(null)),
          localeProvider.overrideWith(() => _StubLocale('ja')),
          llmSummaryServiceProvider.overrideWith((ref, folderPath) => null),
          llmClientProvider.overrideWith((_) async => null),
          llmConfigProvider.overrideWithValue(
            const LlmConfig(provider: LlmProvider.appleOnDevice),
          ),
          onDeviceModelAvailabilityProvider.overrideWith(
            (ref) async => availability,
          ),
          llmSummaryRepositoryProvider.overrideWith(
            (ref, folderPath) async => _DummyRepo(),
          ),
          factCacheRepositoryProvider.overrideWith(
            (ref, folderPath) async => _DummyFactCache(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> runIt(WidgetTester tester, ProviderContainer container) async {
      await tester.pumpWidget(
        _harness(
          container: container,
          onPressed: (ref, context) {
            ref
                .read(analysisRunnerProvider)
                .run(context: context, word: 'アリス', coveredUpToEpisode: 1);
          },
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('a disabled intelligence feature is named, not blamed on '
        'the settings', (tester) async {
      final ja = await AppLocalizations.delegate.load(const Locale('ja'));
      final container = noService(
        OnDeviceModelAvailability.intelligenceNotEnabled,
      );

      await runIt(tester, container);

      // The reader has configured an LLM. Telling them to go and configure
      // one sends them somewhere that cannot help.
      expect(find.text(ja.llmAnalysis_noLlmConfigured), findsNothing);
      expect(
        find.text(ja.settings_llmOnDeviceUnavailableIntelligenceOff),
        findsOneWidget,
      );
    });

    testWidgets('a model still being prepared is named', (tester) async {
      final ja = await AppLocalizations.delegate.load(const Locale('ja'));
      final container = noService(OnDeviceModelAvailability.modelNotReady);

      await runIt(tester, container);

      expect(
        find.text(ja.settings_llmOnDeviceUnavailableModelNotReady),
        findsOneWidget,
      );
    });

    testWidgets('a server provider still gets the configure message', (
      tester,
    ) async {
      final ja = await AppLocalizations.delegate.load(const Locale('ja'));
      final container = ProviderContainer(
        overrides: [
          llmSummarySupportedProvider.overrideWithValue(true),
          currentDirectoryProvider.overrideWith(
            () => CurrentDirectoryNotifier('/library/novel_a'),
          ),
          selectedFileProvider.overrideWith(() => _MockSelectedFile(null)),
          localeProvider.overrideWith(() => _StubLocale('ja')),
          llmSummaryServiceProvider.overrideWith((ref, folderPath) => null),
          llmClientProvider.overrideWith((_) async => null),
          llmConfigProvider.overrideWithValue(const LlmConfig()),
          llmSummaryRepositoryProvider.overrideWith(
            (ref, folderPath) async => _DummyRepo(),
          ),
          factCacheRepositoryProvider.overrideWith(
            (ref, folderPath) async => _DummyFactCache(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await runIt(tester, container);

      expect(find.text(ja.llmAnalysis_noLlmConfigured), findsOneWidget);
    });
  });

  group('DefaultAnalysisRunner success path', () {
    testWidgets(
      'opens modal, calls service, closes modal, shows success SnackBar',
      (tester) async {
        final completer = Completer<String>();
        final stub = _StubService(
          ({required word, required coveredUpToEpisode, sourceFileName}) =>
              completer.future,
        );
        final container = _container(stub);
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _harness(
            container: container,
            onPressed: (ref, context) {
              ref
                  .read(analysisRunnerProvider)
                  .run(context: context, word: 'アリス', coveredUpToEpisode: 40);
            },
          ),
        );

        await tester.tap(find.text('go'));
        await tester.pump();

        expect(find.byKey(const Key('analysis_modal')), findsOneWidget);
        expect(stub.callCount, 1);
        expect(stub.lastCoveredUpToEpisode, 40);

        completer.complete('mock summary');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('analysis_modal')), findsNothing);
        expect(find.textContaining('「アリス」'), findsOneWidget);
      },
    );

    testWidgets('passes the current display language to the service', (
      tester,
    ) async {
      final completer = Completer<String>();
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) =>
            completer.future,
      );
      final container = _container(stub, language: 'en');
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _harness(
          container: container,
          onPressed: (ref, context) {
            ref
                .read(analysisRunnerProvider)
                .run(context: context, word: 'アリス', coveredUpToEpisode: 40);
          },
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(stub.lastLanguage, 'en');

      completer.complete('mock summary');
      await tester.pumpAndSettle();
    });
  });

  group('DefaultAnalysisRunner failure path', () {
    testWidgets('shows error SnackBar and closes modal when service throws', (
      tester,
    ) async {
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) async =>
            throw Exception('boom'),
      );
      final container = _container(stub);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _harness(
          container: container,
          onPressed: (ref, context) {
            ref
                .read(analysisRunnerProvider)
                .run(context: context, word: 'ボブ', coveredUpToEpisode: 100);
          },
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('analysis_modal')), findsNothing);
      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets(
      'a partial failure reports how many files could not be analyzed',
      (tester) async {
        final stub = _StubService(
          ({
            required word,
            required coveredUpToEpisode,
            sourceFileName,
          }) async => throw const LlmAnalysisPartialFailure(
            failedFileCount: 2,
            firstError: 'connection refused',
          ),
        );
        final container = _container(stub);
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _harness(
            container: container,
            onPressed: (ref, context) {
              ref
                  .read(analysisRunnerProvider)
                  .run(context: context, word: 'ボブ', coveredUpToEpisode: 100);
            },
          ),
        );

        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('analysis_modal')), findsNothing);
        expect(find.textContaining('2件'), findsOneWidget);
        // The cause stays visible so the user can act on it.
        expect(find.textContaining('connection refused'), findsOneWidget);
        // The generic failure wording must not be used for this case.
        expect(find.textContaining('解析失敗:'), findsNothing);
      },
    );

    testWidgets('a no-facts failure names the word that yielded nothing', (
      tester,
    ) async {
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) async =>
            throw const LlmAnalysisNoFactsFailure(),
      );
      final container = _container(stub);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _harness(
          container: container,
          onPressed: (ref, context) {
            ref
                .read(analysisRunnerProvider)
                .run(context: context, word: 'ボブ', coveredUpToEpisode: 100);
          },
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.textContaining('「ボブ」'), findsOneWidget);
      expect(find.textContaining('解析失敗:'), findsNothing);
    });

    testWidgets('the partial-failure message honours the display language', (
      tester,
    ) async {
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) async =>
            throw const LlmAnalysisPartialFailure(
              failedFileCount: 2,
              firstError: 'connection refused',
            ),
      );
      final container = _container(stub, language: 'en');
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _harness(
          container: container,
          locale: const Locale('en'),
          onPressed: (ref, context) {
            ref
                .read(analysisRunnerProvider)
                .run(context: context, word: 'ボブ', coveredUpToEpisode: 100);
          },
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not be analyzed'), findsOneWidget);
      expect(find.textContaining('解析を中止しました'), findsNothing);
    });

    testWidgets('the no-facts message honours the display language', (
      tester,
    ) async {
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) async =>
            throw const LlmAnalysisNoFactsFailure(),
      );
      final container = _container(stub, language: 'zh');
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _harness(
          container: container,
          locale: const Locale('zh'),
          onPressed: (ref, context) {
            ref
                .read(analysisRunnerProvider)
                .run(context: context, word: 'ボブ', coveredUpToEpisode: 100);
          },
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.textContaining('分析已中止'), findsOneWidget);
      expect(find.textContaining('解析を中止しました'), findsNothing);
    });

    testWidgets(
      'a failure raised before extraction keeps the generic message',
      (tester) async {
        final stub = _StubService(
          ({
            required word,
            required coveredUpToEpisode,
            sourceFileName,
          }) async => throw Exception('database is locked'),
        );
        final container = _container(stub);
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _harness(
            container: container,
            onPressed: (ref, context) {
              ref
                  .read(analysisRunnerProvider)
                  .run(context: context, word: 'ボブ', coveredUpToEpisode: 100);
            },
          ),
        );

        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();

        expect(find.textContaining('解析失敗:'), findsOneWidget);
        expect(find.textContaining('database is locked'), findsOneWidget);
      },
    );
  });

  group('DefaultAnalysisRunner failure diagnostics', () {
    Future<AppLocalizations> ja() =>
        AppLocalizations.delegate.load(const Locale('ja'));

    Future<ProviderContainer> runFailing(
      WidgetTester tester, {
      required Object error,
      String word = 'アリス',
      int coveredUpToEpisode = 40,
      String? sourceFileName = '040_chapter.txt',
      LlmConfig config = const LlmConfig(
        provider: LlmProvider.ollama,
        baseUrl: 'http://192.168.1.20:11434',
        model: 'qwen3:8b',
      ),
    }) async {
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) async =>
            throw error,
      );
      final container = _container(stub, config: config);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _harness(
          container: container,
          onPressed: (ref, context) {
            ref
                .read(analysisRunnerProvider)
                .run(
                  context: context,
                  word: word,
                  coveredUpToEpisode: coveredUpToEpisode,
                  sourceFileName: sourceFileName,
                );
          },
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return container;
    }

    /// The text the detail dialog presents, i.e. what the copy button takes.
    Future<String> openDetails(WidgetTester tester) async {
      final l10n = await ja();
      await tester.tap(find.text(l10n.failure_detailsAction));
      await tester.pumpAndSettle();
      return tester
          .widget<SelectableText>(
            find.descendant(
              of: find.byType(FailureDetailDialog),
              matching: find.byType(SelectableText),
            ),
          )
          .data!;
    }

    testWidgets('the failure snackbar outlives the default duration', (
      tester,
    ) async {
      await runFailing(tester, error: StateError('boom'));

      await tester.pump(const Duration(seconds: 30));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(SnackBarAction), findsOneWidget);
    });

    testWidgets('the report names the run and the configuration', (
      tester,
    ) async {
      await runFailing(tester, error: StateError('boom'));

      final text = await openDetails(tester);

      expect(text, contains('time: '));
      expect(text, contains('app version: 1.8.2+41'));
      expect(text, contains('provider: ollama'));
      expect(text, contains('model: qwen3:8b'));
      expect(text, contains('word: アリス'));
      expect(text, contains('covered up to: 40'));
      expect(text, contains('file: 040_chapter.txt'));
    });

    testWidgets('the report withholds the endpoint', (tester) async {
      await runFailing(tester, error: StateError('boom'));

      final text = await openDetails(tester);

      expect(text, isNot(contains('192.168.1.20')));
      expect(text, isNot(contains('11434')));
    });

    testWidgets('the report carries the stack trace from the catch site', (
      tester,
    ) async {
      await runFailing(tester, error: StateError('boom'));

      final text = await openDetails(tester);

      expect(text, contains('Bad state: boom'));
      expect(text, contains('#0'));
    });

    testWidgets('the underlying error is not printed twice', (tester) async {
      await runFailing(
        tester,
        error: const LlmAnalysisPartialFailure(
          failedFileCount: 2,
          firstError: 'connection refused',
        ),
      );

      // The action label is a Text too, so read the body off the SnackBar.
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      final body = (bar.content as Text).data!;

      expect('connection refused'.allMatches(body).length, 1);
      expect(body, contains('2件'));
    });

    testWidgets('a successful run keeps a self-dismissing snackbar', (
      tester,
    ) async {
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) async =>
            'summary',
      );
      final container = _container(stub);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _harness(
          container: container,
          onPressed: (ref, context) {
            ref
                .read(analysisRunnerProvider)
                .run(context: context, word: 'アリス', coveredUpToEpisode: 40);
          },
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(SnackBarAction), findsNothing);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('DefaultAnalysisRunner modal behavior', () {
    testWidgets(
      'modal is barrierDismissible: false (tap outside does nothing)',
      (tester) async {
        final completer = Completer<String>();
        final stub = _StubService(
          ({required word, required coveredUpToEpisode, sourceFileName}) =>
              completer.future,
        );
        final container = _container(stub);
        addTearDown(container.dispose);
        addTearDown(() {
          if (!completer.isCompleted) completer.complete('done');
        });

        await tester.pumpWidget(
          _harness(
            container: container,
            onPressed: (ref, context) {
              ref
                  .read(analysisRunnerProvider)
                  .run(context: context, word: 'アリス', coveredUpToEpisode: 40);
            },
          ),
        );

        await tester.tap(find.text('go'));
        await tester.pump();

        expect(find.byKey(const Key('analysis_modal')), findsOneWidget);

        await tester.tapAt(const Offset(5, 5));
        await tester.pump();

        expect(find.byKey(const Key('analysis_modal')), findsOneWidget);
      },
    );
  });

  group('DefaultAnalysisRunner progress display', () {
    testWidgets('initial state shows llmAnalysis_inProgress label', (
      tester,
    ) async {
      final completer = Completer<String>();
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) =>
            completer.future,
      );
      final container = _container(stub);
      addTearDown(container.dispose);
      addTearDown(() {
        if (!completer.isCompleted) completer.complete('done');
      });

      await tester.pumpWidget(
        _harness(
          container: container,
          onPressed: (ref, context) {
            ref
                .read(analysisRunnerProvider)
                .run(context: context, word: 'アリス', coveredUpToEpisode: 40);
          },
        ),
      );

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
              completer.future,
        );
        final container = _container(stub);
        addTearDown(container.dispose);
        addTearDown(() {
          if (!completer.isCompleted) completer.complete('done');
        });

        await tester.pumpWidget(
          _harness(
            container: container,
            onPressed: (ref, context) {
              ref
                  .read(analysisRunnerProvider)
                  .run(context: context, word: 'アリス', coveredUpToEpisode: 40);
            },
          ),
        );

        await tester.tap(find.text('go'));
        await tester.pump();

        stub.lastOnProgress!(
          const AnalysisExtractingFacts(round: 1, current: 2, total: 5),
        );
        await tester.pump();

        expect(find.text('情報を抽出中 (2 / 5)'), findsOneWidget);
        expect(find.text('解析中…'), findsNothing);
      },
    );

    testWidgets(
      'extracting facts event (round>=2) shows "絞り込み N 周目 (current / total)" label',
      (tester) async {
        final completer = Completer<String>();
        final stub = _StubService(
          ({required word, required coveredUpToEpisode, sourceFileName}) =>
              completer.future,
        );
        final container = _container(stub);
        addTearDown(container.dispose);
        addTearDown(() {
          if (!completer.isCompleted) completer.complete('done');
        });

        await tester.pumpWidget(
          _harness(
            container: container,
            onPressed: (ref, context) {
              ref
                  .read(analysisRunnerProvider)
                  .run(context: context, word: 'アリス', coveredUpToEpisode: 40);
            },
          ),
        );

        await tester.tap(find.text('go'));
        await tester.pump();

        stub.lastOnProgress!(
          const AnalysisExtractingFacts(round: 3, current: 1, total: 2),
        );
        await tester.pump();

        expect(find.text('絞り込み 3 周目 (1 / 2)'), findsOneWidget);
      },
    );

    testWidgets('final summary event shows the localized "最終要約を生成中…" label', (
      tester,
    ) async {
      final completer = Completer<String>();
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) =>
            completer.future,
      );
      final container = _container(stub);
      addTearDown(container.dispose);
      addTearDown(() {
        if (!completer.isCompleted) completer.complete('done');
      });

      await tester.pumpWidget(
        _harness(
          container: container,
          onPressed: (ref, context) {
            ref
                .read(analysisRunnerProvider)
                .run(context: context, word: 'アリス', coveredUpToEpisode: 40);
          },
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      stub.lastOnProgress!(const AnalysisGeneratingFinalSummary());
      await tester.pump();

      expect(find.text('最終要約を生成中…'), findsOneWidget);
    });

    testWidgets('consecutive progress events keep the same modal route open', (
      tester,
    ) async {
      final completer = Completer<String>();
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) =>
            completer.future,
      );
      final container = _container(stub);
      addTearDown(container.dispose);
      addTearDown(() {
        if (!completer.isCompleted) completer.complete('done');
      });

      await tester.pumpWidget(
        _harness(
          container: container,
          onPressed: (ref, context) {
            ref
                .read(analysisRunnerProvider)
                .run(context: context, word: 'アリス', coveredUpToEpisode: 40);
          },
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      stub.lastOnProgress!(
        const AnalysisExtractingFacts(round: 1, current: 1, total: 3),
      );
      await tester.pump();
      stub.lastOnProgress!(
        const AnalysisExtractingFacts(round: 1, current: 2, total: 3),
      );
      await tester.pump();
      stub.lastOnProgress!(
        const AnalysisExtractingFacts(round: 1, current: 3, total: 3),
      );
      await tester.pump();
      stub.lastOnProgress!(const AnalysisGeneratingFinalSummary());
      await tester.pump();

      expect(find.byKey(const Key('analysis_modal')), findsOneWidget);
      expect(find.text('最終要約を生成中…'), findsOneWidget);
    });
  });

  group('DefaultAnalysisRunner pre-checks', () {
    testWidgets(
      'shows error SnackBar without opening modal when no directory',
      (tester) async {
        final stub = _StubService(
          ({
            required word,
            required coveredUpToEpisode,
            sourceFileName,
          }) async => 'never',
        );
        final container = _container(
          stub,
          directory: '/x',
        ).copyWithDirectoryOverride(null);
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _harness(
            container: container,
            onPressed: (ref, context) {
              ref
                  .read(analysisRunnerProvider)
                  .run(context: context, word: 'アリス', coveredUpToEpisode: 1);
            },
          ),
        );

        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('analysis_modal')), findsNothing);
        expect(stub.callCount, 0);
      },
    );
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

    test(
      'resolveUpperBoundForCurrent returns numeric prefix when present',
      () async {
        await touch('010_a.txt');
        await touch('040_b.txt');
        await touch('100_c.txt');

        final bound = resolveUpperBoundForCurrent(
          directoryPath: tempDir.path,
          currentFile: const FileEntry(name: '040_b.txt', path: ''),
        );
        expect(bound, 40);
      },
    );

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

    test(
      'resolveUpperBoundForAll falls back to file count when no prefix',
      () async {
        await touch('intro.txt');
        await touch('part1.txt');
        await touch('part2.txt');

        expect(resolveUpperBoundForAll(tempDir.path), 3);
      },
    );

    test('resolveSourceFileForAll picks the highest-prefix file', () async {
      await touch('010_a.txt');
      await touch('040_b.txt');
      await touch('100_c.txt');

      expect(resolveSourceFileForAll(tempDir.path), '100_c.txt');
    });

    test(
      'resolveSourceFileForAll falls back to the last lexical file',
      () async {
        await touch('intro.txt');
        await touch('part1.txt');
        await touch('part2.txt');

        expect(resolveSourceFileForAll(tempDir.path), 'part2.txt');
      },
    );
  });

  group('DefaultAnalysisRunner provider resolution (regression)', () {
    testWidgets(
      'waits for factCacheRepositoryProvider before reading the service '
      '(otherwise analysis silently bails on a null service)',
      (tester) async {
        final completer = Completer<String>();
        final stub = _StubService(
          ({required word, required coveredUpToEpisode, sourceFileName}) =>
              completer.future,
        );
        addTearDown(() {
          if (!completer.isCompleted) completer.complete('done');
        });

        // Reproduce the production wiring: llmSummaryServiceProvider is null
        // until factCacheRepositoryProvider (a FutureProvider that nothing
        // pre-resolves) finishes loading. The stub stands in for the real
        // service so the test stays free of real file/DB I/O.
        final container = ProviderContainer(
          overrides: [
            currentDirectoryProvider.overrideWith(
              () => CurrentDirectoryNotifier('/library/novel_a'),
            ),
            selectedFileProvider.overrideWith(
              () => _MockSelectedFile(
                const FileEntry(
                  name: '001.txt',
                  path: '/library/novel_a/001.txt',
                ),
              ),
            ),
            localeProvider.overrideWith(() => _StubLocale('ja')),
            llmClientProvider.overrideWith((_) async => _DummyClient()),
            llmSummaryRepositoryProvider.overrideWith(
              (ref, folderPath) async => _DummyRepo(),
            ),
            factCacheRepositoryProvider.overrideWith(
              (ref, folderPath) async => _DummyFactCache(),
            ),
            llmSummaryServiceProvider.overrideWith((ref, folderPath) {
              // Mirror the real provider: gate on the fact-cache FutureProvider.
              final factCache = ref.watch(
                factCacheRepositoryProvider(folderPath),
              );
              if (factCache.value == null) return null;
              return stub;
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _harness(
            container: container,
            onPressed: (ref, context) {
              ref
                  .read(analysisRunnerProvider)
                  .run(
                    context: context,
                    word: 'アリス',
                    coveredUpToEpisode: 1,
                    sourceFileName: '001.txt',
                  );
            },
          ),
        );

        await tester.tap(find.text('go'));
        await tester.pump();
        await tester.pump();

        // The modal only appears if run() obtained a non-null service, which
        // requires it to await factCacheRepositoryProvider.future first.
        expect(
          find.byKey(const Key('analysis_modal')),
          findsOneWidget,
          reason:
              'run() must wait for the fact-cache FutureProvider before '
              'reading the (sync) service; otherwise the service is null and '
              'analysis silently bails',
        );
        expect(stub.callCount, 1);
        expect(stub.lastCoveredUpToEpisode, 1);

        completer.complete('mock summary');
        await tester.pumpAndSettle();
      },
    );
  });

  group('where LLM summary is unavailable', () {
    // The popup's re-analyze control is withheld there, so nothing in the UI
    // reaches this runner. Refusing here as well is the second layer: a
    // surface added later without a capability check must still not reach an
    // LLM server.
    testWidgets('run() performs no analysis', (tester) async {
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) async =>
            fail('the summary service was invoked'),
      );
      final container = _container(stub, llmSupported: false);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _harness(
          container: container,
          onPressed: (ref, context) => ref
              .read(analysisRunnerProvider)
              .run(context: context, word: 'アリス', coveredUpToEpisode: 5),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(stub.callCount, 0);
    });

    testWidgets('runWithScope() performs no analysis', (tester) async {
      final stub = _StubService(
        ({required word, required coveredUpToEpisode, sourceFileName}) async =>
            fail('the summary service was invoked'),
      );
      final container = _container(stub, llmSupported: false);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _harness(
          container: container,
          onPressed: (ref, context) => ref
              .read(analysisRunnerProvider)
              .runWithScope(
                context: context,
                word: 'アリス',
                scope: AnalysisScope.upToAll,
              ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(stub.callCount, 0);
    });
  });
}

/// Helper for the no-directory test.
extension on ProviderContainer {
  ProviderContainer copyWithDirectoryOverride(String? directory) {
    dispose();
    return ProviderContainer(
      overrides: [
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier(directory),
        ),
        selectedFileProvider.overrideWith(() => _MockSelectedFile(null)),
        llmSummaryServiceProvider.overrideWith(
          (ref, folderPath) => _StubService(
            ({
              required word,
              required coveredUpToEpisode,
              sourceFileName,
            }) async => 'noop',
          ),
        ),
        llmClientProvider.overrideWith((_) async => _DummyClient()),
      ],
    );
  }
}
