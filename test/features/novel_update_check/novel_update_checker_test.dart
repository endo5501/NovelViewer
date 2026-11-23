import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_update_check/data/narou_api_client.dart';
import 'package:novel_viewer/features/novel_update_check/data/novel_update_checker.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/shared/utils/cancellation_token.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/novel_metadata_db_fixture.dart';

const _html = {'content-type': 'text/html; charset=utf-8'};
const _json = {'content-type': 'application/json; charset=utf-8'};

String _fixture(String name) =>
    File('test/fixtures/text_download/$name').readAsStringSync();

/// A Kakuyomu index page listing [count] episodes for work [workId].
String _kakuyomuIndex(String workId, int count) {
  final episodes = [
    for (var i = 1; i <= count; i++)
      '"Episode:e$i":{"__typename":"Episode","id":"e$i","title":"第$i話",'
          '"publishedAt":"2025-01-01T00:00:00.000Z"}',
  ];
  final refs = [for (var i = 1; i <= count; i++) '{"__ref":"Episode:e$i"}'];
  return '<html><body><script id="__NEXT_DATA__" type="application/json">'
      '{"props":{"pageProps":{"__APOLLO_STATE__":{'
      '"ROOT_QUERY":{"work({\\"id\\":\\"$workId\\"})":{"__ref":"Work:$workId"}},'
      '"Work:$workId":{"id":"$workId","title":"t",'
      '"tableOfContentsV2":[{"__ref":"TableOfContentsChapter:c1"}]},'
      '"TableOfContentsChapter:c1":{"episodeUnions":[${refs.join(',')}]},'
      '${episodes.join(',')}}}}}</script></body></html>';
}

NovelMetadata _novel(
  String siteType,
  String novelId,
  String url, {
  int episodeCount = 10,
}) {
  return NovelMetadata(
    siteType: siteType,
    novelId: novelId,
    title: '$siteType $novelId',
    url: url,
    folderName: '${siteType}_$novelId',
    episodeCount: episodeCount,
    downloadedAt: DateTime.utc(2026, 1, 1),
  );
}

