import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/llm_summary/presentation/analysis_runner.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_reference/domain/reference_graph.dart';
import 'package:novel_viewer/features/novel_reference/providers/novel_reference_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/failure/failure_detail_dialog.dart';
import 'package:novel_viewer/shared/utils/novel_folder_locator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

class _DummyClient implements LlmClient {
  @override
  int get maxChunkSize => 4000;
  @override
  int get maxResponseSize => 4000;
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

class _DummyFactCache implements FactCacheRepository {
  _DummyFactCache(this.folderPath);
  final String folderPath;
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

class _RecordingService extends LlmSummaryService {
  _RecordingService()
    : super(
        llmClient: _DummyClient(),
        repository: _DummyRepo(),
        factCacheRepository: _DummyFactCache(''),
        searchService: TextSearchService(),
      );

  int callCount = 0;
  List<ReferenceSourceScope>? lastReferenceSources;
  ReferenceScope? lastReferenceScope;

  @override
  Future<String> generateSummary({
    required String directoryPath,
    required String word,
    required int coveredUpToEpisode,
    String? sourceFileName,
    String language = 'ja',
    List<ReferenceSourceScope> referenceSources = const [],
    ReferenceScope referenceScope = ReferenceScope.whole,
    void Function(AnalysisProgress)? onProgress,
  }) async {
    callCount++;
    lastReferenceSources = referenceSources;
    lastReferenceScope = referenceScope;
    return 'summary';
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

NovelMetadata _novel(String folderName, String title) => NovelMetadata(
  siteType: 'narou',
  novelId: folderName,
  title: title,
  url: 'https://example.com/$folderName/',
  folderName: folderName,
  episodeCount: 1,
  downloadedAt: DateTime(2024, 1, 1),
);

ReferenceRelation _r(String child, String parent) =>
    ReferenceRelation(child: child, parent: parent);

void main() {
  late Directory library;
  late String part3Path;
  late String part2Path;
  late String part1Path;

  setUp(() {
    library = Directory.systemTemp.createTempSync('runner_refs_');
    part3Path = p.join(library.path, 'part3');
    part2Path = p.join(library.path, 'series', 'part2');
    part1Path = p.join(library.path, 'series', 'part1');
    for (final path in [part3Path, part2Path, part1Path]) {
      Directory(path).createSync(recursive: true);
    }
    File(p.join(part3Path, '001.txt')).writeAsStringSync('アリスが旅に出る。');
  });

  tearDown(() {
    library.deleteSync(recursive: true);
  });

  final novels = [
    _novel('part3', '第3部'),
    _novel('part2', '第2部'),
    _novel('part1', '第1部'),
  ];

  ({ProviderContainer container, _RecordingService service, List<int> scans})
  build({
    required List<ReferenceRelation> relations,
    List<NovelMetadata>? registered,
    Object? relationsError,
    String language = 'ja',
  }) {
    final service = _RecordingService();
    final scans = <int>[];
    final container = ProviderContainer(
      overrides: [
        llmSummarySupportedProvider.overrideWithValue(true),
        llmConfigProvider.overrideWithValue(
          const LlmConfig(
            provider: LlmProvider.ollama,
            baseUrl: 'http://localhost:11434',
            model: 'm',
          ),
        ),
        packageInfoProvider.overrideWithValue(
          PackageInfo(
            appName: 'NovelViewer',
            packageName: 'x',
            version: '1.0.0',
            buildNumber: '1',
          ),
        ),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier(part3Path),
        ),
        libraryPathProvider.overrideWithValue(library.path),
        allNovelsProvider.overrideWith((ref) => registered ?? novels),
        selectedFileProvider.overrideWith(
          () => _MockSelectedFile(
            FileEntry(name: '001.txt', path: p.join(part3Path, '001.txt')),
          ),
        ),
        localeProvider.overrideWith(() => _StubLocale(language)),
        llmSummaryServiceProvider.overrideWith((ref, folderPath) => service),
        llmClientProvider.overrideWith((_) async => _DummyClient()),
        llmSummaryRepositoryProvider.overrideWith(
          (ref, folderPath) async => _DummyRepo(),
        ),
        factCacheRepositoryProvider.overrideWith(
          (ref, folderPath) async => _DummyFactCache(folderPath),
        ),
        novelReferenceRelationsProvider.overrideWith((ref) async {
          if (relationsError != null) throw relationsError;
          return relations;
        }),
        novelFolderLocatorProvider.overrideWithValue(({
          required String libraryRoot,
          required Set<String> registeredFolderNames,
        }) async {
          scans.add(1);
          return locateNovelFolders(
            libraryRoot: libraryRoot,
            registeredFolderNames: registeredFolderNames,
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, service: service, scans: scans);
  }

  Future<void> pump(
    WidgetTester tester,
    ProviderContainer container,
    void Function(WidgetRef ref, BuildContext context) onPressed, {
    Locale locale = const Locale('ja'),
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
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
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('go'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  void runUpToCurrent(WidgetRef ref, BuildContext context) => ref
      .read(analysisRunnerProvider)
      .run(context: context, word: 'アリス', coveredUpToEpisode: 1);

  testWidgets('passes every ancestor with its title, path and own cache', (
    tester,
  ) async {
    final h = build(relations: [_r('part3', 'part2'), _r('part2', 'part1')]);

    await pump(tester, h.container, runUpToCurrent);

    final refs = h.service.lastReferenceSources!;
    expect(refs.map((r) => r.folderName), ['part1', 'part2']);
    expect(refs.map((r) => r.title), ['第1部', '第2部']);
    expect(refs.map((r) => r.folderPath), [part1Path, part2Path]);
    expect(
      refs.map((r) => (r.factCacheRepository as _DummyFactCache).folderPath),
      [part1Path, part2Path],
    );
    expect(h.service.lastReferenceScope, ReferenceScope.whole);
  });

  testWidgets('the quick analysis reads ancestors at first occurrence only', (
    tester,
  ) async {
    final h = build(relations: [_r('part3', 'part1')]);

    await pump(
      tester,
      h.container,
      (ref, context) => ref
          .read(analysisRunnerProvider)
          .runWithScope(
            context: context,
            word: 'アリス',
            scope: AnalysisScope.firstOccurrence,
          ),
    );

    expect(h.service.callCount, 1);
    expect(h.service.lastReferenceScope, ReferenceScope.firstOccurrence);
  });

  testWidgets('a novel without reference sources does not walk the library', (
    tester,
  ) async {
    final h = build(relations: [_r('other', 'part1')]);

    await pump(tester, h.container, runUpToCurrent);

    expect(h.service.callCount, 1);
    expect(h.service.lastReferenceSources, isEmpty);
    expect(h.scans, isEmpty);
  });

  testWidgets('a missing ancestor stops the run before the service', (
    tester,
  ) async {
    Directory(part1Path).deleteSync(recursive: true);
    final h = build(relations: [_r('part3', 'part1')]);
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));

    await pump(tester, h.container, runUpToCurrent);

    expect(h.service.callCount, 0);
    expect(find.byKey(const Key('analysis_modal')), findsNothing);
    expect(
      find.textContaining(l10n.llmAnalysis_referenceSourcesMissing('『第1部』')),
      findsOneWidget,
    );
  });

  testWidgets('an ancestor\'s missing ancestor also stops the run', (
    tester,
  ) async {
    Directory(part1Path).deleteSync(recursive: true);
    final h = build(relations: [_r('part3', 'part2'), _r('part2', 'part1')]);

    await pump(tester, h.container, runUpToCurrent);

    expect(h.service.callCount, 0);
    expect(find.textContaining('『第1部』'), findsOneWidget);
    expect(find.textContaining('『第2部』'), findsNothing);
  });

  testWidgets('every missing ancestor is named, by folder when unregistered', (
    tester,
  ) async {
    Directory(part1Path).deleteSync(recursive: true);
    final h = build(relations: [_r('part3', 'part1'), _r('part3', 'gone')]);

    await pump(tester, h.container, runUpToCurrent);

    expect(find.textContaining('『第1部』'), findsOneWidget);
    expect(find.textContaining('『gone』'), findsOneWidget);
  });

  testWidgets('the failure details carry the missing folder names', (
    tester,
  ) async {
    Directory(part1Path).deleteSync(recursive: true);
    final h = build(relations: [_r('part3', 'part1')]);
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));

    await pump(tester, h.container, runUpToCurrent);
    await tester.tap(find.text(l10n.failure_detailsAction));
    await tester.pumpAndSettle();

    final details = tester
        .widget<SelectableText>(
          find.descendant(
            of: find.byType(FailureDetailDialog),
            matching: find.byType(SelectableText),
          ),
        )
        .data!;
    expect(details, contains('part1'));
  });

  testWidgets('an unexpected failure resolving sources is reported', (
    tester,
  ) async {
    final h = build(relations: const [], relationsError: StateError('db'));
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));

    await pump(tester, h.container, runUpToCurrent);

    expect(h.service.callCount, 0);
    expect(find.textContaining(l10n.llmAnalysis_failed), findsOneWidget);
  });

  testWidgets('the missing-source message uses the locale\'s punctuation', (
    tester,
  ) async {
    Directory(part1Path).deleteSync(recursive: true);
    final h = build(
      relations: [_r('part3', 'part1'), _r('part3', 'gone')],
      language: 'en',
    );

    await pump(tester, h.container, runUpToCurrent, locale: const Locale('en'));

    final message = find.textContaining('could not be found');
    expect(message, findsOneWidget);
    final text = tester.widget<Text>(message).data!;
    expect(text, isNot(contains('『')));
    expect(text, isNot(contains('、')));
    expect(text, contains('第1部'));
    expect(text, contains('gone'));
  });
}
