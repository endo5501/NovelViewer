import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_update_check/data/narou_api_client.dart';
import 'package:novel_viewer/features/novel_update_check/data/novel_update_checker.dart';
import 'package:novel_viewer/features/novel_update_check/providers/novel_update_check_providers.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/novel_metadata_db_fixture.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

NovelMetadata _narou(String ncode, {int episodeCount = 10}) => NovelMetadata(
  siteType: 'narou',
  novelId: ncode,
  title: ncode,
  url: 'https://ncode.syosetu.com/$ncode/',
  folderName: 'narou_$ncode',
  episodeCount: episodeCount,
  downloadedAt: DateTime.utc(2026, 1, 1),
);

/// The Narou API reporting [total] episodes for every asked work. Each
/// response waits for [gate] when given (only for requests [gated] accepts,
/// all by default), so a test can look at the state while a check is in
/// flight.
MockClient _api(
  List<Uri> log, {
  int total = 12,
  Completer<void>? gate,
  bool Function(Uri url)? gated,
}) {
  return MockClient((request) async {
    log.add(request.url);
    if (gate != null && (gated?.call(request.url) ?? true)) await gate.future;
    final asked = request.url.queryParameters['ncode']!.split('-');
    final items = [
      '{"allcount":${asked.length}}',
      for (final n in asked)
        '{"ncode":"${n.toUpperCase()}","general_all_no":$total}',
    ];
    return http.Response('[${items.join(',')}]', 200, headers: _json);
  });
}