/// A fake web: the Narou APIs report [narouCounts] (ncode -> total), Kakuyomu
/// work pages list [kakuyomuCounts] (work id -> total) episodes, and any path
/// in [failing] answers 404. Every requested URL is logged.
MockClient _web(
  List<Uri> log, {
  Map<String, int> narouCounts = const {},
  Map<String, int> kakuyomuCounts = const {},
  Set<String> failing = const {},
}) {
  return MockClient((request) async {
    final url = request.url;
    log.add(url);
    if (failing.any(url.toString().contains)) {
      return http.Response('not found', 404);
    }
    if (url.host == 'api.syosetu.com') {
      final asked = url.queryParameters['ncode']!.split('-');
      final items = [
        '{"allcount":${asked.length}}',
        for (final n in asked)
          if (narouCounts.containsKey(n))
            '{"ncode":"${n.toUpperCase()}","general_all_no":${narouCounts[n]}}',
      ];
      return http.Response('[${items.join(',')}]', 200, headers: _json);
    }
    if (url.host == 'kakuyomu.jp') {
      final id = url.pathSegments[1];
      return http.Response(
        _kakuyomuIndex(id, kakuyomuCounts[id]!),
        200,
        headers: _html,
      );
    }
    if (url.host == 'syosetu.org') {
      return http.Response(
        _fixture('hameln_index_valid.html'),
        200,
        headers: _html,
      );
    }
    return http.Response('unexpected', 500);
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

  NovelUpdateChecker checker(http.Client client) => NovelUpdateChecker(
    repository: repository,
    downloadService: DownloadService(
      client: client,
      requestDelay: Duration.zero,
      retryBaseDelay: Duration.zero,
    ),
    narouApi: NarouApiClient(client: client, requestDelay: Duration.zero),
    requestDelay: Duration.zero,
    clock: () => DateTime.utc(2026, 11, 23, 9),
  );

  Future<List<NovelMetadata>> register(List<NovelMetadata> novels) async {
    for (final n in novels) {
      await repository.upsert(n);
    }
    return repository.findAll();
  }

  test('checks only Narou, Kakuyomu and Hameln works', () async {
    final log = <Uri>[];
    final novels = await register([
      _novel('narou', 'n1111aa', 'https://ncode.syosetu.com/n1111aa/'),
      _novel('web', 'abc', 'https://example.com/a'),
      _novel('aozora', '123', 'https://www.aozora.gr.jp/cards/1/card2.html'),
    ]);
    final progress = <(int, int)>[];

    await checker(
      _web(log, narouCounts: {'n1111aa': 10}),
    ).run(novels, onProgress: (done, total) => progress.add((done, total)));

    expect(log.map((u) => u.host).toSet(), {'api.syosetu.com'});
    expect(progress.last, (1, 1));
  });

  test('records each observed total and reports new episodes', () async {
    final novels = await register([
      _novel(
        'narou',
        'n1111aa',
        'https://ncode.syosetu.com/n1111aa/',
        episodeCount: 120,
      ),
      _novel(
        'narou',
        'n2222bb',
        'https://novel18.syosetu.com/n2222bb/',
        episodeCount: 30,
      ),
      _novel(
        'kakuyomu',
        '777',
        'https://kakuyomu.jp/works/777',
        episodeCount: 5,
      ),
      _novel(
        'hameln',
        '000000',
        'https://syosetu.org/novel/000000/',
        episodeCount: 4,
      ),
    ]);
    final log = <Uri>[];

    final summary = await checker(
      _web(
        log,
        narouCounts: {'n1111aa': 125, 'n2222bb': 30},
        kakuyomuCounts: {'777': 6},
      ),
    ).run(novels);

    expect(summary.checked, 4);
    expect(summary.withNewEpisodes, 2);
    expect(summary.failed, 0);

    Future<int?> latest(String folder) async =>
        (await repository.findByFolderName(folder))!.latestEpisodeCount;
    expect(await latest('narou_n1111aa'), 125);
    expect(await latest('narou_n2222bb'), 30);
    expect(await latest('kakuyomu_777'), 6);
    expect(await latest('hameln_000000'), 4);
    expect(
      (await repository.findByFolderName('kakuyomu_777'))!.updateCheckedAt,
      DateTime.utc(2026, 11, 23, 9),
    );

    final apiPaths = log
        .where((u) => u.host == 'api.syosetu.com')
        .map((u) => u.path)
        .toList();
    expect(apiPaths, unorderedEquals(['/novelapi/api/', '/novel18api/api/']));
    // Only index pages are read: no episode page is ever requested.
    expect(log.where((u) => u.path.contains('/episodes/')), isEmpty);
    expect(log.where((u) => u.path.endsWith('.html')), isEmpty);
  });

  test('Narou works are asked in one request', () async {
    final log = <Uri>[];
    final novels = await register([
      for (final n in ['n1111aa', 'n2222bb', 'n3333cc'])
        _novel('narou', n, 'https://ncode.syosetu.com/$n/'),
    ]);

    await checker(
      _web(log, narouCounts: {'n1111aa': 1, 'n2222bb': 1, 'n3333cc': 1}),
    ).run(novels);

    expect(log, hasLength(1));
  });

  test('progress counts every target work up to the total', () async {
    final novels = await register([
      _novel('narou', 'n1111aa', 'https://ncode.syosetu.com/n1111aa/'),
      _novel('kakuyomu', '1', 'https://kakuyomu.jp/works/1'),
      _novel('kakuyomu', '2', 'https://kakuyomu.jp/works/2'),
    ]);
    final progress = <(int, int)>[];

    await checker(
      _web([], narouCounts: {'n1111aa': 1}, kakuyomuCounts: {'1': 1, '2': 1}),
    ).run(novels, onProgress: (done, total) => progress.add((done, total)));

    expect(progress.first, (0, 3));
    expect(progress.last, (3, 3));
    expect(progress.map((p) => p.$1), orderedEquals([0, 1, 2, 3]));
  });

  test('a failed work keeps its previous result and the rest go on', () async {
    final novels = await register([
      _novel('kakuyomu', '1', 'https://kakuyomu.jp/works/1', episodeCount: 1),
      _novel('kakuyomu', '2', 'https://kakuyomu.jp/works/2', episodeCount: 1),
      _novel('kakuyomu', '3', 'https://kakuyomu.jp/works/3', episodeCount: 1),
    ]);
    await repository.recordUpdateCheck(
      'kakuyomu_2',
      latestEpisodeCount: 125,
      checkedAt: DateTime.utc(2026, 1, 1),
    );

    final summary = await checker(
      _web([], kakuyomuCounts: {'1': 2, '3': 1}, failing: {'/works/2'}),
    ).run(novels);

    expect(summary.failed, 1);
    expect(summary.checked, 2);
    expect(summary.withNewEpisodes, 1);
    final kept = await repository.findByFolderName('kakuyomu_2');
    expect(kept!.latestEpisodeCount, 125);
    expect(kept.updateCheckedAt, DateTime.utc(2026, 1, 1));
    expect(
      (await repository.findByFolderName('kakuyomu_3'))!.latestEpisodeCount,
      1,
    );
  });

  test('a Narou work missing from the API answer counts as failed', () async {
    final novels = await register([
      _novel('narou', 'n1111aa', 'https://ncode.syosetu.com/n1111aa/'),
      _novel('narou', 'n2222bb', 'https://ncode.syosetu.com/n2222bb/'),
    ]);

    final summary = await checker(
      _web([], narouCounts: {'n1111aa': 10}),
    ).run(novels);

    expect(summary.failed, 1);
    expect(
      (await repository.findByFolderName('narou_n2222bb'))!.latestEpisodeCount,
      isNull,
    );
  });

  test('a cancellation stops further requests and keeps results', () async {
    final novels = await register([
      _novel('kakuyomu', '1', 'https://kakuyomu.jp/works/1'),
      _novel('kakuyomu', '2', 'https://kakuyomu.jp/works/2'),
      _novel('kakuyomu', '3', 'https://kakuyomu.jp/works/3'),
    ]);
    final log = <Uri>[];
    final token = CancellationToken();

    await expectLater(
      checker(_web(log, kakuyomuCounts: {'1': 11, '2': 11, '3': 11})).run(
        novels,
        cancelToken: token,
        onProgress: (done, _) {
          if (done == 1) token.cancel();
        },
      ),
      throwsA(isA<CancelledException>()),
    );

    expect(log, hasLength(1));
    final checked = await repository.findAll();
    expect(
      checked
          .where((n) => n.latestEpisodeCount != null)
          .map((n) => n.folderName),
      hasLength(1),
    );
  });

  test('nothing to check finishes at once with an empty summary', () async {
    final log = <Uri>[];
    final novels = await register([
      _novel('web', 'abc', 'https://example.com/a'),
    ]);

    final summary = await checker(_web(log)).run(novels);

    expect(log, isEmpty);
    expect(summary.checked, 0);
    expect(summary.withNewEpisodes, 0);
    expect(summary.failed, 0);
  });
}
