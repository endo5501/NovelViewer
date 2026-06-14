import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

/// Describes how the fake HTTP client should respond to a request whose URL
/// contains [match].
class FakeRoute {
  /// Substring matched against the request URL.
  final String match;
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  /// When non-null, this is thrown instead of returning a response (simulates
  /// a network error such as `SocketException`).
  final Object? error;

  /// When non-null, the handler waits this long before responding (used to
  /// drive timeout / cancellation tests).
  final Duration? delay;

  const FakeRoute(
    this.match, {
    this.statusCode = 200,
    this.body = 'ok',
    this.headers = const {},
    this.error,
    this.delay,
  });
}

/// Builds a [MockClient] that matches requests against [routes] in order (first
/// match wins). Unmatched requests use [fallback]. When [requestLog] is given,
/// every requested URL is appended to it.
MockClient routingClient(
  List<FakeRoute> routes, {
  FakeRoute fallback = const FakeRoute(''),
  List<String>? requestLog,
}) {
  return MockClient((request) async {
    requestLog?.add(request.url.toString());
    final route = routes.firstWhere(
      (r) => request.url.toString().contains(r.match),
      orElse: () => fallback,
    );
    if (route.delay != null) {
      await Future<void>.delayed(route.delay!);
    }
    if (route.error != null) {
      throw route.error!;
    }
    return http.Response(route.body, route.statusCode, headers: route.headers);
  });
}

/// Builds a [MockClient] that returns a *sequence* of responses per URL: the
/// i-th request whose URL contains a given key uses the i-th [FakeRoute] in that
/// key's list. Once a key's sequence is exhausted, its last entry repeats for
/// every subsequent request (so a single `[FakeRoute(503)]` keeps returning 503,
/// and `[FakeRoute(503), FakeRoute(200)]` fails once then succeeds forever).
///
/// This is the stateful counterpart to [routingClient] (which is stateless and
/// returns the same response every time), used to drive retry tests such as
/// "503 then 200". A sequence step may carry an [FakeRoute.error] (thrown, e.g.
/// a `TimeoutException`) or a [FakeRoute.delay] just like [routingClient].
///
/// Keys are matched against the request URL by substring, in insertion order
/// (first match wins). Unmatched requests use [fallback]. When [requestLog] is
/// given, every requested URL is appended to it (so tests can count attempts).
MockClient sequencedClient(
  Map<String, List<FakeRoute>> sequences, {
  FakeRoute fallback = const FakeRoute(''),
  List<String>? requestLog,
}) {
  final counters = <String, int>{};
  return MockClient((request) async {
    final urlStr = request.url.toString();
    requestLog?.add(urlStr);

    String? matchedKey;
    for (final key in sequences.keys) {
      if (urlStr.contains(key)) {
        matchedKey = key;
        break;
      }
    }

    final FakeRoute route;
    if (matchedKey == null) {
      route = fallback;
    } else {
      final seq = sequences[matchedKey]!;
      final i = counters[matchedKey] ?? 0;
      counters[matchedKey] = i + 1;
      route = seq.isEmpty
          ? fallback
          : (i < seq.length ? seq[i] : seq.last);
    }

    if (route.delay != null) {
      await Future<void>.delayed(route.delay!);
    }
    if (route.error != null) {
      throw route.error!;
    }
    return http.Response(route.body, route.statusCode, headers: route.headers);
  });
}

/// A [MockClient] that records the request headers of every request into
/// [captured] (last request wins), then returns a 200 response. Header names are
/// lowercased by the http package, so look up e.g. `captured['user-agent']`.
MockClient capturingHeadersClient(
  Map<String, String> captured, {
  String body = 'ok',
  Map<String, String> responseHeaders = const {},
}) {
  return MockClient((request) async {
    captured.clear();
    request.headers.forEach((k, v) => captured[k.toLowerCase()] = v);
    return http.Response(body, 200, headers: responseHeaders);
  });
}