void main() {
  late NovelDatabase novelDatabase;
  late NovelRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    repository = NovelRepository(novelDatabase);
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  ProviderContainer container(
    http.Client client, {
    List<dynamic> extra = const [],
  }) {
    final c = ProviderContainer(
      overrides: [
        ...extra,
        novelDatabaseProvider.overrideWithValue(novelDatabase),
        updateCheckClientFactoryProvider.overrideWithValue(() => client),
        novelUpdateCheckerFactoryProvider.overrideWithValue(
          (client) => NovelUpdateChecker(
            repository: repository,
            downloadService: DownloadService(
              client: client,
              requestDelay: Duration.zero,
            ),
            narouApi: NarouApiClient(
              client: client,
              requestDelay: Duration.zero,
            ),
            requestDelay: Duration.zero,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('starts idle', () {
    final c = container(_api([]));
    expect(c.read(novelUpdateCheckProvider).status, UpdateCheckStatus.idle);
  });

  test('reports progress, then the summary', () async {
    await repository.upsert(_narou('n1111aa', episodeCount: 10));
    await repository.upsert(_narou('n2222bb', episodeCount: 12));
    final c = container(_api([], total: 12));
    final seen = <UpdateCheckState>[];
    c.listen(novelUpdateCheckProvider, (_, next) => seen.add(next));

    await c.read(novelUpdateCheckProvider.notifier).start();

    final checking = seen.where((s) => s.status == UpdateCheckStatus.checking);
    expect(checking.map((s) => (s.done, s.total)), contains((2, 2)));
    final last = c.read(novelUpdateCheckProvider);
    expect(last.status, UpdateCheckStatus.completed);
    expect(last.summary!.withNewEpisodes, 1);
    expect(last.summary!.failed, 0);
  });

  test('the novel list is reloaded once the check ends', () async {
    await repository.upsert(_narou('n1111aa', episodeCount: 10));
    final c = container(_api([], total: 12));
    final before = await c.read(allNovelsProvider.future);
    expect(before.single.latestEpisodeCount, isNull);

    await c.read(novelUpdateCheckProvider.notifier).start();

    final after = await c.read(allNovelsProvider.future);
    expect(after.single.latestEpisodeCount, 12);
  });

  test('a second start while checking does nothing', () async {
    await repository.upsert(_narou('n1111aa'));
    final log = <Uri>[];
    final gate = Completer<void>();
    final c = container(_api(log, gate: gate));
    final notifier = c.read(novelUpdateCheckProvider.notifier);

    final first = notifier.start();
    await pumpEventQueue();
    final second = notifier.start();
    gate.complete();
    await Future.wait([first, second]);

    expect(log, hasLength(1));
  });

  test('cancelling ends in the cancelled state and keeps results', () async {
    await repository.upsert(_narou('n1111aa'));
    final gate = Completer<void>();
    final c = container(_api([], gate: gate));
    final notifier = c.read(novelUpdateCheckProvider.notifier);
    // Keep the list cached so the reload at the end is observable.
    c.listen(allNovelsProvider, (_, _) {});
    await c.read(allNovelsProvider.future);

    final run = notifier.start();
    await pumpEventQueue();
    notifier.cancel();
    gate.complete();
    await run;

    expect(
      c.read(novelUpdateCheckProvider).status,
      UpdateCheckStatus.cancelled,
    );
  });

  test('an unexpected failure ends in the error state', () async {
    final log = <Uri>[];
    final c = container(
      _api(log),
      extra: [
        allNovelsProvider.overrideWith(
          (ref) => Future<List<NovelMetadata>>.error(StateError('db')),
        ),
      ],
    );

    await c.read(novelUpdateCheckProvider.notifier).start();

    final state = c.read(novelUpdateCheckProvider);
    expect(state.status, UpdateCheckStatus.error);
    expect(state.errorMessage, contains('db'));
    expect(log, isEmpty);
  });

  test('a finished check can be started again after reset', () async {
    await repository.upsert(_narou('n1111aa'));
    final log = <Uri>[];
    final c = container(_api(log));
    final notifier = c.read(novelUpdateCheckProvider.notifier);

    await notifier.start();
    notifier.reset();
    expect(c.read(novelUpdateCheckProvider).status, UpdateCheckStatus.idle);
    await notifier.start();

    expect(log, hasLength(2));
  });

  test('disposing the scope mid-check does not throw afterwards', () async {
    await repository.upsert(_narou('n1111aa'));
    final gate = Completer<void>();
    final c = ProviderContainer(
      overrides: [
        novelDatabaseProvider.overrideWithValue(novelDatabase),
        updateCheckClientFactoryProvider.overrideWithValue(
          () => _api([], gate: gate),
        ),
        novelUpdateCheckerFactoryProvider.overrideWithValue(
          (client) => NovelUpdateChecker(
            repository: repository,
            downloadService: DownloadService(client: client),
            narouApi: NarouApiClient(client: client),
            requestDelay: Duration.zero,
          ),
        ),
      ],
    );

    final run = c.read(novelUpdateCheckProvider.notifier).start();
    await pumpEventQueue();
    c.dispose();
    gate.complete();

    await expectLater(run, completes);
  });

  test('works checked before a cancel reach the novel list', () async {
    await repository.upsert(_narou('n1111aa', episodeCount: 10));
    await repository.upsert(
      NovelMetadata(
        siteType: 'narou',
        novelId: 'n2222bb',
        title: 'n2222bb',
        url: 'https://novel18.syosetu.com/n2222bb/',
        folderName: 'narou_n2222bb',
        episodeCount: 10,
        downloadedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    // The general API answers at once; the R18 one waits until cancelled.
    final r18Gate = Completer<void>();
    final client = _api(
      [],
      total: 12,
      gate: r18Gate,
      gated: (url) => url.path.contains('novel18'),
    );
    final c = container(client);
    c.listen(allNovelsProvider, (_, _) {});
    await c.read(allNovelsProvider.future);
    final notifier = c.read(novelUpdateCheckProvider.notifier);
    c.listen(novelUpdateCheckProvider, (_, next) {
      if (next.status == UpdateCheckStatus.checking && next.done == 1) {
        notifier.cancel();
        if (!r18Gate.isCompleted) r18Gate.complete();
      }
    });

    await notifier.start();

    expect(
      c.read(novelUpdateCheckProvider).status,
      UpdateCheckStatus.cancelled,
    );
    final novels = await c.read(allNovelsProvider.future);
    final byFolder = {for (final n in novels) n.folderName: n};
    expect(byFolder['narou_n1111aa']!.latestEpisodeCount, 12);
    expect(byFolder['narou_n2222bb']!.latestEpisodeCount, isNull);
  });
}
