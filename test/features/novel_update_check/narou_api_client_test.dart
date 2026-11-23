import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/novel_update_check/data/narou_api_client.dart';
import 'package:novel_viewer/shared/utils/cancellation_token.dart';

/// Responses captured from the real API on 2026-11-23 (see design.md).
String _fixture(String name) =>
    File('test/fixtures/narou_api/$name').readAsStringSync();

const _json = {'content-type': 'application/json; charset=utf-8'};

/// Answers every request with the Narou API's shape, listing the requested
/// ncodes (upper-cased, as the API does) except those in [missing].
MockClient _echoingApi(
  List<Uri> log, {
  Set<String> missing = const {},
  int episodes = 7,
}) {
  return MockClient((request) async {
    log.add(request.url);
    final requested = request.url.queryParameters['ncode']!.split('-');
    final found = requested.where((n) => !missing.contains(n)).toList();
    final items = [
      '{"allcount":${found.length}}',
      for (final n in found)
        '{"ncode":"${n.toUpperCase()}","general_all_no":$episodes}',
    ];
    return http.Response('[${items.join(',')}]', 200, headers: _json);
  });
}

NarouApiClient _client(http.Client http) =>
    NarouApiClient(client: http, requestDelay: Duration.zero);

Future<Map<String, int?>> _collect(Stream<Map<String, int?>> chunks) async {
  final all = <String, int?>{};
  await for (final chunk in chunks) {
    all.addAll(chunk);
  }
  return all;
}

void main() {
  test('asks the general API and maps upper-case ncodes back', () async {
    final log = <Uri>[];
    final api = _client(
      MockClient((request) async {
        log.add(request.url);
        return http.Response(
          _fixture('novelapi_two_works.json'),
          200,
          headers: _json,
        );
      }),
    );

    final counts = await _collect(
      api.fetchEpisodeCounts(['n9669bk', 'n4830bu'], isR18: false),
    );

    expect(counts, {'n9669bk': 286, 'n4830bu': 677});
    expect(log, hasLength(1));
    final url = log.single;
    expect(url.host, 'api.syosetu.com');
    expect(url.path, '/novelapi/api/');
    expect(url.queryParameters['out'], 'json');
    expect(url.queryParameters['of'], 'n-ga');
    expect(url.queryParameters['lim'], '500');
    expect(url.queryParameters['ncode'], 'n9669bk-n4830bu');
  });

  test('R18 works go to the R18 API', () async {
    final log = <Uri>[];
    final api = _client(
      MockClient((request) async {
        log.add(request.url);
        return http.Response(
          _fixture('novel18api_two_works.json'),
          200,
          headers: _json,
        );
      }),
    );

    final counts = await _collect(
      api.fetchEpisodeCounts(['n9598df', 'n8321do'], isR18: true),
    );

    expect(log.single.path, '/novel18api/api/');
    expect(counts, {'n9598df': 314, 'n8321do': 390});
  });

  test('more than 100 works are split into chunks of 100', () async {
    final log = <Uri>[];
    final api = _client(_echoingApi(log));
    final ncodes = [for (var i = 0; i < 250; i++) 'n${1000 + i}aa'];

    final chunks = await api.fetchEpisodeCounts(ncodes, isR18: false).toList();

    expect(log, hasLength(3));
    expect(log.map((u) => u.queryParameters['ncode']!.split('-').length), [
      100,
      100,
      50,
    ]);
    expect(chunks.map((c) => c.length), [100, 100, 50]);
    expect(chunks.expand((c) => c.keys).toSet(), ncodes.toSet());
  });

  test('a work missing from the response is reported as failed', () async {
    final api = _client(_echoingApi([], missing: {'n2222bb'}));

    final counts = await _collect(
      api.fetchEpisodeCounts(['n1111aa', 'n2222bb'], isR18: false),
    );

    expect(counts, {'n1111aa': 7, 'n2222bb': null});
  });

  test('works the request did not ask for are ignored', () async {
    // An all-invalid ncode filter makes the real API ignore it and return
    // unrelated works; those must never be attributed to the request.
    final api = _client(
      MockClient(
        (_) async => http.Response(
          '[{"allcount":99},{"ncode":"N0000ZZ","general_all_no":5}]',
          200,
          headers: _json,
        ),
      ),
    );

    final counts = await _collect(
      api.fetchEpisodeCounts(['n1111aa'], isR18: false),
    );

    expect(counts, {'n1111aa': null});
  });

  test('a failed chunk fails its works and the next chunk still runs', () async {
    var calls = 0;
    final api = _client(
      MockClient((request) async {
        calls++;
        if (calls == 1) return http.Response('busy', 503);
        final n = request.url.queryParameters['ncode']!;
        return http.Response(
          '[{"allcount":1},{"ncode":"${n.toUpperCase()}","general_all_no":3}]',
          200,
          headers: _json,
        );
      }),
    );
    final ncodes = [for (var i = 0; i < 101; i++) 'n${1000 + i}aa'];

    final chunks = await api.fetchEpisodeCounts(ncodes, isR18: false).toList();

    expect(chunks, hasLength(2));
    expect(chunks[0].values.toSet(), {null});
    expect(chunks[0], hasLength(100));
    expect(chunks[1], {'n1100aa': 3});
  });

  test('a body that is not the expected JSON fails the chunk', () async {
    final api = _client(
      MockClient((_) async => http.Response('<html>maintenance</html>', 200)),
    );

    final counts = await _collect(
      api.fetchEpisodeCounts(['n1111aa'], isR18: false),
    );

    expect(counts, {'n1111aa': null});
  });

  test('a network error fails the chunk', () async {
    final api = _client(
      MockClient((_) async => throw const SocketException('offline')),
    );

    final counts = await _collect(
      api.fetchEpisodeCounts(['n1111aa'], isR18: false),
    );

    expect(counts, {'n1111aa': null});
  });

  test('an empty list sends no request', () async {
    final log = <Uri>[];
    final api = _client(_echoingApi(log));

    final chunks = await api.fetchEpisodeCounts([], isR18: false).toList();

    expect(chunks, isEmpty);
    expect(log, isEmpty);
  });

  test('a cancellation stops before the next chunk', () async {
    final log = <Uri>[];
    final api = _client(_echoingApi(log));
    final token = CancellationToken();
    final ncodes = [for (var i = 0; i < 150; i++) 'n${1000 + i}aa'];

    final received = <Map<String, int?>>[];
    await expectLater(() async {
      await for (final chunk in api.fetchEpisodeCounts(
        ncodes,
        isR18: false,
        cancelToken: token,
      )) {
        received.add(chunk);
        token.cancel();
      }
    }(), throwsA(isA<CancelledException>()));

    expect(log, hasLength(1));
    expect(received, hasLength(1));
  });

  test('requests carry a User-Agent (the API refuses an empty one)', () async {
    final agents = <String?>[];
    final api = _client(
      MockClient((request) async {
        agents.add(request.headers['User-Agent']);
        return http.Response('[{"allcount":0}]', 200, headers: _json);
      }),
    );

    await _collect(api.fetchEpisodeCounts(['n1111aa'], isR18: false));

    expect(agents.single, isNotNull);
    expect(agents.single, isNotEmpty);
  });
}
