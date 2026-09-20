import 'dart:async';
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
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

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

class _DummyFactCache implements FactCacheRepository {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

class _DummySearch implements TextSearchService {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

/// Records what the runner asked for instead of talking to an LLM.
class _RecordingService extends LlmSummaryService {
  _RecordingService()
    : super(
        llmClient: _DummyClient(),
        repository: _DummyRepo(),
        factCacheRepository: _DummyFactCache(),
        searchService: _DummySearch(),
      );

  int callCount = 0;
  String? lastDirectoryPath;
  int? lastCoveredUpToEpisode;
  String? lastSourceFileName;

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
    lastDirectoryPath = directoryPath;
    lastCoveredUpToEpisode = coveredUpToEpisode;
    lastSourceFileName = sourceFileName;
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
  @override
  Locale build() => const Locale('ja');
}

final _packageInfo = PackageInfo(
  appName: 'NovelViewer',
  packageName: 'com.example.novelViewer',
  version: '1.8.2',
  buildNumber: '41',
);

NovelMetadata _novel(String folderName) => NovelMetadata(
  siteType: 'narou',
  novelId: folderName,
  title: 'Title $folderName',
  url: 'https://ncode.syosetu.com/$folderName/',
  folderName: folderName,
  episodeCount: 3,
  downloadedAt: DateTime(2024, 1, 1),
);

void main() {
  late Directory libraryRoot;
  late _RecordingService service;

  /// Every folder a per-folder repository was resolved for. Resolving one is
  /// what opens — and therefore creates — that folder's `novel_data.db`; the
  /// provider-level test pins that link against the real filesystem, so here
  /// it is enough to record who was asked.
  late List<String> openedFolders;

  setUp(() {
    libraryRoot = Directory.systemTemp.createTempSync('analysis_scope');
    service = _RecordingService();
    openedFolders = [];
  });

  tearDown(() {
    if (libraryRoot.existsSync()) {
      libraryRoot.deleteSync(recursive: true);
    }
  });

  String lib(String relative) => p.join(libraryRoot.path, relative);

  // Synchronous on purpose: these run inside `testWidgets`, whose fake-async
  // zone never completes a real filesystem Future, so awaiting one hangs.
  Directory makeDir(String relative) =>
      Directory(lib(relative))..createSync(recursive: true);

  void writeEpisode(String folderPath, String name) =>
      File(p.join(folderPath, name)).writeAsStringSync('アリスが現れた\n');

  ProviderContainer containerAt(
    String directory, {
    FileEntry? file,
    Future<List<NovelMetadata>>? novels,
  }) {
    final container = ProviderContainer(
      overrides: [
        llmSummarySupportedProvider.overrideWithValue(true),
        llmConfigProvider.overrideWithValue(
          const LlmConfig(
            provider: LlmProvider.ollama,
            baseUrl: 'http://127.0.0.1:11434',
            model: 'qwen3:8b',
          ),
        ),
        packageInfoProvider.overrideWithValue(_packageInfo),
        libraryPathProvider.overrideWithValue(libraryRoot.path),
        allNovelsProvider.overrideWith(
          (ref) =>
              novels ??
              Future.value([_novel('narou_n1234ab'), _novel('narou_n5678cd')]),
        ),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier(directory),
        ),
        selectedFileProvider.overrideWith(() => _MockSelectedFile(file)),
        localeProvider.overrideWith(_StubLocale.new),
        llmClientProvider.overrideWith((_) async => _DummyClient()),
        llmSummaryRepositoryProvider.overrideWith((ref, folderPath) async {
          openedFolders.add(folderPath);
          return _DummyRepo();
        }),
        factCacheRepositoryProvider.overrideWith((ref, folderPath) async {
          openedFolders.add(folderPath);
          return _DummyFactCache();
        }),
        llmSummaryServiceProvider.overrideWith((ref, folderPath) {
          openedFolders.add(folderPath);
          return service;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Widget harness(
    ProviderContainer container,
    void Function(AnalysisRunner runner, BuildContext context) onPressed,
  ) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => ElevatedButton(
              onPressed: () =>
                  onPressed(ref.read(analysisRunnerProvider), context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> runAll(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      harness(
        container,
        (runner, context) => runner.runWithScope(
          context: context,
          word: 'アリス',
          scope: AnalysisScope.upToAll,
        ),
      ),
    );
    await tester.tap(find.text('go'));
    // Not pumpAndSettle: the analysis modal carries a progress indicator that
    // animates for as long as it is on screen, so nothing ever settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('解析を開始できる場所', () {
    testWidgets('整理フォルダでは解析が始まらず、novel_data.db も作られない', (tester) async {
      final organizational = makeDir('完結済み');
      writeEpisode(organizational.path, '001.txt');
      final container = containerAt(organizational.path);

      await runAll(tester, container);

      expect(service.callCount, 0);
      expect(openedFolders, isEmpty);
      expect(find.text('小説フォルダを開いてください'), findsOneWidget);
    });

    testWidgets('ライブラリルートでは解析が始まらず、novel_data.db も作られない', (tester) async {
      writeEpisode(libraryRoot.path, '001.txt');
      final container = containerAt(libraryRoot.path);

      await runAll(tester, container);

      expect(service.callCount, 0);
      expect(openedFolders, isEmpty);
    });

    testWidgets('登録済み小説フォルダでは解析が始まる', (tester) async {
      final novelFolder = makeDir('narou_n1234ab');
      writeEpisode(novelFolder.path, '001.txt');
      final container = containerAt(novelFolder.path);

      await runAll(tester, container);

      expect(service.callCount, 1);
      expect(service.lastDirectoryPath, novelFolder.path);
      expect(openedFolders, everyElement(novelFolder.path));
    });

    testWidgets('整理フォルダに入れ子の小説フォルダでも解析が始まる', (tester) async {
      final novelFolder = makeDir(p.join('完結済み', 'narou_n1234ab'));
      writeEpisode(novelFolder.path, '001.txt');
      final container = containerAt(novelFolder.path);

      await runAll(tester, container);

      expect(service.callCount, 1);
      expect(openedFolders, everyElement(novelFolder.path));
    });

    testWidgets('小説一覧の解決を待つ間に移動しても、本文と保存先は同じ作品のまま', (tester) async {
      // The novel list is invalidated after every download and folder
      // operation, so a request made while it is refetching really can be
      // resolved after the reader has moved on. The text being analysed is
      // fixed when the request is made; the database it lands in must be that
      // same novel's, not wherever the browser ended up.
      final novelA = makeDir('narou_n1234ab');
      writeEpisode(novelA.path, '001.txt');
      final novelB = makeDir('narou_n5678cd');
      writeEpisode(novelB.path, '001.txt');
      final pending = Completer<List<NovelMetadata>>();

      final container = containerAt(novelA.path, novels: pending.future);
      await tester.pumpWidget(
        harness(
          container,
          (runner, context) => runner.runWithScope(
            context: context,
            word: 'アリス',
            scope: AnalysisScope.upToAll,
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory(novelB.path);
      pending.complete([_novel('narou_n1234ab'), _novel('narou_n5678cd')]);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(service.lastDirectoryPath, novelA.path);
      expect(openedFolders, isNotEmpty);
      expect(openedFolders, everyElement(novelA.path));
    });

    testWidgets('サブフォルダでは、DBは小説フォルダ・話数は表示中のフォルダから', (tester) async {
      final novelFolder = makeDir('narou_n1234ab');
      final subFolder = makeDir(p.join('narou_n1234ab', '第二部'));
      for (final name in ['001.txt', '002.txt', '003.txt']) {
        writeEpisode(subFolder.path, name);
      }
      final container = containerAt(subFolder.path);

      await runAll(tester, container);

      expect(service.callCount, 1);
      expect(
        service.lastDirectoryPath,
        subFolder.path,
        reason: '本文を読むのは表示中のフォルダ',
      );
      expect(service.lastCoveredUpToEpisode, 3);
      expect(service.lastSourceFileName, '003.txt');
      expect(openedFolders, isNotEmpty);
      expect(openedFolders, everyElement(novelFolder.path));
    });
  });
}