/// A [MockClient] whose requests never complete — useful for verifying that
/// request timeouts fire.
MockClient hangingClient({List<String>? requestLog}) {
  return MockClient((request) async {
    requestLog?.add(request.url.toString());
    await Completer<void>().future; // never completes
    return http.Response('', 200);
  });
}

/// Wraps another [http.Client] and records whether `close()` was called, so
/// tests can assert that cancellation aborts the in-flight client.
class RecordingClient extends http.BaseClient {
  final http.Client _inner;
  bool closed = false;

  RecordingClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    closed = true;
    _inner.close();
  }
}

/// A configurable single-page fake site. [parseEpisode] always returns
/// [episodeBody], so tests can simulate an empty parse by passing `''`.
class FakeNovelSite extends NovelSite {
  final String siteTypeValue;
  final String novelIdValue;
  final List<Episode> episodes;
  final String? bodyContent;
  final String episodeBody;

  FakeNovelSite({
    this.siteTypeValue = 'test',
    this.novelIdValue = 'novel1',
    this.episodes = const [],
    this.bodyContent,
    this.episodeBody = 'episode body',
  });

  @override
  String get siteType => siteTypeValue;

  @override
  bool canHandle(Uri url) => true;

  @override
  String extractNovelId(Uri url) => novelIdValue;

  @override
  Uri normalizeUrl(Uri url) => url;

  @override
  Map<String, String> requestHeaders(Uri url) => const {};

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) {
    return NovelIndex(
      title: 'テスト小説',
      episodes: episodes,
      bodyContent: bodyContent,
    );
  }

  @override
  String parseEpisode(String html) => episodeBody;
}

/// A configurable multi-page fake site. It emits [episodesPerPage] episodes per
/// page across [totalPages] pages, chaining `nextPageUrl` between them.
///
/// When [throwParseOnPage] is set, `parseIndex` throws while parsing that page
/// (simulating a parse failure on a later index page). Fetch failures are
/// simulated separately via [routingClient] returning a non-200 / error for the
/// page URL.
class FakePagedSite extends NovelSite {
  final int totalPages;
  final int episodesPerPage;
  final int? throwParseOnPage;
  final String episodeBody;

  FakePagedSite({
    this.totalPages = 2,
    this.episodesPerPage = 3,
    this.throwParseOnPage,
    this.episodeBody = 'episode body',
  });

  @override
  String get siteType => 'test';

  @override
  bool canHandle(Uri url) => true;

  @override
  String extractNovelId(Uri url) => 'novel1';

  @override
  Uri normalizeUrl(Uri url) {
    if (url.queryParameters.containsKey('p')) {
      return url.replace(queryParameters: {});
    }
    return url;
  }

  @override
  Map<String, String> requestHeaders(Uri url) => const {};

  int _pageOf(Uri baseUrl) {
    final pageParam = baseUrl.queryParameters['p'];
    return pageParam != null ? int.parse(pageParam) : 1;
  }

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) {
    final currentPage = _pageOf(baseUrl);
    if (throwParseOnPage != null && currentPage == throwParseOnPage) {
      throw const FormatException('simulated index parse failure');
    }

    final episodes = <Episode>[
      for (var i = 1; i <= episodesPerPage; i++)
        Episode(
          index: i,
          title: 'ページ$currentPage第$i話',
          url: Uri.parse('https://example.com/p$currentPage/$i'),
          updatedAt: '2025/01/01 00:00',
        ),
    ];

    Uri? nextPageUrl;
    if (currentPage < totalPages) {
      nextPageUrl =
          Uri.parse('https://example.com/index?p=${currentPage + 1}');
    }

    return NovelIndex(
      title: 'マルチページ小説',
      episodes: episodes,
      nextPageUrl: nextPageUrl,
    );
  }

  @override
  String parseEpisode(String html) => episodeBody;
}
