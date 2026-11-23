import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/hameln_site.dart';
import 'package:novel_viewer/features/text_download/data/sites/kakuyomu_site.dart';
import 'package:novel_viewer/shared/utils/cancellation_token.dart';

import 'helpers/download_test_helpers.dart';

/// `DownloadService.fetchEpisodeCount` reads only the first index page and
/// reports how many episodes it lists — the update check's view of "how many
/// episodes the site has now" for Kakuyomu and Hameln.
void main() {
  String fixture(String name) =>
      File('test/fixtures/text_download/$name').readAsStringSync();

  final kakuyomuUrl = Uri.parse('https://kakuyomu.jp/works/12345');
  final hamelnUrl = Uri.parse('https://syosetu.org/novel/000000/');

  DownloadService service(List<String> log, Map<String, List<FakeRoute>> seq) {
    return DownloadService(
      client: sequencedClient(seq, requestLog: log),
      requestDelay: Duration.zero,
      retryBaseDelay: Duration.zero,
    );
  }

  test('counts a Kakuyomu index from one request', () async {
    final log = <String>[];
    final s = service(log, {
      '/works/12345': [
        FakeRoute('', body: fixture('kakuyomu_index_valid.html')),
      ],
    });

    final count = await s.fetchEpisodeCount(
      site: KakuyomuSite(),
      url: kakuyomuUrl,
    );

    expect(count, 2);
    expect(log, hasLength(1));
  });

  test('counts a Hameln index', () async {
    final log = <String>[];
    final s = service(log, {
      '/novel/000000': [
        FakeRoute('', body: fixture('hameln_index_valid.html')),
      ],
    });

    final count = await s.fetchEpisodeCount(site: HamelnSite(), url: hamelnUrl);

    expect(count, 4);
    expect(log, hasLength(1));
  });

  test('a short story with only a body counts as one episode', () async {
    final s = service([], {
      '/novel/000000': [
        FakeRoute('', body: fixture('hameln_index_short_story.html')),
      ],
    });

    final count = await s.fetchEpisodeCount(site: HamelnSite(), url: hamelnUrl);

    expect(count, 1);
  });

  test('an index with neither episodes nor body is an error', () async {
    final s = service([], {
      '/novel/000000': [
        FakeRoute('', body: fixture('hameln_index_drifted.html')),
      ],
    });

    await expectLater(
      s.fetchEpisodeCount(site: HamelnSite(), url: hamelnUrl),
      throwsA(isA<EmptyIndexException>()),
    );
  });

  test('a transient 503 is retried', () async {
    final log = <String>[];
    final s = service(log, {
      '/works/12345': [
        const FakeRoute('', statusCode: 503),
        FakeRoute('', body: fixture('kakuyomu_index_valid.html')),
      ],
    });

    final count = await s.fetchEpisodeCount(
      site: KakuyomuSite(),
      url: kakuyomuUrl,
    );

    expect(count, 2);
    expect(log, hasLength(2));
  });

  test('a 404 fails at once', () async {
    final log = <String>[];
    final s = service(log, {
      '/works/12345': [const FakeRoute('', statusCode: 404)],
    });

    await expectLater(
      s.fetchEpisodeCount(site: KakuyomuSite(), url: kakuyomuUrl),
      throwsA(isA<HttpException>()),
    );
    expect(log, hasLength(1));
  });

  test('a cancelled token sends no request', () async {
    final log = <String>[];
    final s = service(log, {
      '/works/12345': [
        FakeRoute('', body: fixture('kakuyomu_index_valid.html')),
      ],
    });
    final token = CancellationToken()..cancel();

    await expectLater(
      s.fetchEpisodeCount(
        site: KakuyomuSite(),
        url: kakuyomuUrl,
        cancelToken: token,
      ),
      throwsA(isA<CancelledException>()),
    );
    expect(log, isEmpty);
  });
}
